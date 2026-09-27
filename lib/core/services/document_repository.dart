import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/field_model.dart';
import '../utils/path_resolver.dart';
import 'import_service.dart';
import 'page_raster_service.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(appDatabaseProvider));
});

class DocumentRepository {
  DocumentRepository(this._db);
  final AppDatabase _db;
  final _uuid = const Uuid();

  /// Runs [action] atomically. Repository calls made inside it (on any
  /// repository sharing this database) join the same transaction, so a
  /// multi-step create either fully lands or not at all.
  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  Stream<List<Document>> watchAll() => (_db.select(
    _db.documents,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Stream<List<Document>> watchByQuery(String query) =>
      (_db.select(_db.documents)
            // ocrText can hold the "has its own form" marker rather than page
            // text; it must not make every form PDF match a search.
            ..where(
              (t) =>
                  (t.ocrText.contains(query) &
                      t.ocrText
                          .equals(ImportService.formFieldsSentinel)
                          .not()) |
                  t.title.contains(query),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<Document> createDocument(String title) async {
    final now = DateTime.now();
    final id = await _db
        .into(_db.documents)
        .insert(
          DocumentsCompanion.insert(
            uuid: _uuid.v4(),
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(
      _db.documents,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateDocument(DocumentsCompanion companion) => (_db.update(
    _db.documents,
  )..where((t) => t.id.equals(companion.id.value))).write(companion);

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
    final pages = await (_db.select(
      _db.pages,
    )..where((t) => t.documentId.equals(id))).get();

    await _db.transaction(() async {
      await (_db.delete(_db.pages)..where((t) => t.documentId.equals(id))).go();
      await (_db.delete(
        _db.fields,
      )..where((t) => t.documentId.equals(id))).go();
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

    // Rendered previews of imported-PDF pages sit in the OS cache; they're
    // images of the document, so they go with it.
    final pdfSources = {
      for (final page in pages)
        if (page.imagePath.contains('#page='))
          page.imagePath.split('#page=').first,
    };
    for (final src in pdfSources) {
      await PageRasterService().evict(src);
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
    final rows =
        await (_db.select(_db.pages)
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

  Future<Document?> getById(int id) => (_db.select(
    _db.documents,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}

// ─── Pages ────────────────────────────────────────────────────────────────────

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository(ref.watch(appDatabaseProvider));
});

/// Owns the page ↔ field link.
///
/// A field records its page as `Fields.pageIndex`: the page's **position** in
/// the document (0-based, in [watchPages] order). Every screen, the press and
/// the fillable export look pages up by that position. So any operation that
/// changes page positions must move the fields with it, in the same
/// transaction. Otherwise a reorder, delete or rotate silently puts fields on
/// the wrong page. That's why reorder/delete/rotate live here rather than in
/// the screens.
class PageRepository {
  PageRepository(this._db);
  final AppDatabase _db;

  Stream<List<Page>> watchPages(int documentId) =>
      (_db.select(_db.pages)
            ..where((t) => t.documentId.equals(documentId))
            // id breaks ties so the order (and so every field's page) is
            // stable even if two rows ever share a pageIndex.
            ..orderBy([
              (t) => OrderingTerm.asc(t.pageIndex),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  Future<List<Page>> _orderedPages(int documentId) =>
      watchPages(documentId).first;

  Future<int> addPage({
    required int documentId,
    required int pageIndex,
    required String imagePath,
  }) => _db
      .into(_db.pages)
      .insert(
        PagesCompanion.insert(
          documentId: documentId,
          pageIndex: pageIndex,
          // Stored container-relative so it survives iOS container moves.
          imagePath: PathResolver.toStorable(imagePath),
        ),
      );

  Future<void> updatePage(PagesCompanion companion) => (_db.update(
    _db.pages,
  )..where((t) => t.id.equals(companion.id.value))).write(companion);

  /// Deletes the page, **its fields**, and renumbers everything after it so
  /// later pages' fields stay on their own pages. The image file goes too
  /// once nothing else still points at it. Pages of an imported PDF all share
  /// one `#page=N` file, so the file only goes with the last of them.
  Future<void> deletePage(int id) async {
    final page = await (_db.select(
      _db.pages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (page == null) return;
    final docId = page.documentId;

    await _db.transaction(() async {
      final pages = await _orderedPages(docId);
      final pos = pages.indexWhere((pg) => pg.id == id);
      final fields = await (_db.select(
        _db.fields,
      )..where((t) => t.documentId.equals(docId))).get();
      for (final f in fields) {
        if (f.pageIndex == pos) {
          await (_db.delete(_db.fields)..where((t) => t.id.equals(f.id))).go();
        } else if (f.pageIndex > pos) {
          await (_db.update(_db.fields)..where((t) => t.id.equals(f.id))).write(
            FieldsCompanion(pageIndex: Value(f.pageIndex - 1)),
          );
        }
      }
      await (_db.delete(_db.pages)..where((t) => t.id.equals(id))).go();
      final remaining = [...pages]..removeAt(pos);
      for (var i = 0; i < remaining.length; i++) {
        if (remaining[i].pageIndex != i) {
          await (_db.update(_db.pages)
                ..where((t) => t.id.equals(remaining[i].id)))
              .write(PagesCompanion(pageIndex: Value(i)));
        }
      }
      await (_db.update(_db.documents)..where((t) => t.id.equals(docId))).write(
        DocumentsCompanion(
          pageCount: Value(remaining.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });

    await _deleteFileIfUnreferenced(page.imagePath.split('#page=').first);
  }

  /// Rewrites page positions to match [orderedPageIds] and moves every field
  /// along with its page.
  Future<void> reorderPages(int documentId, List<int> orderedPageIds) =>
      _db.transaction(() async {
        final pages = await _orderedPages(documentId);
        // Old position → new position, by the page's current place in order.
        final newPosOf = {
          for (var i = 0; i < orderedPageIds.length; i++) orderedPageIds[i]: i,
        };
        final remap = <int, int>{};
        for (var oldPos = 0; oldPos < pages.length; oldPos++) {
          final newPos = newPosOf[pages[oldPos].id];
          if (newPos != null) remap[oldPos] = newPos;
        }
        final fields = await (_db.select(
          _db.fields,
        )..where((t) => t.documentId.equals(documentId))).get();
        for (final f in fields) {
          final to = remap[f.pageIndex];
          if (to != null && to != f.pageIndex) {
            await (_db.update(_db.fields)..where((t) => t.id.equals(f.id)))
                .write(FieldsCompanion(pageIndex: Value(to)));
          }
        }
        for (final entry in newPosOf.entries) {
          await (_db.update(_db.pages)..where((t) => t.id.equals(entry.key)))
              .write(PagesCompanion(pageIndex: Value(entry.value)));
        }
      });

  /// Rotates an image page 90° clockwise and turns its fields with it.
  ///
  /// The rotated image is written to a **new** file rather than over the old
  /// one: a template clone shares its template's page files (see
  /// TemplateService), so writing in place would silently rotate the template
  /// too. A new path also defeats Flutter's image cache, which is keyed by
  /// path and would otherwise keep showing the unrotated page.
  ///
  /// Returns false for a PDF-backed page, which can't be rotated here.
  Future<bool> rotatePageClockwise(int id) async {
    final page = await (_db.select(
      _db.pages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (page == null || page.imagePath.contains('#page=')) return false;

    final src = PathResolver.resolve(page.imagePath);
    final dest = p.join(
      p.dirname(src),
      '${p.basenameWithoutExtension(src).split('_r').first}_r${const Uuid().v4().substring(0, 8)}.jpg',
    );
    await compute(_rotateJpegClockwise, [src, dest]);

    await _db.transaction(() async {
      final pages = await _orderedPages(page.documentId);
      final pos = pages.indexWhere((pg) => pg.id == id);
      await (_db.update(_db.pages)..where((t) => t.id.equals(id))).write(
        PagesCompanion(imagePath: Value(PathResolver.toStorable(dest))),
      );
      final fields =
          await (_db.select(_db.fields)..where(
                (t) =>
                    t.documentId.equals(page.documentId) &
                    t.pageIndex.equals(pos),
              ))
              .get();
      for (final f in fields) {
        final b = BoundingBox.fromJsonString(f.boundingBoxJson);
        await (_db.update(_db.fields)..where((t) => t.id.equals(f.id))).write(
          FieldsCompanion(
            boundingBoxJson: Value(b.rotatedClockwise().toJsonString()),
          ),
        );
      }
    });

    await _deleteFileIfUnreferenced(page.imagePath);
    return true;
  }

  /// Deletes [stored] once no page row points at it any more. Matches on the
  /// `<uuid>/<filename>` tail: rows from older builds hold an absolute path,
  /// newer ones a relative one, and both must count as a reference.
  Future<void> _deleteFileIfUnreferenced(String stored) async {
    final tail = p.join(p.basename(p.dirname(stored)), p.basename(stored));
    final others =
        await (_db.select(_db.pages)
              ..where((t) => t.imagePath.contains(tail))
              ..limit(1))
            .get();
    if (others.isNotEmpty) return;
    try {
      final f = File(PathResolver.resolve(stored));
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}

/// compute() entry: rotates the JPEG at args[0] 90° clockwise into args[1].
Future<void> _rotateJpegClockwise(List<String> args) async {
  final decoded = img.decodeImage(await File(args[0]).readAsBytes());
  if (decoded == null) throw const FormatException('Unreadable page image');
  final rotated = img.copyRotate(decoded, angle: 90);
  await File(args[1]).writeAsBytes(img.encodeJpg(rotated, quality: 92));
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

  /// Inserts [companions] atomically and returns their ids in order, so a
  /// crash mid-way can't leave half a page of detected fields behind.
  Future<List<int>> addFields(List<FieldsCompanion> companions) =>
      _db.transaction(
        () async => [
          for (final c in companions) await _db.into(_db.fields).insert(c),
        ],
      );

  Future<void> updateField(FieldsCompanion companion) => (_db.update(
    _db.fields,
  )..where((t) => t.id.equals(companion.id.value))).write(companion);

  /// Answers a radio question: [chosen] becomes the selected option and every
  /// other option in its group (same page, same group id) is cleared, in one
  /// transaction. Tapping the already-chosen option clears the answer, so a
  /// mis-tap can be undone. The whole group counts as filled once answered.
  Future<void> chooseRadio(Field chosen) => _db.transaction(() async {
    final group = radioGroupOf(chosen.optionsJson);
    final clear = chosen.isChecked;
    final radios =
        await (_db.select(_db.fields)..where(
              (t) =>
                  t.documentId.equals(chosen.documentId) &
                  t.pageIndex.equals(chosen.pageIndex) &
                  t.type.equals(FieldType.radio.name),
            ))
            .get();
    for (final r in radios) {
      final inGroup =
          r.id == chosen.id ||
          (group != null && radioGroupOf(r.optionsJson) == group);
      if (!inGroup) continue;
      final on = !clear && r.id == chosen.id;
      await (_db.update(_db.fields)..where((t) => t.id.equals(r.id))).write(
        FieldsCompanion(isChecked: Value(on), isFilled: Value(!clear)),
      );
    }
  });

  /// After the field [signedFieldId] is signed: fills the still-empty date
  /// fields on its page that detection paired with a signature (the
  /// `autoToday` option) with [today], already formatted for the user's
  /// locale. Dates the user filled themselves are never overwritten.
  Future<void> fillTodayDatesFor(int signedFieldId, String today) async {
    final signed = await (_db.select(
      _db.fields,
    )..where((t) => t.id.equals(signedFieldId))).getSingleOrNull();
    if (signed == null) return;
    final dates =
        await (_db.select(_db.fields)..where(
              (t) =>
                  t.documentId.equals(signed.documentId) &
                  t.pageIndex.equals(signed.pageIndex) &
                  t.type.equals(FieldType.date.name) &
                  t.isFilled.equals(false),
            ))
            .get();
    for (final d in dates.where((d) => autoTodayOf(d.optionsJson))) {
      await (_db.update(_db.fields)..where((t) => t.id.equals(d.id))).write(
        FieldsCompanion(value: Value(today), isFilled: const Value(true)),
      );
    }
  }

  Future<void> deleteField(int id) =>
      (_db.delete(_db.fields)..where((t) => t.id.equals(id))).go();
}
