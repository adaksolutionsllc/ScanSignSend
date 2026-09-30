import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/ai_enhancer_service.dart';
import '../../../core/services/field_detection_engine.dart';
import '../../../core/services/field_hints.dart';
import '../../../core/services/page_layout.dart';
import '../../../core/services/page_layout_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum DetectionPhase { idle, running, done, error }

class FieldDetectionState {
  final DetectionPhase phase;

  /// Structured progress instead of a baked sentence: the notifier has no
  /// BuildContext, so the screen renders these numbers through AppLocalizations.
  /// [progressTotal] == 0 means "no page-by-page progress yet".
  final int progressCurrent;
  final int progressTotal;

  /// Number of fields found once [phase] is done.
  final int foundCount;
  final List<EditableField> fields;
  final int currentPageIndex;
  final String? errorMessage;

  /// The document's body text size (fraction of page height), if measured.
  final double? textSize;

  /// Fields from the PDF's own form: shown in the editor for context but
  /// not editable there.
  final List<Field> formFields;

  const FieldDetectionState({
    this.phase = DetectionPhase.idle,
    this.progressCurrent = 0,
    this.progressTotal = 0,
    this.foundCount = 0,
    this.fields = const [],
    this.currentPageIndex = 0,
    this.errorMessage,
    this.textSize,
    this.formFields = const [],
  });

