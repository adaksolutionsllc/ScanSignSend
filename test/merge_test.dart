// Merge and split: the new document gets its own copy of every page, in
// order, with the fields on them (values kept, positions offset). PDF pages
// become images, a form's own fields become the app's, and radio groups
// from different documents never join. A completed document joins as its
// finished PDF, without fields. The originals are left as they were,
// unless pages are moved out.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/merge_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase db;
  late DocumentRepository docs;
  late PageRepository pages;
  late FieldRepository fields;
  late MergeService merger;
  late List<String> rendered;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sss_merge_');
    PathResolver.debugSetDocsDir(root);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    pages = PageRepository(db);
    fields = FieldRepository(db);
    rendered = [];
    merger = MergeService(
      docs,
      pages,
      fields,
      renderPdf: (pdf, dests) async {
        for (final e in dests.entries) {
          rendered.add('${p.basename(pdf)}#${e.key}');
          File(e.value).writeAsStringSync('${p.basename(pdf)}#${e.key}');
        }
      },
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A scanned draft whose page files hold "<folder>/<n>".
  Future<Document> scanned(String folder, int n) async {
    final doc = await docs.createDocument(folder);
    final dir = Directory(p.join(root.path, 'pages', folder))
      ..createSync(recursive: true);
    for (var i = 0; i < n; i++) {
      final f = File(p.join(dir.path, 'page_$i.jpg'))
        ..writeAsStringSync('$folder/$i');
      await pages.addPage(documentId: doc.id, pageIndex: i, imagePath: f.path);
    }
    await docs.updateDocument(
      DocumentsCompanion(id: Value(doc.id), pageCount: Value(n)),
    );
    return doc;
  }

  Future<int> field(
    int docId,
    int page, {
    String type = 'text',
    String value = '',
    String? group,
    String? pdfName,
  }) => fields.addField(
    FieldsCompanion.insert(
      documentId: docId,
      pageIndex: page,
      type: type,
      boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.3,"h":0.05}',
      value: Value(value),
      isFilled: Value(value.isNotEmpty),
      optionsJson: Value(group == null ? null : radioGroupJson(group)),
      pdfFieldName: Value(pdfName),
      sourceKind: Value(pdfName == null ? 'app' : 'acroform'),
    ),
  );

  String contentOf(Page pg) =>
      File(PathResolver.resolve(pg.imagePath)).readAsStringSync();

  test(
    'merge: order, copies, fields, forms, radio groups, finished PDFs',
    () async {
      // A: a scan with a filled field and a radio group.
      final a = await scanned('scan-a', 2);
      await field(a.id, 0, value: 'Priya');
      await field(a.id, 1, type: 'radio', group: 'g');
      // B: an imported form (PDF pages) with its own field and the same group.
      final form = File(p.join(root.path, 'pages', 'form', 'w4.pdf'))
        ..createSync(recursive: true);
      final b = await docs.createDocument('W-4');
      for (var i = 0; i < 2; i++) {
        await pages.addPage(
          documentId: b.id,
          pageIndex: i,
          imagePath: '${form.path}#page=$i',
        );
      }
      await docs.updateDocument(
        DocumentsCompanion(id: Value(b.id), hasFormFields: const Value(true)),
      );
      await field(b.id, 1, pdfName: 'f1_01', value: 'Raman');
      await field(b.id, 1, type: 'radio', group: 'g', pdfName: 'c1');
      // C: completed; its finished PDF has 3 pages, its fields are pressed in.
      final c = await scanned('scan-c', 1);
      await field(c.id, 0, value: 'flattened');
      final pdf = PdfDocument();
      for (var i = 0; i < 3; i++) {
        pdf.pages.add();
      }
      final pressed = File(p.join(root.path, 'pressed', 'c.pdf'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(await pdf.save());
      pdf.dispose();
      await docs.markCompleted(c.id, pressed.path);

      final id = await merger.merge([b.id, a.id, c.id], title: 'All');

      final merged = await pages.pagesOf(id);
      expect(merged.map(contentOf), [
        'w4.pdf#0',
        'w4.pdf#1',
        'scan-a/0',
        'scan-a/1',
        'c.pdf#0',
        'c.pdf#1',
        'c.pdf#2',
      ]);
      expect((await docs.getById(id))!.pageCount, 7);
      expect((await docs.getById(id))!.hasFormFields, isFalse);
      final folder = {
        for (final pg in merged) p.dirname(PathResolver.resolve(pg.imagePath)),
      };
      expect(folder, hasLength(1), reason: 'one new folder');
      expect(p.basename(folder.single), isNot(anyOf('scan-a', 'form')));

      final got = await fields.watchFields(id).first;
      expect(got.map((f) => (f.pageIndex, f.value)), [
        (1, 'Raman'),
        (1, ''),
        (2, 'Priya'),
        (3, ''),
      ]);
      expect(got.every((f) => f.sourceKind == 'app'), isTrue);
      expect(got.every((f) => f.pdfFieldName == null), isTrue);
      final groups = {
        for (final f in got)
          if (f.type == 'radio') radioGroupOf(f.optionsJson),
      };
      expect(groups, hasLength(2), reason: 'groups from B and A stay apart');

      // The originals are untouched, and deleting the merge leaves them whole.
      expect(await pages.pagesOf(a.id), hasLength(2));
      expect(await fields.watchFields(b.id).first, hasLength(2));
      await docs.deleteDocument(id);
      expect((await pages.pagesOf(a.id)).map(contentOf), [
        'scan-a/0',
        'scan-a/1',
      ]);
    },
  );

  test('copy pages to a new document: page order, fields renumbered', () async {
    final a = await scanned('scan-a', 3);
    await field(a.id, 0, value: 'first');
    await field(a.id, 2, value: 'third');
    final all = await pages.pagesOf(a.id);

    final id = await merger.extract(a.id, [
      all[2].id,
      all[0].id,
    ], title: 'Part');

    expect((await pages.pagesOf(id)).map(contentOf), ['scan-a/0', 'scan-a/2']);
    expect(
      (await fields.watchFields(id).first).map((f) => (f.pageIndex, f.value)),
      [(0, 'first'), (1, 'third')],
    );
    expect(await pages.pagesOf(a.id), hasLength(3), reason: 'copy, not move');
    expect(rendered, isEmpty);
  });

  test('move pages to a new document: the rest stays, renumbered', () async {
    final a = await scanned('scan-a', 3);
    await field(a.id, 1, value: 'second');
    await field(a.id, 2, value: 'third');
    final all = await pages.pagesOf(a.id);

    final id = await merger.extract(
      a.id,
      [all[2].id],
      title: 'Part',
      move: true,
    );

    expect((await pages.pagesOf(id)).map(contentOf), ['scan-a/2']);
    final left = await pages.pagesOf(a.id);
    expect(left.map(contentOf), ['scan-a/0', 'scan-a/1']);
    expect((await docs.getById(a.id))!.pageCount, 2);
    expect(
      (await fields.watchFields(a.id).first).map((f) => (f.pageIndex, f.value)),
      [(1, 'second')],
    );
    expect(
      (await fields.watchFields(id).first).map((f) => (f.pageIndex, f.value)),
      [(0, 'third')],
    );
  });
}
