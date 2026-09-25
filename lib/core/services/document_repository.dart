import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../utils/path_resolver.dart';

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

  /// Deletes the document, its rows, **and its files on disk**.
  ///
  /// Deleting only the rows used to leave every scanned page, the imported PDF
  /// copy and the pressed/fillable export sitting in the app container forever
  /// — an unbounded disk leak, and a broken promise for an app whose whole
  /// pitch is that documents stay private. Files are removed after the rows so
  /// the "is anything else still pointing at this folder?" check below sees the
  /// true remaining state.
  Future<void> deleteDocument(int id) async {
    final doc = await getById(id);
    final pages = await (_db.select(_db.pages)
          ..where((t) => t.documentId.equals(id)))
        .get();

    await _db.transaction(() async {
      await (_db.delete(_db.pages)
            ..where((t) => t.documentId.equals(id)))
          .go();
      await (_db.delete(_db.fields)
            ..where((t) => t.documentId.equals(id)))
          .go();
      await (_db.delete(_db.documents)..where((t) => t.id.equals(id))).go();
    });

    await _purgeFilesFor(doc, pages);
  }

  /// Removes the on-disk artefacts of an already-deleted document.
  ///
  /// Never throws: a file that has already vanished must not turn a successful
  /// delete into a user-visible error.
  Future<void> _purgeFilesFor(Document? doc, List<Page> pages) async {
    // The pressed and fillable exports are each uniquely named per document.
    for (final exported in [doc?.pressedPdfPath, doc?.fillablePdfPath]) {
      if (exported != null && exported.isNotEmpty) {
        await _deleteFileQuietly(PathResolver.resolve(exported));
      }
    }

    // Page assets live in `pages/<uuid>/`. A template clone re-uses the
    // template's own folder (TemplateService copies imagePath verbatim), so a
    // folder is only safe to remove once no surviving page row references it.
    final dirs = <String>{};
    for (final page in pages) {
      final file = PathResolver.resolve(page.imagePath).split('#page=').first;
      final dir = p.dirname(file);
      // Only ever touch our own `pages/<uuid>/` folders.
      if (p.basename(p.dirname(dir)) == 'pages') dirs.add(dir);
    }
    for (final dir in dirs) {
      if (await _isFolderStillReferenced(dir)) continue;
      try {
        final d = Directory(dir);
        if (d.existsSync()) await d.delete(recursive: true);
      } catch (_) {
        // Best effort — a locked/missing folder must not fail the delete.
      }
    }
  }

  /// True when any remaining page row still points inside [dir]. Matches on the
  /// folder's UUID segment, which is unique per import/scan batch.
  Future<bool> _isFolderStillReferenced(String dir) async {
    final marker = p.basename(dir);
    if (marker.isEmpty) return true; // unrecognised shape — leave it alone
    final rows = await (_db.select(_db.pages)
          ..where((t) => t.imagePath.contains(marker))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
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

  /// Deletes the page row and, when nothing else still points at it, the image
  /// file behind it. Pages of an imported PDF all share one `#page=N` file, so
  /// the file only goes once the last page referencing it is gone.
  Future<void> deletePage(int id) async {
    final page = await (_db.select(_db.pages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await (_db.delete(_db.pages)..where((t) => t.id.equals(id))).go();
    if (page == null) return;

    final stored = page.imagePath.split('#page=').first;
    // Match on the `<uuid>/<filename>` tail rather than the whole path: rows
    // written by older builds hold an absolute path, newer ones a relative one,
    // and both must count as "still referencing this file".
    final tail = p.join(p.basename(p.dirname(stored)), p.basename(stored));
    final others = await (_db.select(_db.pages)
          ..where((t) => t.imagePath.contains(tail))
          ..limit(1))
        .get();
    if (others.isNotEmpty) return;

    try {
      final f = File(PathResolver.resolve(stored));
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

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
