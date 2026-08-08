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

  /// Clone a template into a draft Document ready for filling. Returns the
  /// document's id.
  ///
  /// Reuses an existing draft clone of this template if one is already present
  /// and untouched, so repeatedly opening a template from the Library doesn't
  /// spawn duplicate drafts. A new clone is only created on the first use (or
  /// after the previous clone was promoted past 'draft' by filling/exporting).
  Future<int> useTemplate(int templateDocId) async {
    final tmpl = await _docRepo.getById(templateDocId);
    if (tmpl == null) throw StateError('Template $templateDocId not found');

    final cloneTitle = tmpl.title.replaceAll(' (Template)', '');

    // Look for an existing draft clone we can hand back instead of duplicating.
    final all = await _docRepo.watchAll().first;
    final existing = all.where((d) =>
        !d.isTemplate &&
        d.status == 'draft' &&
        d.title == cloneTitle);
    if (existing.isNotEmpty) return existing.first.id;

    final pages = await _pageRepo.watchPages(templateDocId).first;
    final fields = await _fieldRepo.watchFields(templateDocId).first;

    final newDoc = await _docRepo.createDocument(cloneTitle);
    await _docRepo.updateDocument(DocumentsCompanion(
      id: Value(newDoc.id),
      pageCount: Value(tmpl.pageCount),
      updatedAt: Value(DateTime.now()),
    ));

    for (final pg in pages) {
      await _pageRepo.addPage(
        documentId: newDoc.id,
        pageIndex: pg.pageIndex,
        imagePath: pg.imagePath,
      );
    }

    for (final f in fields) {
      await _fieldRepo.addField(FieldsCompanion.insert(
        documentId: newDoc.id,
        pageIndex: f.pageIndex,
        type: f.type,
        boundingBoxJson: f.boundingBoxJson,
        label: Value(f.label),
      ));
    }

    return newDoc.id;
  }
}
