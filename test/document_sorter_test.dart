import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/category_hints.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/document_sorter.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';
import 'package:scan_sign_send/core/services/on_device_ai_service.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.scansignsend/on_device_ai');

/// What the fake model channel answers, and what it was asked.
class _FakeModel {
  String status = 'available';
  Object? answer = 'medical'; // a key, null, or an Exception to throw
  Duration delay = Duration.zero;
  int classifyCalls = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'status':
              return status;
            case 'classifyDocument':
              classifyCalls++;
              await Future<void>.delayed(delay);
              if (answer is Exception) throw answer!;
              return answer;
          }
          return null;
        });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DocumentRepository docs;
  late PageRepository pages;
  late _FakeModel model;
  late DocumentSorter sorter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    pages = PageRepository(db);
    model = _FakeModel()..install();
    sorter = DocumentSorter(
      docRepo: docs,
      pageRepo: pages,
      layouts: PageLayoutService(OcrService(), PageRasterService()),
      hints: CategoryHintRepository(db),
      ai: OnDeviceAiService(),
    );
  });

  tearDown(() => db.close());

  Future<Document> doc(String title) => docs.createDocument(title);

  Future<String?> categoryOf(int id) async =>
      (await docs.getById(id))!.category;

  test('only names nobody chose are replaced', () {
    for (final t in [
      'Document 2026-10-23',
      'Documento 2026-10-23',
      'IMG_2041',
      'PXL_20261023_101200',
      'WhatsApp Image 2026-10-23 at 10.12.01',
      'Screenshot 2026-10-23',
      '20261023_101200',
    ]) {
      expect(DocumentSorter.looksGenerated(t), isTrue, reason: t);
    }
    for (final t in ['Lease', 'Rental application', 'Imagine form']) {
      expect(DocumentSorter.looksGenerated(t), isFalse, reason: t);
    }
  });

  group('who decides', () {
    test('the on-device model, when the phone has one', () async {
      final (key, by) = await sorter.categorise('Visit summary', 'Notes');
      expect((key, by), ('medical', SortedBy.model));
      expect(model.classifyCalls, 1);
    });

    test(
      'keywords when the model is not available, without asking it',
      () async {
        model.status = 'deviceNotEligible';
        final (key, by) = await sorter.categorise('Invoice', 'Amount due 40');
        expect((key, by), ('bills', SortedBy.keywords));
        expect(model.classifyCalls, 0);
      },
    );

    for (final (what, answer) in [
      ('is not sure', null),
      ('answers outside the list', 'cars'),
      ('fails', PlatformException(code: 'x')),
    ]) {
      test('keywords when the model $what', () async {
        model.answer = answer;
        final (key, by) = await sorter.categorise('Invoice', 'Amount due 40');
        expect((key, by), ('bills', SortedBy.keywords));
      });
    }

    test('keywords when the model is too slow', () async {
      model.delay = OnDeviceAiService.timeout + const Duration(seconds: 1);
      final (key, by) = await sorter.categorise('Invoice', 'Amount due 40');
      expect((key, by), ('bills', SortedBy.keywords));
    });

    test('nobody sure → Uncategorised', () async {
      model.answer = null;
      expect(await sorter.categorise('Notes', 'See you soon'), (null, null));
    });

    test("what the user's corrections taught wins over the model", () async {
      final a = await doc('Lease renewal – 1 Oct');
      final b = await doc('Lease renewal – 2 Oct');
      await sorter.setByUser(a, 'u:7');
      expect(
        (await sorter.categorise('Lease renewal – 3 Oct', '')).$1,
        isNot('u:7'),
        reason: 'one correction is not a pattern',
      );
      await sorter.setByUser(b, 'u:7');
      expect(await sorter.categorise('Lease renewal – 3 Oct', ''), (
        'u:7',
        SortedBy.learned,
      ));
    });
  });

  group('the user stays in charge', () {
    test('a category chosen by hand is never changed', () async {
      final d = await doc('Visit');
      await sorter.setByUser(d, 'tax');
      expect(await sorter.afterDetection(d.id), isNull);
      expect(await categoryOf(d.id), 'tax');
      expect((await docs.getById(d.id))!.categoryManual, isTrue);
    });

    test('moving to Uncategorised by hand also sticks', () async {
      final d = await doc('Visit');
      await sorter.setByUser(d, null);
      await sorter.afterDetection(d.id);
      expect(await categoryOf(d.id), isNull);
    });

    test('switched off in Settings: nothing is sorted', () async {
      SharedPreferences.setMockInitialValues({
        DocumentSorter.enabledKey: false,
      });
      final d = await doc('Visit');
      expect(await sorter.afterDetection(d.id), isNull);
      expect(await categoryOf(d.id), isNull);
    });
  });

  group('new documents', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('sss_sort'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<Document> importedPdf(String title, String file) async {
      final d = await doc(title);
      final copy = File('${tmp.path}/${file.split('/').last}')
        ..writeAsBytesSync(File(file).readAsBytesSync());
      await pages.addPage(
        documentId: d.id,
        pageIndex: 0,
        imagePath: '${copy.path}#page=0',
      );
      return d;
    }

    test(
      'an imported PDF keeps its file name, gets sorted and searchable',
      () async {
        model.status = 'unsupported';
        final d = await importedPdf(
          'Rental_Application',
          'tool/store_capture/forms/Rental_Application.pdf',
        );
        final by = await sorter.sortNew(d.id, nameFor: (t) => '$t – 23 Oct');
        final after = (await docs.getById(d.id))!;
        expect(after.title, 'Rental_Application');
        expect(after.category, 'home');
        expect(by, SortedBy.keywords);
        expect(after.ocrText, contains('RENTAL'));
      },
    );

    test('a document the user already sorted is left alone', () async {
      final d = await importedPdf('W-4', 'test/fixtures/irs_fw4_2026.pdf');
      await sorter.setByUser(d, 'work');
      await sorter.sortNew(d.id, nameFor: (t) => t);
      expect(await categoryOf(d.id), 'work');
    });

    test('backfill sorts old documents once from their stored text', () async {
      model.status = 'unsupported';
      final a = await doc('Old one');
      await docs.updateDocument(
        DocumentsCompanion(
          id: Value(a.id),
          ocrText: Value('Patient name. Allergies. Medications.'),
        ),
      );
      await sorter.backfillOnce();
      expect(await categoryOf(a.id), 'medical');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DocumentSorter.backfilledKey), isTrue);

      // A second run doesn't touch documents again.
      await sorter.setByUser((await docs.getById(a.id))!, null);
      await docs.updateDocument(
        DocumentsCompanion(id: Value(a.id), categoryManual: Value(false)),
      );
      await sorter.backfillOnce();
      expect(await categoryOf(a.id), isNull);
    });
  });
}
