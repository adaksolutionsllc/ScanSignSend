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

  /// Clone a template into a fresh draft Document ready for filling.
  /// Returns the new document's id.
  Future<int> useTemplate(int templateDocId) async {
    final tmpl = await _docRepo.getById(templateDocId);
    if (tmpl == null) throw StateError('Template $templateDocId not found');

    final pages = await _pageRepo.watchPages(templateDocId).first;
    final fields = await _fieldRepo.watchFields(templateDocId).first;

    final newDoc = await _docRepo.createDocument(
      tmpl.title.replaceAll(' (Template)', ''),
    );
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
