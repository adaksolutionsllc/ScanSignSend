// Fields belong to the page they were created on. They're stored by page
// position, so reordering, deleting or rotating pages must move the fields
// with the page. These tests pin that contract at the repository layer, where
// every screen's page operations now go through.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/template_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';

void main() {
  late AppDatabase db;
  late DocumentRepository docs;
  late PageRepository pages;
  late FieldRepository fields;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    pages = PageRepository(db);
    fields = FieldRepository(db);
    tmp = await Directory.systemTemp.createTemp('sss_pages');
    PathResolver.debugSetDocsDir(tmp);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// A document with [n] pages and one field per page, labelled by the page
  /// it was created on, so a test can tell which page a field travelled with.
  Future<int> seed(int n) async {
    final doc = await docs.createDocument('Doc');
    for (var i = 0; i < n; i++) {
      await pages.addPage(
        documentId: doc.id,
        pageIndex: i,
        imagePath: 'pages/u/page_$i.jpg',
      );
      await fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: i,
          type: 'text',
          boundingBoxJson: const BoundingBox(
            x: 0.1,
            y: 0.1,
            w: 0.3,
            h: 0.05,
          ).toJsonString(),
          label: Value('from page_$i'),
        ),
      );
    }
    return doc.id;
  }

  /// label → the image file of the page the field is now on.
  Future<Map<String, String>> fieldHomes(int docId) async {
    final ps = await pages.watchPages(docId).first;
    final fs = await fields.watchFields(docId).first;
    return {
      for (final f in fs)
        f.label: p.basenameWithoutExtension(ps[f.pageIndex].imagePath),
    };
  }

  test('reordering pages carries each field with its page', () async {
    final docId = await seed(3);
    final ids = (await pages.watchPages(docId).first).map((p) => p.id).toList();

    await pages.reorderPages(docId, [ids[2], ids[0], ids[1]]);

    expect(await fieldHomes(docId), {
      'from page_0': 'page_0',
      'from page_1': 'page_1',
      'from page_2': 'page_2',
    });
    final order = await pages.watchPages(docId).first;
    expect(order.map((p) => p.pageIndex), [0, 1, 2]);
    expect(p.basename(order.first.imagePath), 'page_2.jpg');
  });

  test(
    'deleting a page removes its fields and keeps later fields in place',
    () async {
      final docId = await seed(3);
      final ids = (await pages.watchPages(docId).first)
          .map((p) => p.id)
          .toList();

      await pages.deletePage(ids[1]);

      expect(await fieldHomes(docId), {
        'from page_0': 'page_0',
        'from page_2': 'page_2',
      });
      final left = await pages.watchPages(docId).first;
      expect(
        left.map((p) => p.pageIndex),
        [0, 1],
        reason: 'positions stay contiguous so position lookups stay valid',
      );
      expect((await docs.getById(docId))!.pageCount, 2);
    },
  );

  test(
    'rotating a page turns its fields and leaves other pages alone',
    () async {
      final doc = await docs.createDocument('Doc');
      final dir = Directory(p.join(tmp.path, 'pages', 'u'))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'page_0.jpg'))
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 40, height: 60)));
      final pageId = await pages.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: file.path,
      );
      await pages.addPage(
        documentId: doc.id,
        pageIndex: 1,
        imagePath: 'pages/u/page_1.jpg',
      );
      const box = BoundingBox(x: 0.1, y: 0.2, w: 0.3, h: 0.05);
      for (final pageIndex in [0, 1]) {
        await fields.addField(
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: pageIndex,
            type: 'text',
            boundingBoxJson: box.toJsonString(),
          ),
        );
      }

      expect(await pages.rotatePageClockwise(pageId), isTrue);

      final page = (await pages.watchPages(doc.id).first).first;
      expect(
        page.imagePath,
        isNot(contains('page_0.jpg')),
        reason:
            'rotation writes a new file so shared template pages and the '
            'image cache never see a stale image',
      );
      final rotated = img.decodeJpg(
        File(PathResolver.resolve(page.imagePath)).readAsBytesSync(),
      )!;
      expect((rotated.width, rotated.height), (60, 40));
      expect(file.existsSync(), isFalse, reason: 'old image is cleaned up');

      final fs = await fields.watchFields(doc.id).first;
      final onRotated = BoundingBox.fromJsonString(
        fs.firstWhere((f) => f.pageIndex == 0).boundingBoxJson,
      );
      expect(onRotated.toJson(), box.rotatedClockwise().toJson());
      final onOther = BoundingBox.fromJsonString(
        fs.firstWhere((f) => f.pageIndex == 1).boundingBoxJson,
      );
      expect(onOther.toJson(), box.toJson());
    },
  );

  test(
    'a template clone keeps every field on its page with its form wiring',
    () async {
      final tmplId = await seed(2);
      final acro = await fields.addField(
        FieldsCompanion.insert(
          documentId: tmplId,
          pageIndex: 1,
          type: 'text',
          boundingBoxJson: const BoundingBox(
            x: 0.5,
            y: 0.5,
            w: 0.2,
            h: 0.04,
          ).toJsonString(),
          label: const Value('Surname'),
          pdfFieldName: const Value('form.surname'),
          sourceKind: const Value('acroform'),
          isRequired: const Value(true),
          value: const Value('Filled in template'),
          isFilled: const Value(true),
        ),
      );
      expect(acro, isPositive);
      await docs.updateDocument(
        DocumentsCompanion(id: Value(tmplId), isTemplate: const Value(true)),
      );

      final cloneId = await TemplateService(
        docs,
        pages,
        fields,
      ).useTemplate(tmplId);

      expect(await fieldHomes(cloneId), await fieldHomes(tmplId));
      final surname = (await fields.watchFields(cloneId).first).firstWhere(
        (f) => f.label == 'Surname',
      );
      expect(surname.pdfFieldName, 'form.surname');
      expect(surname.sourceKind, 'acroform');
      expect(surname.isRequired, isTrue);
      expect(surname.value, isEmpty, reason: 'templates clone blank');
    },
  );

  test(
    'choosing a radio clears the rest of its group, not other groups',
    () async {
      final doc = await docs.createDocument('Survey');
      await pages.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: 'pages/u/page_0.jpg',
      );
      Future<int> radio(String group, double y) => fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: FieldType.radio.name,
          boundingBoxJson: BoundingBox(
            x: 0.1,
            y: y,
            w: 0.04,
            h: 0.03,
          ).toJsonString(),
          optionsJson: Value(radioGroupJson(group)),
        ),
      );
      final yes = await radio('q1', 0.1);
      final no = await radio('q1', 0.2);
      final other = await radio('q2', 0.3);

      Future<Map<int, (bool, bool)>> read() async => {
        for (final f in await fields.watchFields(doc.id).first)
          f.id: (f.isChecked, f.isFilled),
      };
      Future<Field> row(int id) async =>
          (await fields.watchFields(doc.id).first).firstWhere(
            (f) => f.id == id,
          );

      await fields.chooseRadio(await row(other));
      await fields.chooseRadio(await row(yes));
      await fields.chooseRadio(await row(no));
      expect(await read(), {
        yes: (false, true),
        no: (true, true),
        other: (true, true),
      });

      // Tapping the chosen option again clears that question only.
      await fields.chooseRadio(await row(no));
      expect(await read(), {
        yes: (false, false),
        no: (false, false),
        other: (true, true),
      });
    },
  );

  test(
    'signing fills the page\'s paired date with today, and only that one',
    () async {
      final doc = await docs.createDocument('Affidavit');
      for (var i = 0; i < 2; i++) {
        await pages.addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: 'pages/u/page_$i.jpg',
        );
      }
      Future<int> add(
        int page,
        FieldType type, {
        bool autoToday = false,
        String value = '',
      }) => fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: page,
          type: type.name,
          boundingBoxJson: const BoundingBox(
            x: 0.1,
            y: 0.1,
            w: 0.2,
            h: 0.02,
          ).toJsonString(),
          optionsJson: Value(fieldOptionsJson(autoToday: autoToday)),
          value: Value(value),
          isFilled: Value(value.isNotEmpty),
        ),
      );
      final sig = await add(1, FieldType.signature);
      final paired = await add(1, FieldType.date, autoToday: true);
      final plain = await add(1, FieldType.date);
      final userSet = await add(
        1,
        FieldType.date,
        autoToday: true,
        value: '01/01/2020',
      );
      final otherPage = await add(0, FieldType.date, autoToday: true);

      await fields.fillTodayDatesFor(sig, '24/09/2026');

      final byId = {
        for (final f in await fields.watchFields(doc.id).first) f.id: f.value,
      };
      expect(byId[paired], '24/09/2026');
      expect(byId[plain], isEmpty, reason: 'not paired with a signature');
      expect(byId[userSet], '01/01/2020', reason: 'never overwrite the user');
      expect(byId[otherPage], isEmpty, reason: 'only the signed page');
    },
  );
}
