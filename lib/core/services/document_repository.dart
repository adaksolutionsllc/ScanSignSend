import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(appDatabaseProvider));
});

class DocumentRepository {
  DocumentRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Document>> watchAll() =>
      (_db.select(_db.documents)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Stream<List<Document>> watchByQuery(String query) => (_db.select(_db.documents)
        ..where((t) => t.ocrText.contains(query) | t.title.contains(query))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Future<Document> createDocument(String title) async {
    final now = DateTime.now();
    final id = await _db.into(_db.documents).insert(
          DocumentsCompanion.insert(
            uuid: _uuid.v4(),
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(_db.documents)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> updateDocument(DocumentsCompanion companion) =>
      (_db.update(_db.documents)
            ..where((t) => t.id.equals(companion.id.value)))
          .write(companion);

  Future<void> deleteDocument(int id) async {
    await (_db.delete(_db.pages)
          ..where((t) => t.documentId.equals(id)))
        .go();
    await (_db.delete(_db.fields)
          ..where((t) => t.documentId.equals(id)))
        .go();
    await (_db.delete(_db.documents)..where((t) => t.id.equals(id))).go();
  }

  Future<Document?> getById(int id) =>
      (_db.select(_db.documents)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
}

// ─── Pages ────────────────────────────────────────────────────────────────────

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(ref.watch(appDatabaseProvider));
});

class PageRepository {
  PageRepository(this._db);
  final AppDatabase _db;

  Stream<List<Page>> watchPages(int documentId) =>
      (_db.select(_db.pages)
            ..where((t) => t.documentId.equals(documentId))
            ..orderBy([(t) => OrderingTerm.asc(t.pageIndex)]))
          .watch();

  Future<int> addPage({
    required int documentId,
    required int pageIndex,
    required String imagePath,
  }) =>
      _db.into(_db.pages).insert(
            PagesCompanion.insert(
              documentId: documentId,
              pageIndex: pageIndex,
              imagePath: imagePath,
            ),
          );

  Future<void> updatePage(PagesCompanion companion) =>
      (_db.update(_db.pages)..where((t) => t.id.equals(companion.id.value)))
          .write(companion);

  Future<void> deletePage(int id) =>
      (_db.delete(_db.pages)..where((t) => t.id.equals(id))).go();

  Future<void> reorderPages(int documentId, List<int> orderedPageIds) async {
    for (var i = 0; i < orderedPageIds.length; i++) {
      await (_db.update(_db.pages)
            ..where((t) => t.id.equals(orderedPageIds[i])))
          .write(PagesCompanion(pageIndex: Value(i)));
    }
  }
}

// ─── Fields ───────────────────────────────────────────────────────────────────

final fieldRepositoryProvider = Provider<FieldRepository>((ref) {
  return FieldRepository(ref.watch(appDatabaseProvider));
});

class FieldRepository {
  FieldRepository(this._db);
  final AppDatabase _db;

  Stream<List<Field>> watchFields(int documentId) =>
      (_db.select(_db.fields)
            ..where((t) => t.documentId.equals(documentId))
            ..orderBy([(t) => OrderingTerm.asc(t.pageIndex)]))
          .watch();

  Future<int> addField(FieldsCompanion companion) =>
      _db.into(_db.fields).insert(companion);

  Future<void> updateField(FieldsCompanion companion) =>
      (_db.update(_db.fields)..where((t) => t.id.equals(companion.id.value)))
          .write(companion);

  Future<void> deleteField(int id) =>
      (_db.delete(_db.fields)..where((t) => t.id.equals(id))).go();
}
