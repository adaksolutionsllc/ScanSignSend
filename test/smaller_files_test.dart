// Smaller files: page photos go into a PDF at 200 dpi for the page they are
// printed on (not at camera size), with their Review filter, B&W as
// grayscale. Send → "Smaller file" writes a separate copy at 150 dpi that
// leaves the document's own PDF, and a completed one's date, as they were.

import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/fillable_form_export_service.dart';
import 'package:scan_sign_send/core/services/page_image.dart';
import 'package:scan_sign_send/core/services/press_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A colourful, noisy photo: hard to compress, like a real one.
Uint8List photo(int w, int h, {int seed = 1}) {
  final r = Random(seed);
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(
        x,
        y,
        180 + r.nextInt(60),
        120 + r.nextInt(80),
        60 + r.nextInt(60),
      );
    }
  }
  return img.encodeJpg(im, quality: 92);
}

const a4w = 595.0, a4h = 842.0;

const cert = PressCertificateStrings(
  title: 'Certificate',
  documentLabel: 'Document',
  signedOnLabel: 'Signed on',
  methodLabel: 'Method',
  methodValue: 'Drawn',
  noteLabel: 'Note',
  noteValue: 'Offline',
  dateFormat: 'd MMMM y, HH:mm',
  localeName: 'en',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('page photos', () {
    final big = photo(1800, 2400);

    test('a camera-sized photo shrinks to 200 dpi for an A4 page', () {
      final out = img.decodeJpg(
        pageImageForPdf(big, filter: 'original', pageW: a4w, pageH: a4h),
      )!;
      // A 3:4 photo fills an A4 page's width first: 595 pt at 200 dpi.
      expect(out.width, closeTo(595 / 72 * 200, 1));
      expect(out.height, closeTo(2400 * out.width / 1800, 1));
    });

    test('Smaller file is 150 dpi and lighter', () {
      final standard = pageImageForPdf(
        big,
        filter: 'original',
        pageW: a4w,
        pageH: a4h,
      );
      final smaller = pageImageForPdf(
        big,
        filter: 'original',
        pageW: a4w,
        pageH: a4h,
        quality: PageImageQuality.smaller,
      );
      expect(img.decodeJpg(smaller)!.width, closeTo(595 / 72 * 150, 1));
      expect(smaller.length, lessThan(standard.length * 0.6));
    });

    test('a small photo is left alone; B&W is gray', () {
      final small = photo(400, 560, seed: 2);
      expect(
        pageImageForPdf(small, filter: 'original', pageW: a4w, pageH: a4h),
        same(small),
      );
      final bw = img.decodeJpg(
        pageImageForPdf(small, filter: 'bw', pageW: a4w, pageH: a4h),
      )!;
      // Gray, not tinted (a one-channel encode once came out red).
      for (final px in [bw.getPixel(10, 10), bw.getPixel(200, 300)]) {
        expect(px.g, closeTo(px.r, 3));
        expect(px.b, closeTo(px.r, 3));
        expect(px.r, greaterThan(60));
      }
      final notImage = Uint8List.fromList([1, 2, 3]);
      expect(
        pageImageForPdf(notImage, filter: 'bw', pageW: a4w, pageH: a4h),
        same(notImage),
      );
    });
  });

  group('exports', () {
    late Directory docsDir;
    late AppDatabase db;
    late DocumentRepository docs;
    late PageRepository pages;
    late FieldRepository fields;

    setUp(() async {
      await initializeDateFormatting('en');
      docsDir = await Directory.systemTemp.createTemp('sss_small_');
      PathResolver.debugSetDocsDir(docsDir);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => docsDir.path,
          );
      db = AppDatabase.forTesting(NativeDatabase.memory());
      docs = DocumentRepository(db);
      pages = PageRepository(db);
      fields = FieldRepository(db);
    });

    tearDown(() async {
      await db.close();
      await docsDir.delete(recursive: true);
    });

    Future<(Document, int)> scanned(String filter) async {
      final dir = Directory(p.join(docsDir.path, 'pages', 'u'))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'page_$filter.jpg'))
        ..writeAsBytesSync(photo(1800, 2400));
      final doc = await docs.createDocument('Lease');
      final id = await pages.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: file.path,
      );
      await pages.updatePage(
        PagesCompanion(id: Value(id), activeFilter: Value(filter)),
      );
      return (doc, file.lengthSync());
    }

    int size(String path) => File(path).lengthSync();

    test('completed: smaller copy, same PDF and same date kept', () async {
      final (doc, photoSize) = await scanned('original');
      final press = PressService(docs, pages, fields);
      final out = await press.press(doc.id, cert);
      expect(size(out), lessThan(photoSize), reason: 'not camera size');

      // The time it was completed, as the certificate shows it.
      final completed = DateTime(2026, 3, 4, 5, 6);
      await docs.updateDocument(
        DocumentsCompanion(id: Value(doc.id), updatedAt: Value(completed)),
      );
      final copy = await press.smallerCopy(doc.id, cert);
      expect(size(copy), lessThan(size(out) * 0.7));
      final after = (await docs.getById(doc.id))!;
      expect(PathResolver.resolve(after.pressedPdfPath!), out);
      expect(after.updatedAt, completed);
      final pdf = PdfDocument(inputBytes: File(copy).readAsBytesSync());
      final text = PdfTextExtractor(pdf).extractText(startPageIndex: 1);
      pdf.dispose();
      expect(
        text,
        contains(DateFormat(cert.dateFormat, 'en').format(completed)),
      );
    });

    test('fillable: the page filter shows, and a smaller copy', () async {
      final (colour, _) = await scanned('original');
      final (bw, _) = await scanned('bw');
      final export = FillableFormExportService(docs, pages, fields);
      final colourOut = await export.export(colour.id);
      final bwOut = await export.export(bw.id);
      // The page photo as embedded (JPEG, start to end marker).
      img.Image embedded(String pdf) {
        final b = File(pdf).readAsBytesSync();
        var s = 0;
        while (!(b[s] == 0xFF && b[s + 1] == 0xD8 && b[s + 2] == 0xFF)) {
          s++;
        }
        var e = s + 2;
        while (!(b[e] == 0xFF && b[e + 1] == 0xD9)) {
          e++;
        }
        return img.decodeJpg(b.sublist(s, e + 2))!;
      }

      final c = embedded(colourOut).getPixel(50, 50);
      final g = embedded(bwOut).getPixel(50, 50);
      expect((c.r - c.b).abs(), greaterThan(40), reason: 'colour stays');
      expect(g.b, closeTo(g.r, 3), reason: 'B&W shows in the export');

      final copy = await export.smallerCopy(colour.id);
      expect(size(copy), lessThan(size(colourOut) * 0.7));
      expect(
        PathResolver.resolve((await docs.getById(colour.id))!.fillablePdfPath!),
        colourOut,
      );
    });
  });
}