  FieldDetectionState copyWith({
    DetectionPhase? phase,
    int? progressCurrent,
    int? progressTotal,
    int? foundCount,
    List<EditableField>? fields,
    int? currentPageIndex,
    String? errorMessage,
    double? textSize,
    List<Field>? formFields,
  }) => FieldDetectionState(
    phase: phase ?? this.phase,
    progressCurrent: progressCurrent ?? this.progressCurrent,
    progressTotal: progressTotal ?? this.progressTotal,
    foundCount: foundCount ?? this.foundCount,
    fields: fields ?? this.fields,
    currentPageIndex: currentPageIndex ?? this.currentPageIndex,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// A field that lives in the editor — can be newly detected or manually added.
class EditableField {
  int? dbId; // null = not yet persisted
  FieldType type;
  BoundingBox bbox;
  String label;
  int pageIndex;
  bool confirmed;
  bool isRequired;

  /// Radio buttons only: the group this option belongs to.
  String? radioGroup;

  /// Dates only: filled with today's date when the page is signed.
  bool autoToday;

  /// Proposed by detection in this session (vs. placed by the user).
  bool detected;

  /// This field's lesson has already been recorded (see LearnedHints).
  bool learned = false;

  String? get optionsJson => fieldOptionsJson(
    group: radioGroup,
    autoToday: autoToday,
    detected: detected,
  );

  EditableField({
    this.dbId,
    required this.type,
    required this.bbox,
    required this.label,
    required this.pageIndex,
    this.confirmed = false,
    this.isRequired = false,
    this.radioGroup,
    this.autoToday = false,
    this.detected = false,
  });

  EditableField copyWithId(int id) => EditableField(
    dbId: id,
    type: type,
    bbox: bbox,
    label: label,
    pageIndex: pageIndex,
    confirmed: confirmed,
    isRequired: isRequired,
    radioGroup: radioGroup,
    autoToday: autoToday,
    detected: detected,
  )..learned = learned;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final fieldDetectionNotifierProvider = StateNotifierProvider.autoDispose
    .family<FieldDetectionNotifier, FieldDetectionState, int>(
      (ref, docId) => FieldDetectionNotifier(
        docId: docId,
        layouts: ref.watch(pageLayoutServiceProvider),
        hintRepo: ref.watch(fieldHintRepositoryProvider),
        aiEnhancer: ref.watch(aiEnhancerServiceProvider),
        docRepo: ref.watch(documentRepositoryProvider),
        pageRepo: ref.watch(pageRepositoryProvider),
        fieldRepo: ref.watch(fieldRepositoryProvider),
      ),
    );

/// Editor state for one document's app-authored fields.
///
/// Every edit is written through to SQLite as it happens (in order, via
/// [_enqueue]) rather than batched until the user taps "Fill". Batching lost
/// all edits whenever the app was closed or killed mid-edit, and a double tap
/// on the button ran the batch twice and duplicated every field.
class FieldDetectionNotifier extends StateNotifier<FieldDetectionState> {
  FieldDetectionNotifier({
    required this.docId,
    required this.layouts,
    required this.hintRepo,
    required this.aiEnhancer,
    required this.docRepo,
    required this.pageRepo,
    required this.fieldRepo,
  }) : super(const FieldDetectionState());

  final int docId;
  final PageLayoutService layouts;
  final FieldHintRepository hintRepo;
  final AiEnhancerService aiEnhancer;

  /// Page layouts analysed this session, by page position — the text a
  /// user-placed field sits after, for learning.
  final _layoutCache = <int, PageLayout>{};
  final DocumentRepository docRepo;
  final PageRepository pageRepo;
  final FieldRepository fieldRepo;

  /// Serialises DB writes so they land in the order the user made them, and
  /// so an update issued right after an add sees the add's row id.
  Future<void> _queue = Future.value();

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    // A failed write must not wedge every later one.
    _queue = next.catchError((Object _) {});
    return next;
  }

  @visibleForTesting
  List<EditableField> get debugFields => state.fields;

  /// Resolves once every edit made so far is on disk.
  Future<void> flush() => _queue;

  Future<void> run() async {
    state = state.copyWith(
      phase: DetectionPhase.running,
      progressCurrent: 0,
      progressTotal: 0,
    );
    try {
      final pages = await pageRepo.watchPages(docId).first;
      final hints = await hintRepo.load();
      final detected = <EditableField>[];
      final pageTexts = <String>[];
      final textSizes = <double>[];

      for (var i = 0; i < pages.length; i++) {
        if (!mounted) return;
        state = state.copyWith(
          progressCurrent: i + 1,
          progressTotal: pages.length,
        );
        try {
          // The PDF's own text layer when it has one, OCR otherwise; plus the
          // lines drawn on the page. Imported PDFs are no longer skipped.
          final (layout, text) = await layouts.analyse(pages[i].imagePath);
          _layoutCache[i] = layout;
          pageTexts.add(text);
          final result = await aiEnhancer.detect(layout, hints: hints);
          if (result.textSize != null) textSizes.add(result.textSize!);
          for (final d in result.fields) {
            detected.add(
              EditableField(
                type: d.type,
                bbox: d.bbox,
                label: d.label,
                pageIndex: i,
                autoToday: d.autoToday,
                detected: true,
              ),
            );
          }
        } catch (_) {
          // One unreadable page must not cost the user every other page's
          // fields; it can still be filled in by hand.
        }
      }

      // The document's text size: the middle of its pages' body sizes.
      textSizes.sort();
      final textSize = textSizes.isEmpty
          ? null
          : textSizes[textSizes.length ~/ 2];

      // Persist detections straight away so leaving the screen (or the app
      // being killed) never throws them away and never triggers a re-scan.
      final ids = await fieldRepo.addFields([
        for (final f in detected) _insertCompanion(f),
      ]);
      final persisted = [
        for (var i = 0; i < detected.length; i++)
          detected[i].copyWithId(ids[i]),
      ];

      // Index every page's text for search, not only the first page's.
      await docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(docId),
          ocrText: Value(pageTexts.where((t) => t.isNotEmpty).join('\n')),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (!mounted) return;
      state = state.copyWith(
        phase: DetectionPhase.done,
        foundCount: persisted.length,
        fields: persisted,
        textSize: textSize,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: DetectionPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Loads already-saved 'app' fields into the editor instead of re-running
  /// OCR detection. AcroForm-sourced fields aren't loaded here: they're
  /// fill-only and never editable in this screen.
  Future<void> loadExisting() async {
    final existing = await fieldRepo.watchFields(docId).first;
    final appFields = [
      for (final f in existing.where((f) => f.sourceKind == 'app'))
        EditableField(
            dbId: f.id,
            type: f.type.toFieldType(),
            bbox: BoundingBox.fromJsonString(f.boundingBoxJson),
            label: f.label,
            pageIndex: f.pageIndex,
            confirmed: true,
            isRequired: f.isRequired,
            // Every stored option must round-trip: an edit rewrites
            // optionsJson from these, so a dropped one would be erased.
            radioGroup: radioGroupOf(f.optionsJson),
            autoToday: autoTodayOf(f.optionsJson),
            detected: detectedOf(f.optionsJson),
          )
          // Taught (or not) in the session that created it; reopening the
          // document mustn't count the same fields again.
          ..learned = true,
    ];
    final doc = await docRepo.getById(docId);
    if (!mounted) return;
    state = state.copyWith(
      phase: DetectionPhase.done,
      foundCount: appFields.length,
      fields: appFields,
      textSize: doc?.textSize,
      formFields: existing.where((f) => f.sourceKind != 'app').toList(),
    );
  }

  void setPageIndex(int i) => state = state.copyWith(currentPageIndex: i);

  void confirmField(int index) =>
      _mutate(index, (f) => f.confirmed = true, persist: false);

  void confirmAll() {
    for (final f in state.fields) {
      f.confirmed = true;
    }
    state = state.copyWith(fields: List.of(state.fields));
  }

  void deleteField(int index) {
    if (index < 0 || index >= state.fields.length) return;
    final updated = List<EditableField>.from(state.fields);
    final removed = updated.removeAt(index);
    state = state.copyWith(fields: updated);
    // Deleting a detection is a "not here" — unless it was the user's own.
    if (removed.detected && !removed.learned) {
      removed.learned = true;
      _learn(removed.label, removed.type, accepted: false);
    }
    _enqueue(() async {
      if (removed.dbId != null) await fieldRepo.deleteField(removed.dbId!);
    });
  }

  void changeType(int index, FieldType type) => _mutate(index, (f) {
    if (f.detected && !f.learned && f.type != type) {
      // "Not a date — a text field" teaches both.
      _learn(f.label, f.type, accepted: false);
      _learn(f.label, type, accepted: true);
      f.learned = true;
    }
    f.type = type;
    // A field turned into a radio starts its own group; one turned into
    // anything else leaves its group. Only dates auto-fill today.
    f.radioGroup = type == FieldType.radio ? _newGroup() : null;
    if (type != FieldType.date) f.autoToday = false;
  });

  void updateLabel(int index, String label) =>
      _mutate(index, (f) => f.label = label);

  /// Reposition / resize a field after a drag, handle drag or pinch.
  void updateBbox(int index, BoundingBox bbox) =>
      _mutate(index, (f) => f.bbox = bbox);

  void setRequired(int index, bool required) =>
      _mutate(index, (f) => f.isRequired = required);

  /// Adds a field and returns it, so the editor can select it straight away.
  ///
  /// A radio joins [radioGroup] when given (the editor passes the selected
  /// radio's group, so tapping Radio again adds another choice to the same
  /// question), otherwise it starts a new group.
  EditableField addManualField({
    required FieldType type,
    required int pageIndex,
    required BoundingBox bbox,
    String? radioGroup,
    String label = '',
    bool isRequired = false,
  }) {
    final field = EditableField(
      type: type,
      bbox: bbox,
      label: label,
      pageIndex: pageIndex,
      confirmed: true,
      isRequired: isRequired,
      radioGroup: type == FieldType.radio ? (radioGroup ?? _newGroup()) : null,
    );
    state = state.copyWith(fields: [...state.fields, field]);
    _enqueue(() async {
      field.dbId = await fieldRepo.addField(_insertCompanion(field));
    });
    return field;
  }

  /// Removes [field] (by identity, so it's safe after other deletes shifted
  /// indices) and returns it for an Undo.
  EditableField? removeField(EditableField field) {
    final index = state.fields.indexOf(field);
    if (index < 0) return null;
    deleteField(index);
    return field;
  }

  /// Re-adds a field removed by [removeField], keeping its group and label.
  EditableField restoreField(EditableField f) => addManualField(
    type: f.type,
    pageIndex: f.pageIndex,
    bbox: f.bbox,
    radioGroup: f.radioGroup,
    label: f.label,
    isRequired: f.isRequired,
  );

  /// Auto-detect's fields that are still in the editor, on every page.
  List<EditableField> get detectedFields => [
    for (final f in state.fields)
      if (f.detected) f,
  ];

  /// Undoes auto-detect: removes every field it proposed and keeps the
  /// ones the user placed. Returns them for an Undo. Not a lesson — one
  /// "clear the lot" says nothing about any single label.
  List<EditableField> removeDetected() {
    final removed = detectedFields;
    if (removed.isEmpty) return removed;
    state = state.copyWith(
      fields: [
        for (final f in state.fields)
          if (!f.detected) f,
      ],
    );
    final ids = [for (final f in removed) f.dbId];
    _enqueue(() async {
      for (final id in ids) {
        if (id != null) await fieldRepo.deleteField(id);
      }
    });
    return removed;
  }

  /// Puts back fields taken away by [removeDetected], still marked detected.
  void restoreDetected(List<EditableField> fields) {
    if (fields.isEmpty) return;
    state = state.copyWith(fields: [...state.fields, ...fields]);
    _enqueue(() async {
      final ids = await fieldRepo.addFields([
        for (final f in fields) _insertCompanion(f),
      ]);
      for (var i = 0; i < fields.length; i++) {
        fields[i].dbId = ids[i];
      }
    });
  }

  static String _newGroup() => const Uuid().v4().substring(0, 8);

  /// Learns from the finished layout when the user moves on to filling:
  /// detections they kept (didn't delete or retype) are confirmed, and each
  /// field they placed themselves teaches "a field of this type goes after
  /// this text" — from its final position, so a rough first drop that was
  /// then adjusted doesn't teach the wrong phrase. Once per field.
  void commitLearning() {
    for (final f in state.fields) {
      if (f.learned) continue;
      f.learned = true;
      if (f.detected) {
        _learn(f.label, f.type, accepted: true);
      } else {
        _learnPlacement(f);
      }
    }
  }

  void _learn(String phrase, FieldType type, {required bool accepted}) {
    // Fire-and-forget: learning must never slow down or break editing.
    hintRepo.record(phrase, type, accepted: accepted).catchError((Object _) {});
  }

  Future<void> _learnPlacement(EditableField f) async {
    try {
      var layout = _layoutCache[f.pageIndex];
      if (layout == null) {
        final pages = await pageRepo.watchPages(docId).first;
        if (f.pageIndex >= pages.length) return;
        (layout, _) = await layouts.analyse(pages[f.pageIndex].imagePath);
        _layoutCache[f.pageIndex] = layout;
      }
      final phrase = FieldDetectionEngine.phraseBefore(layout, f.bbox);
      if (phrase.isNotEmpty) {
        await hintRepo.record(phrase, f.type, accepted: true);
      }
    } catch (_) {
      // Best effort — a page that can't be analysed just teaches nothing.
    }
  }

  void _mutate(
    int index,
    void Function(EditableField) change, {
    bool persist = true,
  }) {
    if (index < 0 || index >= state.fields.length) return;
    final field = state.fields[index];
    change(field);
    state = state.copyWith(fields: List.of(state.fields));
    if (!persist) return;
    // Reads the field when the write runs, so a burst of edits collapses to
    // the latest values and an add still in the queue has set dbId by then.
    _enqueue(() async {
      final id = field.dbId;
      if (id == null) return;
      final name = field.label.trim();
      await fieldRepo.updateField(
        FieldsCompanion(
          id: Value(id),
          pageIndex: Value(field.pageIndex),
          type: Value(field.type.name),
          boundingBoxJson: Value(field.bbox.toJsonString()),
          label: Value(field.label),
          isRequired: Value(field.isRequired),
          // A non-empty label doubles as the exported AcroForm field name.
          pdfFieldName: Value(name.isEmpty ? null : name),
          // Every option (radio group, auto-today date) — see optionsJson.
          optionsJson: Value(field.optionsJson),
        ),
      );
    });
  }

  FieldsCompanion _insertCompanion(EditableField f) {
    final name = f.label.trim();
    return FieldsCompanion.insert(
      documentId: docId,
      pageIndex: f.pageIndex,
      type: f.type.name,
      boundingBoxJson: f.bbox.toJsonString(),
      label: Value(f.label),
      isRequired: Value(f.isRequired),
      pdfFieldName: Value(name.isEmpty ? null : name),
      sourceKind: const Value('app'),
      optionsJson: Value(f.optionsJson),
    );
  }
}

/// A sensible starting box for a new field of [type] centred on [centre]
/// (normalised page coordinates). [pageAspect] is page width / height, used
/// so checkboxes and radios come out square on the page rather than square
/// in normalised units.
///
/// With the document's measured [textSize] (fraction of page height) fields
/// are sized to its text: a text field is one line of body text tall, a
/// checkbox about a capital letter. Without it, sizes suit ~11pt on A4.
BoundingBox defaultFieldBox(
  FieldType type,
  Offset centre,
  double pageAspect, {
  double? textSize,
}) {
  final ts = (textSize == null || textSize <= 0) ? 0.0145 : textSize;
  final line = ts * 1.45;
  final toggle = ts * 1.15; // side of a checkbox / radio, as page height
  final (w, h) = switch (type) {
    FieldType.text => (0.40, line),
    FieldType.date => (0.22, line),
    FieldType.checkbox || FieldType.radio => (toggle / pageAspect, toggle),
    FieldType.initials => (0.12, ts * 2.6),
    FieldType.signature => (0.35, ts * 3.2),
  };
  return BoundingBox(
    x: (centre.dx - w / 2).clamp(0.0, 1.0 - w),
    y: (centre.dy - h / 2).clamp(0.0, 1.0 - h),
    w: w,
    h: h,
  );
}
