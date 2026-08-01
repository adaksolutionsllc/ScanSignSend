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
  final String statusMessage;
  final List<EditableField> fields;
  final int currentPageIndex;
  final String? errorMessage;

  const FieldDetectionState({
    this.phase = DetectionPhase.idle,
    this.statusMessage = '',
    this.fields = const [],
    this.currentPageIndex = 0,
    this.errorMessage,
  });

  FieldDetectionState copyWith({
    DetectionPhase? phase,
    String? statusMessage,
    List<EditableField>? fields,
    int? currentPageIndex,
    String? errorMessage,
  }) =>
      FieldDetectionState(
        phase: phase ?? this.phase,
        statusMessage: statusMessage ?? this.statusMessage,
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

  EditableField({
    this.dbId,
    required this.type,
    required this.bbox,
    required this.label,
    required this.pageIndex,
    this.confirmed = false,
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
      statusMessage: 'Reading your document…',
    );
    try {
      final pages = await pageRepo.watchPages(docId).first;
      final allFields = <EditableField>[];

      for (var i = 0; i < pages.length; i++) {
        state = state.copyWith(
          statusMessage:
              'Analysing page ${i + 1} of ${pages.length}…',
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
        statusMessage:
            '${allFields.length} field${allFields.length == 1 ? '' : 's'} found',
        fields: allFields,
      );
    } catch (e) {
      state = state.copyWith(
        phase: DetectionPhase.error,
        errorMessage: e.toString(),
      );
    }
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

  /// Persist all fields to the DB and return.
  Future<void> saveAll() async {
    // Delete any previously detected fields for this doc
    final existing = await fieldRepo.watchFields(docId).first;
    for (final f in existing) {
      await fieldRepo.deleteField(f.id);
    }
    for (final f in state.fields) {
      await fieldRepo.addField(FieldsCompanion.insert(
        documentId: docId,
        pageIndex: f.pageIndex,
        type: f.type.name,
        boundingBoxJson: f.bbox.toJsonString(),
        label: Value(f.label),
      ));
    }
  }
}
