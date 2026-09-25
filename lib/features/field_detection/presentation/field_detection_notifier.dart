import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/ai_enhancer_service.dart';
import '../../../core/services/field_detection_engine.dart';
import '../../../core/services/ocr_service.dart';

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

  const FieldDetectionState({
    this.phase = DetectionPhase.idle,
    this.progressCurrent = 0,
    this.progressTotal = 0,
    this.foundCount = 0,
    this.fields = const [],
    this.currentPageIndex = 0,
    this.errorMessage,
  });

  FieldDetectionState copyWith({
    DetectionPhase? phase,
    int? progressCurrent,
    int? progressTotal,
    int? foundCount,
    List<EditableField>? fields,
    int? currentPageIndex,
    String? errorMessage,
  }) =>
      FieldDetectionState(
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
  final int? dbId; // null = not yet persisted
  FieldType type;
  BoundingBox bbox;
  String label;
  int pageIndex;
  bool confirmed;
  bool isRequired;

  EditableField({
    this.dbId,
    required this.type,
    required this.bbox,
    required this.label,
    required this.pageIndex,
    this.confirmed = false,
    this.isRequired = false,
  });
}

// ── Notifier ──────────────────────────────────────────────────────────────────

final fieldDetectionNotifierProvider = StateNotifierProvider.autoDispose
    .family<FieldDetectionNotifier, FieldDetectionState, int>(
  (ref, docId) => FieldDetectionNotifier(
    docId: docId,
    ocr: ref.watch(ocrServiceProvider),
    engine: ref.watch(fieldDetectionEngineProvider),
    aiEnhancer: ref.watch(aiEnhancerServiceProvider),
    docRepo: ref.watch(documentRepositoryProvider),
    pageRepo: ref.watch(pageRepositoryProvider),
    fieldRepo: ref.watch(fieldRepositoryProvider),
  ),
);

