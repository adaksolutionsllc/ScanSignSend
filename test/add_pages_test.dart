// Add pages: new pages go after the last one, in their own folder; the
// pages a document had keep their fields; deleting the document removes
// both folders. Only drafts and fillable documents take more pages, and
// field detection then reads just the new pages.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/field_hints.dart';
import 'package:scan_sign_send/core/services/import_service.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';
import 'package:scan_sign_send/core/services/page_layout.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/features/field_detection/presentation/field_detection_notifier.dart';
import 'package:scan_sign_send/features/review/presentation/add_pages.dart';

/// Records which pages detection reads; every read fails, as an
/// unreadable page would.
class _SpyLayouts extends PageLayoutService {
  _SpyLayouts() : super(OcrService(), PageRasterService());
  final read = <String>[];

  @override
  Future<(PageLayout, String)> analyse(String storedPath) async {
    read.add(storedPath);
    throw StateError('unreadable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late AppDatabase db;
  late DocumentRepository docs;
  late PageRepository pages;
  late FieldRepository fields;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sss_add_');
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
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A two-page scanned draft with a field on page 2.
  Future<(Document, int)> twoPageDraft() async {
    final doc = await docs.createDocument('Lease');
    final dir = Directory(p.join(root.path, 'pages', 'batch-a'))
      ..createSync(recursive: true);
    for (var i = 0; i < 2; i++) {
      final f = File(p.join(dir.path, 'page_$i.jpg'))..writeAsStringSync('x');
      await pages.addPage(documentId: doc.id, pageIndex: i, imagePath: f.path);
    }
    await docs.updateDocument(
      DocumentsCompanion(id: Value(doc.id), pageCount: const Value(2)),
    );
    final fieldId = await fields.addField(
      FieldsCompanion.insert(
        documentId: doc.id,
        pageIndex: 1,
        type: 'signature',
        boundingBoxJson: '{"x":0.1,"y":0.8,"w":0.3,"h":0.06}',
        label: const Value('Tenant signature'),
      ),
    );
    return (doc, fieldId);
  }

  List<String> scans(int n) => [
    for (var i = 0; i < n; i++)
      (File(
        p.join(root.path, 'scan_tmp_$i.jpg'),
      )..writeAsStringSync('s$i')).path,
  ];

  test(
    'scans go after the last page; fields stay; delete cleans both',
    () async {
      final (doc, fieldId) = await twoPageDraft();
      final temp = scans(2);
      final added = await ImportService(
        docs,
        pages,
        fields,
      ).appendScans(doc.id, temp);

      final all = await pages.pagesOf(doc.id);
      expect(all.map((pg) => pg.pageIndex), [0, 1, 2, 3]);
      expect(all.skip(2).map((pg) => pg.id), added);
      expect((await docs.getById(doc.id))!.pageCount, 4);
      final newDir = p.dirname(PathResolver.resolve(all[2].imagePath));
      expect(p.basename(newDir), isNot('batch-a'));
      expect(
        File(PathResolver.resolve(all[3].imagePath)).readAsStringSync(),
        's1',
      );
      expect(temp.every((t) => !File(t).existsSync()), isTrue);

      final field = (await fields.watchFields(doc.id).first).single;
      expect((field.id, field.pageIndex), (fieldId, 1));

      await docs.deleteDocument(doc.id);
      expect(Directory(newDir).existsSync(), isFalse);
      expect(
        Directory(p.join(root.path, 'pages', 'batch-a')).existsSync(),
        isFalse,
      );
    },
  );

  test('only drafts and fillable documents take more pages', () async {
    final doc = await docs.createDocument('Lease');
    Document as(String status, {bool form = false}) =>
        doc.copyWith(status: status, hasFormFields: form);
    expect(canAddPages(as('draft')), isTrue);
    expect(canAddPages(as('fillable')), isTrue);
    expect(canAddPages(as('pressed')), isFalse);
    expect(canAddPages(as('template')), isFalse);
    expect(canAddPages(as('draft', form: true)), isFalse);
  });

  test('detection on added pages keeps fields and search text', () async {
    final (doc, fieldId) = await twoPageDraft();
    await docs.updateDocument(
      DocumentsCompanion(
        id: Value(doc.id),
        ocrText: const Value('Lease terms'),
      ),
    );
    await ImportService(docs, pages, fields).appendScans(doc.id, scans(1));

    final layouts = _SpyLayouts();
    final editor = FieldDetectionNotifier(
      docId: doc.id,
      layouts: layouts,
      hintRepo: FieldHintRepository(db),
      docRepo: docs,
      pageRepo: pages,
      fieldRepo: fields,
    );
    await editor.run(fromPage: 2);
    expect(editor.state.phase, DetectionPhase.done);
    final added = (await pages.pagesOf(doc.id)).last;
    expect(layouts.read, [added.imagePath], reason: 'only the new page');
    expect(editor.state.currentPageIndex, 2, reason: 'opens on the new page');
    expect(editor.debugFields.map((f) => f.dbId), [fieldId]);
    expect((await docs.getById(doc.id))!.ocrText, 'Lease terms');
    editor.dispose();
  });
}
