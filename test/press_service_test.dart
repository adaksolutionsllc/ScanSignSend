// End-to-end: "Flatten & Sign" must work in every app language. The PDF is
// built in a background isolate, which starts without intl's locale date
// data; formatting the signing date there threw LocaleDataException for all
// locales except the built-in en_US.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/press_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;
  late AppDatabase db;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('sss_press_');
    PathResolver.debugSetDocsDir(docsDir);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docsDir.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    await docsDir.delete(recursive: true);
  });

  for (final locale in ['en', 'en_IN', 'fr', 'hi', 'ta', 'te']) {
    test('press succeeds in $locale and locks the document', () async {
      // What flutter_localizations does for the active locale at startup —
      // on the main isolate only.
      await initializeDateFormatting(locale);

      final docs = DocumentRepository(db);
      final pages = PageRepository(db);
      final fields = FieldRepository(db);
      final pageDir = Directory(p.join(docsDir.path, 'pages', 'u'))
        ..createSync(recursive: true);
      final image = File(p.join(pageDir.path, 'page_0.jpg'))
        ..writeAsBytesSync(
          img.encodeJpg(
            img.Image(width: 620, height: 877)
              ..clear(img.ColorRgb8(255, 255, 255)),
          ),
        );
      final doc = await docs.createDocument('Affidavit');
      await pages.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: image.path,
      );
      await fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: FieldType.text.name,
          boundingBoxJson: const BoundingBox(
            x: 0.2,
            y: 0.3,
            w: 0.4,
            h: 0.03,
          ).toJsonString(),
          value: const Value('Madurai'),
          isFilled: const Value(true),
        ),
      );

      final out = await PressService(docs, pages, fields).press(
        doc.id,
        PressCertificateStrings(
          title: 'Certificate',
          documentLabel: 'Document',
          signedOnLabel: 'Signed on',
          methodLabel: 'Method',
          methodValue: 'Drawn',
          noteLabel: 'Note',
          noteValue: 'Offline',
          dateFormat: 'd MMMM y, HH:mm',
          localeName: locale,
        ),
      );

      final pdf = PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(pdf.pages.count, 2, reason: 'the page plus the certificate');
      pdf.dispose();
      expect((await docs.getById(doc.id))!.status, 'pressed');
    });
  }

  test(
    'an imported Letter page presses edge-to-edge at its own size',
    () async {
      await initializeDateFormatting('en');
      // A US Letter source page with text from the left margin to the right
      // one, like the affidavit that was being clipped.
      final src = PdfDocument();
      src.pageSettings
        ..size = const Size(612, 792)
        ..margins.all = 0;
      final font = PdfStandardFont(PdfFontFamily.helvetica, 11.5);
      src.pages.add().graphics
        ..drawString(
          'LEFTEDGE',
          font,
          bounds: const Rect.fromLTWH(78, 110, 200, 16),
        )
        ..drawString(
          'RIGHTEDGE',
          font,
          bounds: const Rect.fromLTWH(470, 178, 120, 16),
        );
      final pdfDir = Directory(p.join(docsDir.path, 'pages', 'imp'))
        ..createSync(recursive: true);
      final srcFile = File(p.join(pdfDir.path, 'form.pdf'))
        ..writeAsBytesSync(src.saveSync());
      src.dispose();

      final docs = DocumentRepository(db);
      final pages = PageRepository(db);
      final fields = FieldRepository(db);
      final doc = await docs.createDocument('Imported');
      await pages.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: '${srcFile.path}#page=0',
      );
      await fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: FieldType.text.name,
          boundingBoxJson: const BoundingBox(
            x: 0.5,
            y: 0.5,
            w: 0.3,
            h: 0.03,
          ).toJsonString(),
          value: const Value('FILLED'),
          isFilled: const Value(true),
        ),
      );

      final out = await PressService(docs, pages, fields).press(
        doc.id,
        const PressCertificateStrings(
          title: 'Certificate',
          documentLabel: 'Document',
          signedOnLabel: 'Signed on',
          methodLabel: 'Method',
          methodValue: 'Drawn',
          noteLabel: 'Note',
          noteValue: 'Offline',
          dateFormat: 'd MMMM y',
          localeName: 'en',
        ),
      );

      final pdf = PdfDocument(inputBytes: File(out).readAsBytesSync());
      final page = pdf.pages[0];
      expect(page.size, const Size(612, 792), reason: 'keeps the source size');
      final words = {
        for (final l in PdfTextExtractor(
          pdf,
        ).extractTextLines(startPageIndex: 0, endPageIndex: 0))
          for (final w in l.wordCollection) w.text: w.bounds,
      };
      expect(
        words['LEFTEDGE']!.left,
        closeTo(78, 2),
        reason: 'not pushed in by a default page margin',
      );
      expect(words['LEFTEDGE']!.top, closeTo(110, 4));
      expect(words['RIGHTEDGE']!.left, closeTo(470, 2));
      expect(words['RIGHTEDGE']!.right, lessThan(612));
      expect(
        words['FILLED']!.left,
        closeTo(306, 4),
        reason: 'fields land where they were placed on the page',
      );
      pdf.dispose();
    },
  );

  test('Hindi, Tamil and Telugu values and certificate press as shaped images',
      () async {
    await initializeDateFormatting('hi');
    final docs = DocumentRepository(db);
    final pages = PageRepository(db);
    final fields = FieldRepository(db);
    final pageDir = Directory(p.join(docsDir.path, 'pages', 'u'))
      ..createSync(recursive: true);
    final image = File(p.join(pageDir.path, 'page_0.jpg'))
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 620, height: 877)
        ..clear(img.ColorRgb8(255, 255, 255))));
    final doc = await docs.createDocument('शपथ पत्र');
    await pages.addPage(documentId: doc.id, pageIndex: 0, imagePath: image.path);
    var y = 0.2;
    for (final value in ['मदुरै', 'மதுரை', 'మదురై', 'Madurai']) {
      await fields.addField(FieldsCompanion.insert(
        documentId: doc.id,
        pageIndex: 0,
        type: FieldType.text.name,
        boundingBoxJson:
            BoundingBox(x: 0.2, y: y, w: 0.4, h: 0.03).toJsonString(),
        value: Value(value),
        isFilled: const Value(true),
      ));
      y += 0.1;
    }

    final out = await PressService(docs, pages, fields).press(
      doc.id,
      const PressCertificateStrings(
        title: 'हस्ताक्षर प्रमाणपत्र',
        documentLabel: 'दस्तावेज़',
        signedOnLabel: 'हस्ताक्षर तिथि',
        methodLabel: 'तरीका',
        methodValue: 'हाथ से बनाया गया',
        noteLabel: 'नोट',
        noteValue: 'ऑफ़लाइन',
        dateFormat: 'd MMMM y',
        localeName: 'hi',
      ),
    );

    final pdf = PdfDocument(inputBytes: File(out).readAsBytesSync());
    final text = PdfTextExtractor(pdf).extractText();
    // Latin stays real text; Indic is drawn as shaped images, so it never
    // appears as (unshaped, garbled) PDF text.
    expect(text, contains('Madurai'));
    for (final s in ['मदुरै', 'மதுரை', 'మదురై', 'हस्ताक्षर']) {
      expect(text.contains(s), isFalse, reason: '$s should be an image');
    }
    expect(pdf.pages.count, 2);
    pdf.dispose();
  });
}
