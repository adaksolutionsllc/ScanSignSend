// Two-finger pinch on a field resizes it (independently per axis), one finger
// moves it, and the result is reported once — when the gesture ends — which is
// when the screens write it to SQLite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/shared/widgets/field_box.dart';

void main() {
  const pageRect = Rect.fromLTWH(0, 0, 400, 600);
  const start = BoundingBox(x: 0.25, y: 0.4, w: 0.5, h: 0.1); // 200×60 px

  Future<List<BoundingBox>> pump(WidgetTester tester) async {
    final changes = <BoundingBox>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            FieldBox(
              bbox: start,
              pageRect: pageRect,
              color: Colors.blue,
              onTap: () {},
              onChanged: changes.add,
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
    return changes;
  }

  testWidgets('horizontal pinch widens the field and keeps it centred', (
    tester,
  ) async {
    final changes = await pump(tester);
    final centre = tester.getCenter(find.byType(FieldBox));

    final a = await tester.startGesture(centre - const Offset(40, 0));
    final b = await tester.startGesture(
      centre + const Offset(40, 0),
      pointer: 2,
    );
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(centre - Offset(40.0 + 4 * i, 0));
      await b.moveTo(centre + Offset(40.0 + 4 * i, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pump();

    expect(changes, hasLength(1), reason: 'one DB write per gesture');
    final r = changes.single;
    expect(r.w, greaterThan(start.w * 1.2), reason: 'spread fingers widen it');
    expect(
      r.h,
      closeTo(start.h, 0.01),
      reason: 'a sideways pinch keeps height',
    );
    expect(r.x + r.w / 2, closeTo(start.x + start.w / 2, 0.01));
  });

  testWidgets('one finger drags the field', (tester) async {
    final changes = await pump(tester);
    await tester.drag(find.byType(FieldBox), const Offset(40, 60));
    await tester.pump();
    expect(changes, hasLength(1));
    expect(changes.single.w, closeTo(start.w, 1e-9));
    expect(changes.single.x, greaterThan(start.x));
    expect(changes.single.y, greaterThan(start.y));
  });

  testWidgets('a checkbox stays square when pinched', (tester) async {
    final changes = <BoundingBox>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            FieldBox(
              bbox: const BoundingBox(
                x: 0.4,
                y: 0.4,
                w: 0.05,
                h: 0.05 * 400 / 600,
              ),
              pageRect: pageRect,
              color: Colors.green,
              shape: FieldBoxShape.square,
              onTap: () {},
              onChanged: changes.add,
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
    final centre = tester.getCenter(find.byType(FieldBox));
    final a = await tester.startGesture(centre - const Offset(20, 0));
    final b = await tester.startGesture(
      centre + const Offset(20, 0),
      pointer: 2,
    );
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(centre - Offset(20.0 + 3 * i, 0));
      await b.moveTo(centre + Offset(20.0 + 3 * i, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pump();

    final r = changes.single;
    expect(
      r.w * pageRect.width,
      closeTo(r.h * pageRect.height, 0.5),
      reason: 'square on the page, even though the pinch was sideways',
    );
    expect(r.w * pageRect.width, greaterThan(20));
  });

  testWidgets('selected field: delete button and corner resize handle', (
    tester,
  ) async {
    final changes = <BoundingBox>[];
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            FieldBox(
              bbox: start,
              pageRect: pageRect,
              color: Colors.blue,
              selected: true,
              onDelete: () => deleted++,
              onTap: () {},
              onChanged: changes.add,
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.close));
    expect(deleted, 1);

    final g = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.open_in_full)),
    );
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(4, 3));
      await tester.pump();
    }
    await g.up();
    await tester.pump();
    expect(changes.single.w, greaterThan(start.w));
    expect(changes.single.h, greaterThan(start.h));
    expect(
      changes.single.x,
      closeTo(start.x, 1e-9),
      reason: 'the corner handle resizes from the top-left anchor',
    );
  });

  testWidgets('an unselected field shows no handles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            FieldBox(
              bbox: start,
              pageRect: pageRect,
              color: Colors.blue,
              showHandles: false,
              onDelete: () {},
              onTap: () {},
              onChanged: (_) {},
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.open_in_full), findsNothing);
  });

  testWidgets('on a dense form, a tap goes to the field it lands in', (
    tester,
  ) async {
    // Two rows 8 px apart: each field's invisible touch margin (18 px)
    // overlaps the other field. The lower one is painted on top.
    const upper = BoundingBox(x: 0.1, y: 0.20, w: 0.6, h: 0.03); // 18 px tall
    const lower = BoundingBox(x: 0.1, y: 0.2433, w: 0.6, h: 0.03);
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            for (final (name, box, other) in [
              ('upper', upper, lower),
              ('lower', lower, upper),
            ])
              FieldBox(
                bbox: box,
                pageRect: pageRect,
                color: Colors.blue,
                showHandles: false,
                neighbours: [other.inPageRect(pageRect)],
                onTap: () => tapped.add(name),
                onChanged: (_) {},
                child: const SizedBox.expand(),
              ),
          ],
        ),
      ),
    );
    final upperRect = upper.inPageRect(pageRect);
    final lowerRect = lower.inPageRect(pageRect);
    await tester.tapAt(upperRect.center);
    await tester.tapAt(
      upperRect.bottomCenter + const Offset(0, 1),
    ); // gap, nearer upper
    await tester.tapAt(lowerRect.center);
    expect(tapped, ['upper', 'upper', 'lower']);
  });
}
