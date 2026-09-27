import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'document_repository.dart';

final templateServiceProvider = Provider<TemplateService>((ref) {
  return TemplateService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
  );
});

class TemplateService {
  TemplateService(this._docRepo, this._pageRepo, this._fieldRepo);
  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;

  /// Saves [docId]'s form as a reusable template: same pages, and every
  /// field's position, type, name and settings, with the filled-in values
  /// cleared. It appears under the library's Templates tab. Returns its id.
  ///
  /// The title is kept as is (the Templates tab and status badge mark it),
  /// so nothing English like "(Template)" is baked into a user's data.
  Future<int> createTemplate(int docId) async {
    final src = await _docRepo.getById(docId);
    if (src == null) throw StateError('Document $docId not found');
    final pages = await _pageRepo.watchPages(docId).first;
    final fields = await _fieldRepo.watchFields(docId).first;
    return _docRepo.transaction(() async {
      final tmpl = await _docRepo.createDocument(src.title);
      await _docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(tmpl.id),
          status: const Value('template'),
          isTemplate: const Value(true),
          pageCount: Value(pages.length),
          ocrText: Value(src.ocrText),
          textSize: Value(src.textSize),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _copyPagesAndFields(pages, fields, tmpl.id);
      return tmpl.id;
    });
  }

  /// Starts a new draft from a template, ready for filling. Returns its id.
  ///
  /// Always a fresh draft: a template exists to be filled again and again.
  /// (Reusing "a draft with the same title" could hand back an unrelated
  /// document, since templates keep their original title.)
  Future<int> useTemplate(int templateDocId) async {
    final tmpl = await _docRepo.getById(templateDocId);
    if (tmpl == null) throw StateError('Template $templateDocId not found');
    final pages = await _pageRepo.watchPages(templateDocId).first;
    final fields = await _fieldRepo.watchFields(templateDocId).first;
    return _docRepo.transaction(() async {
      final draft = await _docRepo.createDocument(tmpl.title);
      await _docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(draft.id),
          pageCount: Value(pages.length),
          // A clone of an AcroForm template must keep skipping OCR detection.
          ocrText: Value(tmpl.ocrText),
          textSize: Value(tmpl.textSize),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _copyPagesAndFields(pages, fields, draft.id);
      return draft.id;
    });
  }

  /// Copies pages (renumbered 0..n-1, which is what fields' pageIndex means)
  /// and every structural field column to [toDocId]. Values are left blank.
  ///
  /// Page files are shared, not copied: rotation writes a new file rather
  /// than editing in place, and delete only removes a file nothing else
  /// references (see PageRepository).
  Future<void> _copyPagesAndFields(
    List<Page> pages,
    List<Field> fields,
    int toDocId,
  ) async {
    for (var i = 0; i < pages.length; i++) {
      final id = await _pageRepo.addPage(
        documentId: toDocId,
        pageIndex: i,
        imagePath: pages[i].imagePath,
      );
      await _pageRepo.updatePage(
        PagesCompanion(
          id: Value(id),
          activeFilter: Value(pages[i].activeFilter),
        ),
      );
    }
    for (final f in fields) {
      await _fieldRepo.addField(
        FieldsCompanion.insert(
          documentId: toDocId,
          pageIndex: f.pageIndex,
          type: f.type,
          boundingBoxJson: f.boundingBoxJson,
          label: Value(f.label),
          pdfFieldName: Value(f.pdfFieldName),
          isRequired: Value(f.isRequired),
          sourceKind: Value(f.sourceKind),
          optionsJson: Value(f.optionsJson),
        ),
      );
    }
  }
}
