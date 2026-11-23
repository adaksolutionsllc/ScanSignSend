// The edge check on imports (1.3.1): which pages it would look at (the user
// is asked first when there are several), progress while it crops, one-pass
// saving of rendered PDF pages, at most two pages at a time, and the signal
// that lets reading every page's text wait until it ends.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/services/import_service.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// A white sheet on a dark table, slightly tilted.
img.Image _photo() {
  final image = img.Image(width: 400, height: 500);
  img.fill(image, color: img.ColorRgb8(60, 50, 45));
  img.fillPolygon(
    image,
    vertices: [
      img.Point(70, 60),
      img.Point(330, 45),
      img.Point(350, 440),
      img.Point(50, 450),
    ],
    color: img.ColorRgb8(245, 245, 240),
  );
  return image;
}

const _quad = EdgeQuad(
  math.Point(0.175, 0.12),
  math.Point(0.825, 0.09),
  math.Point(0.875, 0.88),
  math.Point(0.125, 0.9),
);

void main() {
  late AppDatabase db;
  late Directory tmp;
  late DocumentRepository docs;
  late PageRepository pages;
  late EdgeCheckService edges;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('edge_check');
    PathResolver.debugSetDocsDir(tmp);
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    docs = DocumentRepository(db);
    pages = PageRepository(db);
    edges = EdgeCheckService(docs, pages, PageRasterService());
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// A document of [n] photo pages, stored the way imports store them.
  Future<int> photos(int n, {String title = 'Photos'}) async {
    final doc = await docs.createDocument(title);
    final dir = Directory(p.join(tmp.path, 'pages', '${doc.id}'))
      ..createSync(recursive: true);
    for (var i = 0; i < n; i++) {
      final f = File(p.join(dir.path, 'page_$i.jpg'))
        ..writeAsBytesSync(img.encodeJpg(_photo()));
      await pages.addPage(
        documentId: doc.id,
        pageIndex: i,
        imagePath: PathResolver.toStorable(f.path),
      );
    }
    return doc.id;
  }

  /// A document backed by a 2-page PDF: typed text, or only pictures.
  Future<int> pdf({required bool typed}) async {
    final out = PdfDocument();
    for (var i = 0; i < 2; i++) {
      final page = out.pages.add();
      if (typed) {
        page.graphics.drawString(
          'Typed page $i',
          PdfStandardFont(PdfFontFamily.helvetica, 18),
          bounds: const Rect.fromLTWH(40, 40, 300, 40),
        );
      } else {
        page.graphics.drawImage(
          PdfBitmap(img.encodeJpg(_photo())),
          const Rect.fromLTWH(0, 0, 400, 500),
        );
      }
    }
    final doc = await docs.createDocument(typed ? 'Typed' : 'Scan');
    final dir = Directory(p.join(tmp.path, 'pages', 'pdf${doc.id}'))
      ..createSync(recursive: true);
    final f = File(p.join(dir.path, 'source.pdf'))
      ..writeAsBytesSync(await out.save());
    out.dispose();
    for (var i = 0; i < 2; i++) {
      await pages.addPage(
        documentId: doc.id,
        pageIndex: i,
        imagePath: '${PathResolver.toStorable(f.path)}#page=$i',
      );
    }
    return doc.id;
  }

  group('checkablePages (the user is asked when there are 2 or more)', () {
    test('every photo page', () async {
      expect(await edges.checkablePages(await photos(3)), hasLength(3));
      expect(await edges.checkablePages(await photos(1)), hasLength(1));
    });

    test('a PDF only when every page is a picture', () async {
      expect(await edges.checkablePages(await pdf(typed: false)), hasLength(2));
      expect(await edges.checkablePages(await pdf(typed: true)), isEmpty);
    });

    test('never a PDF with its own form fields', () async {
      final id = await pdf(typed: false);
      await docs.updateDocument(
        DocumentsCompanion(
          id: Value(id),
          ocrText: const Value(ImportService.formFieldsSentinel),
        ),
      );
      expect(await edges.checkablePages(id), isEmpty);
    });

    test('an unknown document', () async {
      expect(await edges.checkablePages(999), isEmpty);
    });
  });

  test('apply crops photo pages, reports progress and failures', () async {
    final id = await photos(3);
    final before = await pages.pagesOf(id);
    // Page 2's file is gone: its crop fails, the others go on.
    File(PathResolver.resolve(before[2].imagePath)).deleteSync();
    final progress = <(int, int)>[];
    final failed = await edges.apply(id, {
      before[0].id: _quad,
      before[2].id: _quad,
    }, onProgress: (done, total) => progress.add((done, total)));
    expect(failed, [before[2].id]);
    expect(progress.first, (0, 2));
    expect(progress.last, (2, 2));
    expect(progress, hasLength(3));

    final after = await pages.pagesOf(id);
    expect(after[0].imagePath, isNot(before[0].imagePath));
    expect(
      File(PathResolver.resolve(before[0].imagePath)).existsSync(),
      isFalse,
      reason: 'the uncropped file is removed',
    );
    final cropped = img.decodeJpg(
      File(PathResolver.resolve(after[0].imagePath)).readAsBytesSync(),
    )!;
    expect(cropped.width, lessThan(400));
    expect(after[1].imagePath, before[1].imagePath, reason: 'not chosen');
    expect(after[2].imagePath, before[2].imagePath, reason: 'failed');
  });

  test('Skip while cropping: no new page starts, done pages stay', () async {
    final id = await photos(3);
    final before = await pages.pagesOf(id);
    var skipped = false;
    final failed = await edges.apply(
      id,
      {for (final pg in before) pg.id: _quad},
      // Skip tapped once the first page is done (two run at a time).
      onProgress: (done, _) => skipped = skipped || done >= 1,
      stop: () => skipped,
    );
    expect(failed, isEmpty, reason: 'a skipped page is not a failure');
    final after = await pages.pagesOf(id);
    expect(after[0].imagePath, isNot(before[0].imagePath));
    expect(after[2].imagePath, before[2].imagePath, reason: 'not started');
    expect(
      File(PathResolver.resolve(before[2].imagePath)).existsSync(),
      isTrue,
    );
  });

  test('Skip while checking: no pages offered', () async {
    final id = await photos(3);
    var checked = 0;
    final found = await edges.candidatesFor(
      id,
      onProgress: (_, _) => checked++,
      stop: () => checked >= 1,
    );
    expect(found, isEmpty);
    expect(checked, 1);
  });

  test('the time estimate learns from this phone\'s own runs', () async {
    final id = await photos(2);
    final two = await pages.pagesOf(id);
    // A first guess before any run: 1.5 s to check, 4 s to straighten.
    expect(await edges.estimateFor(two), const Duration(seconds: 11));

    await edges.candidatesFor(id);
    await edges.apply(id, {for (final pg in two) pg.id: _quad});
    final prefs = await SharedPreferences.getInstance();
    final check = prefs.getDouble(EdgeCheckService.checkMsKey)!;
    final straighten = prefs.getDouble(EdgeCheckService.straightenMsKey)!;
    expect(
      await edges.estimateFor(two),
      Duration(milliseconds: (2 * (check + straighten)).round()),
    );
    expect(straighten, lessThan(4000), reason: 'small test photos');

    // A running average: one run moves it halfway.
    await prefs.setDouble(EdgeCheckService.straightenMsKey, 10000);
    await edges.apply(id, {two.first.id: _quad});
    final after = prefs.getDouble(EdgeCheckService.straightenMsKey)!;
    expect(after, greaterThan(5000));
    expect(after, lessThan(10000));
  });

  test('a skipped run teaches nothing', () async {
    final id = await photos(3);
    final three = await pages.pagesOf(id);
    await edges.candidatesFor(id, stop: () => true);
    await edges.apply(id, {
      for (final pg in three) pg.id: _quad,
    }, stop: () => true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(EdgeCheckService.checkMsKey), isNull);
    expect(prefs.getDouble(EdgeCheckService.straightenMsKey), isNull);
  });

  test('nothing chosen: nothing done, no progress', () async {
    final id = await photos(2);
    var calls = 0;
    expect(
      await edges.apply(id, const {}, onProgress: (_, _) => calls++),
      isEmpty,
    );
    expect(calls, 0);
  });

  group('saveRender (a rendered PDF page saved in one pass)', () {
    final page = _photo();
    late String out;
    setUp(() => out = p.join(tmp.path, 'out.jpg'));

    bool save(List<double>? quad) => saveRender((
      page.convert(numChannels: 4).toUint8List(),
      page.width,
      page.height,
      quad,
      out,
    ));

    img.Image saved() => img.decodeJpg(File(out).readAsBytesSync())!;

    test('whole page when no corners are given', () {
      expect(save(null), isFalse);
      expect((saved().width, saved().height), (400, 500));
      // The same picture, not a blank or shifted one.
      final a = saved().getPixel(200, 250), b = page.getPixel(200, 250);
      expect((a.r - b.r).abs(), lessThan(8));
      expect(saved().getPixel(5, 5).r, lessThan(90), reason: 'table');
    });

    test('cropped like the photo path', () {
      expect(save(_quad.toList()), isTrue);
      final want = cropToQuad(page, _quad);
      expect((saved().width, saved().height), (want.width, want.height));
      // The table is cut away: the corners are paper now.
      expect(saved().getPixel(3, 3).r, greaterThan(200));
    });

    test('a bad crop keeps the whole page and says so', () {
      expect(save([0.1, 0.1, 0.9]), isFalse);
      expect(saved().width, 400);
    });

    test('a page with no background is white, not black', () {
      // What PDFKit and PdfRenderer give for a page that paints no
      // background: transparent everywhere except the ink. The JPEG encoder
      // puts it on white.
      final pixels = Uint8List(40 * 50 * 4);
      for (var i = 0; i < 40 * 4; i += 4) {
        pixels[i + 3] = 255; // one black line of text, at the top
      }
      saveRender((pixels, 40, 50, null, out));
      expect(saved().getPixel(20, 30).r, greaterThan(245));
      expect(saved().getPixel(20, 0).r, lessThan(40));
    });
  });

  group('runTwoAtATime', () {
    test('runs every job, never more than two at once', () async {
      var running = 0, most = 0;
      final done = <int>[];
      await runTwoAtATime(List.generate(7, (i) => i), (i) async {
        running++;
        most = math.max(most, running);
        await Future<void>.delayed(Duration(milliseconds: 5 + (i % 3) * 5));
        running--;
        done.add(i);
      });
      expect(done..sort(), List.generate(7, (i) => i));
      expect(most, 2);
    });

    test(
      'a failure: no new job, the other finishes, then it is thrown',
      () async {
        var slowEnded = false;
        final started = <int>[];
        await expectLater(
          runTwoAtATime([0, 1, 2, 3], (i) async {
            started.add(i);
            if (i == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 30));
              slowEnded = true;
            } else {
              throw StateError('page $i');
            }
          }),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', 'page 1'),
          ),
        );
        expect(slowEnded, isTrue);
        expect(started, [0, 1]);
      },
    );
  });

  test('whenDone waits for end, at once when nothing runs', () async {
    await edges.whenDone(1); // nothing began: does not wait
    edges.begin(1);
    var ended = false;
    unawaited(edges.whenDone(1).then((_) => ended = true));
    await Future<void>.delayed(Duration.zero);
    expect(ended, isFalse);
    edges.end(1);
    edges.end(1); // twice is fine
    await Future<void>.delayed(Duration.zero);
    expect(ended, isTrue);
  });
}
