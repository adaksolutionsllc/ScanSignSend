// Deleting a document must take its files with it.
//
// Removing only the DB rows left every scanned page, imported-PDF copy and
// pressed export sitting in the app container forever — an unbounded disk leak,
// and a broken promise for an app that sells "your documents stay on your
// device". These tests pin the cleanup, including the case that makes it
// non-trivial: a template clone shares its page folder with the template it was
// cloned from, so deleting the clone must NOT destroy the template's pages.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late DocumentRepository docs;
  late PageRepository pages;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sss_delete_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    pages = PageRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Creates `<root>/pages/<folder>/<name>` with dummy content.
  File makePageFile(String folder, String name) {
    final dir = Directory(p.join(root.path, 'pages', folder))
      ..createSync(recursive: true);
    return File(p.join(dir.path, name))..writeAsStringSync('scan-bytes');
  }

  test('deleting a document removes its page files and pressed PDF', () async {
    final pageFile = makePageFile('batch-a', 'page_0.jpg');
    final pressedDir = Directory(p.join(root.path, 'pressed'))
      ..createSync(recursive: true);
    final pressed = File(p.join(pressedDir.path, 'out.pdf'))
      ..writeAsStringSync('%PDF-');

    final doc = await docs.createDocument('Lease');
    await pages.addPage(
        documentId: doc.id, pageIndex: 0, imagePath: pageFile.path);
    await docs.updateDocument(DocumentsCompanion(
      id: Value(doc.id),
      pressedPdfPath: Value(pressed.path),
    ));

    await docs.deleteDocument(doc.id);

    expect(pageFile.existsSync(), isFalse, reason: 'page image must be gone');
    expect(pressed.existsSync(), isFalse, reason: 'pressed PDF must be gone');
    expect(Directory(p.join(root.path, 'pages', 'batch-a')).existsSync(),
        isFalse);
    expect(await docs.getById(doc.id), isNull);
  });

  test('deleting a template clone leaves the template its pages', () async {
    // TemplateService copies imagePath verbatim, so both documents reference
    // the exact same file on disk.
    final shared = makePageFile('batch-shared', 'page_0.jpg');

    final template = await docs.createDocument('W-9 (Template)');
    await pages.addPage(
        documentId: template.id, pageIndex: 0, imagePath: shared.path);

    final clone = await docs.createDocument('W-9');
    await pages.addPage(
        documentId: clone.id, pageIndex: 0, imagePath: shared.path);

    await docs.deleteDocument(clone.id);

    expect(shared.existsSync(), isTrue,
        reason: 'the template still points at this file');

    // Once the template goes too, the file is finally unreferenced.
    await docs.deleteDocument(template.id);
    expect(shared.existsSync(), isFalse);
  });

  test('deletePage keeps a shared imported-PDF file until its last page goes',
      () async {
    final pdf = makePageFile('batch-pdf', 'form.pdf');
    final doc = await docs.createDocument('Imported form');
    final first = await pages.addPage(
        documentId: doc.id, pageIndex: 0, imagePath: '${pdf.path}#page=0');
    final second = await pages.addPage(
        documentId: doc.id, pageIndex: 1, imagePath: '${pdf.path}#page=1');

    await pages.deletePage(first);
    expect(pdf.existsSync(), isTrue,
        reason: 'page 2 still renders from this file');

    await pages.deletePage(second);
    expect(pdf.existsSync(), isFalse);
  });
}
