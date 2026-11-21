// Edge and corner detection for picked/opened photos (the Dart detector used
// on Android), the "is a fix worth asking?" rule, the crop itself, and the
// grouping of files opened together.

import 'dart:math' as math;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/document_model.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/opened_file_service.dart';

/// A white sheet with the given corners (pixels) on a dark table, with a few
/// dark "text" lines on the sheet.
img.Image photo(List<math.Point<int>> corners, {int w = 800, int h = 1000}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(60, 50, 45));
  img.fillPolygon(
    image,
    vertices: [for (final c in corners) img.Point(c.x, c.y)],
    color: img.ColorRgb8(245, 245, 240),
  );
  final cx = corners.map((c) => c.x).reduce((a, b) => a + b) ~/ 4;
  final cy = corners.map((c) => c.y).reduce((a, b) => a + b) ~/ 4;
  for (var i = -3; i <= 3; i++) {
    img.fillRect(
      image,
      x1: cx - 150,
      y1: cy + i * 40,
      x2: cx + 150,
      y2: cy + i * 40 + 6,
      color: img.ColorRgb8(30, 30, 30),
    );
  }
  return image;
}

void main() {
  group('detectDocumentEdges', () {
    test('finds a tilted sheet on a dark table', () {
      final corners = [
        const math.Point(140, 120),
        const math.Point(660, 90),
        const math.Point(700, 880),
        const math.Point(100, 900),
      ];
      final quad = detectDocumentEdges(photo(corners))!;
      final found = quad.points;
      for (var i = 0; i < 4; i++) {
        final want = math.Point(corners[i].x / 800, corners[i].y / 1000);
        expect(
          found[i].distanceTo(want),
          lessThan(0.03),
          reason: 'corner $i: ${found[i]} vs $want',
        );
      }
      expect(quad.worthCropping, isTrue);
    });

    test('a page that already fills the photo needs no fix', () {
      final page = photo([
        const math.Point(0, 0),
        const math.Point(799, 0),
        const math.Point(799, 999),
        const math.Point(0, 999),
      ]);
      final quad = detectDocumentEdges(page);
      expect(quad == null || !quad.worthCropping, isTrue, reason: '$quad');
    });

    test('a photo of one tone has nothing to find', () {
      final flat = img.Image(width: 400, height: 400);
      img.fill(flat, color: img.ColorRgb8(128, 128, 128));
      expect(detectDocumentEdges(flat), isNull);
    });

    test('a round bright blob is not a page', () {
      final image = img.Image(width: 600, height: 600);
      img.fill(image, color: img.ColorRgb8(40, 40, 40));
      img.fillCircle(
        image,
        x: 300,
        y: 300,
        radius: 220,
        color: img.ColorRgb8(240, 240, 240),
      );
      final quad = detectDocumentEdges(image);
      expect(quad, isNull, reason: '$quad');
    });
  });

  group('EdgeQuad', () {
    test('worthCropping: full image no, inset yes, sliver no', () {
      expect(EdgeQuad.full.worthCropping, isFalse);
      const inset = EdgeQuad(
        math.Point(0.1, 0.1),
        math.Point(0.9, 0.1),
        math.Point(0.9, 0.9),
        math.Point(0.1, 0.9),
      );
      expect(inset.worthCropping, isTrue);
      const sliver = EdgeQuad(
        math.Point(0.4, 0.4),
        math.Point(0.5, 0.4),
        math.Point(0.5, 0.5),
        math.Point(0.4, 0.5),
      );
      expect(sliver.worthCropping, isFalse);
    });

    test('a crossed (bow-tie) quad is not convex', () {
      const crossed = EdgeQuad(
        math.Point(0.1, 0.1),
        math.Point(0.9, 0.9),
        math.Point(0.9, 0.1),
        math.Point(0.1, 0.9),
      );
      expect(crossed.isConvex, isFalse);
      expect(crossed.worthCropping, isFalse);
    });

    test('round-trips through the channel list form', () {
      const q = EdgeQuad(
        math.Point(0.1, 0.2),
        math.Point(0.8, 0.15),
        math.Point(0.85, 0.9),
        math.Point(0.12, 0.95),
      );
      final back = EdgeQuad.fromList(q.toList())!;
      expect(back.toList(), q.toList());
      expect(EdgeQuad.fromList([1, 2, 3]), isNull);
      expect(EdgeQuad.fromList(null), isNull);
    });
  });

  test('cropToQuad straightens to the quad\'s own size', () {
    final src = photo([
      const math.Point(100, 100),
      const math.Point(700, 100),
      const math.Point(700, 900),
      const math.Point(100, 900),
    ]);
    const quad = EdgeQuad(
      math.Point(100 / 800, 100 / 1000),
      math.Point(700 / 800, 100 / 1000),
      math.Point(700 / 800, 900 / 1000),
      math.Point(100 / 800, 900 / 1000),
    );
    final out = cropToQuad(src, quad);
    expect(out.width, 600);
    expect(out.height, 800);
    // Corners of the result are paper, not the dark table.
    for (final (x, y) in [(3, 3), (596, 3), (596, 796), (3, 796)]) {
      expect(out.getPixel(x, y).r, greaterThan(200), reason: '($x, $y)');
    }
  });

  test('files opened together: each PDF alone, all photos as one', () {
    const a = OpenedFile(path: '/t/1/a.pdf', name: 'a.pdf');
    const b = OpenedFile(path: '/t/2/b.JPG', name: 'b.JPG');
    const c = OpenedFile(path: '/t/3/c.heic', name: 'c.heic');
    const d = OpenedFile(path: '/t/4/d.pdf', name: 'd.pdf');
    final groups = OpenedFileService.groupOpened([a, b, c, d]);
    expect(groups.map((g) => g.map((f) => f.name).toList()).toList(), [
      ['a.pdf'],
      ['d.pdf'],
      ['b.JPG', 'c.heic'],
    ]);
    expect(OpenedFileService.groupOpened(const []), isEmpty);

    // Photos from two separate opens stay two documents.
    const p1 = OpenedFile(path: '/t/5/p.jpg', name: 'p.jpg', batch: 'x');
    const p2 = OpenedFile(path: '/t/6/q.jpg', name: 'q.jpg', batch: 'x');
    const p3 = OpenedFile(path: '/t/7/r.png', name: 'r.png', batch: 'y');
    expect(
      OpenedFileService.groupOpened([
        p1,
        p3,
        p2,
      ]).map((g) => g.map((f) => f.name).toList()).toList(),
      [
        ['p.jpg', 'q.jpg'],
        ['r.png'],
      ],
    );
  });

  test('markCompleted locks the document with its PDF', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(db.close);
    final repo = DocumentRepository(db);
    final doc = await repo.createDocument('Receipt');
    expect(doc.statusEnum, DocumentStatus.draft);
    await repo.markCompleted(doc.id, '/tmp/receipt.pdf');
    final after = (await repo.getById(doc.id))!;
    expect(after.statusEnum, DocumentStatus.pressed);
    expect(after.pressedPdfPath, isNotNull);
  });
}