class FieldDetectionNotifier
    extends StateNotifier<FieldDetectionState> {
  FieldDetectionNotifier({
    required this.docId,
    required this.ocr,
    required this.engine,
    required this.aiEnhancer,
    required this.docRepo,
    required this.pageRepo,
    required this.fieldRepo,
  }) : super(const FieldDetectionState());

  final int docId;
  final OcrService ocr;
  final FieldDetectionEngine engine;
  final AiEnhancerService aiEnhancer;
  final DocumentRepository docRepo;
  final PageRepository pageRepo;
  final FieldRepository fieldRepo;

  Future<void> run() async {
    state = state.copyWith(
      phase: DetectionPhase.running,
      progressCurrent: 0,
      progressTotal: 0,
    );
    try {
      final pages = await pageRepo.watchPages(docId).first;
      final allFields = <EditableField>[];

      for (var i = 0; i < pages.length; i++) {
        state = state.copyWith(
          progressCurrent: i + 1,
          progressTotal: pages.length,
        );
        final page = pages[i];
        // Skip PDF-fragment pages for OCR (no raster available yet)
        if (page.imagePath.contains('#page=')) continue;

        final ocrResult = await ocr.processPage(page.imagePath);
        // AI enhancer falls back to heuristic engine if unavailable
        final detected = await aiEnhancer.detect(ocrResult);

        for (final d in detected) {
          allFields.add(EditableField(
            type: d.type,
            bbox: d.bbox,
            label: d.label,
            pageIndex: i,
          ));
        }

        // Persist full OCR text to the Document row for search
        if (i == 0) {
          await docRepo.updateDocument(DocumentsCompanion(
            id: Value(docId),
            ocrText: Value(ocrResult.fullText),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }

      state = state.copyWith(
        phase: DetectionPhase.done,
        foundCount: allFields.length,
        fields: allFields,
      );
    } catch (e) {
      state = state.copyWith(
        phase: DetectionPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Loads already-saved 'app' fields into the editor instead of re-running
  /// OCR detection. Used when re-entering this screen for a document that's
  /// been through detection (or manual authoring) before — re-running `run()`
  /// would throw away confirmed labels/positions and any manually-added
  /// fields, since [saveAll] used to always delete-and-reinsert everything.
  /// AcroForm-sourced fields aren't loaded here: they're fill-only and never
  /// editable in this screen (see [saveAll]).
  Future<void> loadExisting() async {
    final existing = await fieldRepo.watchFields(docId).first;
    final appFields = existing
        .where((f) => f.sourceKind == 'app')
        .map((f) => EditableField(
              dbId: f.id,
              type: f.type.toFieldType(),
              bbox: BoundingBox.fromJsonString(f.boundingBoxJson),
              label: f.label,
              pageIndex: f.pageIndex,
              confirmed: true,
              isRequired: f.isRequired,
            ))
        .toList();
    state = state.copyWith(
      phase: DetectionPhase.done,
      foundCount: appFields.length,
      fields: appFields,
    );
  }

  void setPageIndex(int i) =>
      state = state.copyWith(currentPageIndex: i);

  void confirmField(int index) {
    final updated = List<EditableField>.from(state.fields);
    updated[index].confirmed = true;
    state = state.copyWith(fields: updated);
  }

  void deleteField(int index) {
    final updated = List<EditableField>.from(state.fields);
    updated.removeAt(index);
    state = state.copyWith(fields: updated);
  }

  void changeType(int index, FieldType type) {
    final updated = List<EditableField>.from(state.fields);
    updated[index].type = type;
    state = state.copyWith(fields: updated);
  }

  void updateLabel(int index, String label) {
    final updated = List<EditableField>.from(state.fields);
    updated[index].label = label;
    state = state.copyWith(fields: updated);
  }

  /// Reposition / resize a field after the user drags it in the editor.
  void updateBbox(int index, BoundingBox bbox) {
    if (index < 0 || index >= state.fields.length) return;
    final updated = List<EditableField>.from(state.fields);
    updated[index].bbox = bbox;
    state = state.copyWith(fields: updated);
  }

  void setRequired(int index, bool required) {
    if (index < 0 || index >= state.fields.length) return;
    final updated = List<EditableField>.from(state.fields);
    updated[index].isRequired = required;
    state = state.copyWith(fields: updated);
  }

  void addManualField({
    required FieldType type,
    required int pageIndex,
    required BoundingBox bbox,
  }) {
    final updated = List<EditableField>.from(state.fields);
    updated.add(EditableField(
      type: type,
      bbox: bbox,
      label: '',
      pageIndex: pageIndex,
      confirmed: true,
    ));
    state = state.copyWith(fields: updated);
  }

  /// Persist all editor fields to the DB.
  ///
  /// Only app-authored fields are touched — real AcroForm fields imported
  /// from a PDF (`sourceKind='acroform'`) are left untouched so this can never
  /// wipe the source form's fields. Fields the editor already knew about
  /// ([EditableField.dbId] set, e.g. via [loadExisting]) are updated in place
  /// rather than deleted-and-reinserted, so their filled `value`/`isFilled`/
  /// `isChecked`/`signatureId` — none of which this editor ever touches —
  /// survive a re-edit instead of coming back blank.
  Future<void> saveAll() async {
    final existing = await fieldRepo.watchFields(docId).first;
    final existingIds = existing.map((f) => f.id).toSet();
    final keptIds = <int>{};

    for (final f in state.fields) {
      // Use a non-empty label as the AcroForm field name so authored forms
      // export with meaningful, fillable field names.
      final name = f.label.trim().isEmpty ? null : f.label.trim();
      if (f.dbId != null && existingIds.contains(f.dbId)) {
        keptIds.add(f.dbId!);
        await fieldRepo.updateField(FieldsCompanion(
          id: Value(f.dbId!),
          pageIndex: Value(f.pageIndex),
          type: Value(f.type.name),
          boundingBoxJson: Value(f.bbox.toJsonString()),
          label: Value(f.label),
          isRequired: Value(f.isRequired),
          pdfFieldName: Value(name),
        ));
      } else {
        final newId = await fieldRepo.addField(FieldsCompanion.insert(
          documentId: docId,
          pageIndex: f.pageIndex,
          type: f.type.name,
          boundingBoxJson: f.bbox.toJsonString(),
          label: Value(f.label),
          isRequired: Value(f.isRequired),
          pdfFieldName: Value(name),
          sourceKind: const Value('app'),
        ));
        keptIds.add(newId);
      }
    }

    // Anything app-sourced that didn't survive into state.fields was removed
    // in the editor (deleteField) — drop it. AcroForm rows are never in
    // state.fields, so they're never in keptIds and always preserved here.
    for (final f in existing) {
      if (f.sourceKind == 'acroform') continue;
      if (!keptIds.contains(f.id)) {
        await fieldRepo.deleteField(f.id);
      }
    }
  }
}
