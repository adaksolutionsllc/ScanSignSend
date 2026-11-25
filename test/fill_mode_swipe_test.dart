// A document with no fields (a plain PDF or scan) swipes between pages in
// Fill mode; a document with fields keeps the page still, so a swipe never
// fights a field (tester report, build 26). The page chips follow the swipe.

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/db/app_database.dart' hide Page;
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/fill_mode/presentation/fill_mode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    tmp = Directory.systemTemp.createTempSync('fill_swipe_');
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> newDoc(
    WidgetTester tester, {
    int pages = 3,
    bool withField = false,
  }) async => (await tester.runAsync(() async {
    final doc = await DocumentRepository(db).createDocument('Deed');
    for (var i = 0; i < pages; i++) {
      final png = File('${tmp.path}/page_$i.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 10)));
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: i, imagePath: png.path);
    }
    if (withField) {
      await FieldRepository(db).addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: 'text',
          boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.3,"h":0.05}',
          label: const Value('Name'),
        ),
      );
    }
    return doc.id;
  }))!;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, int docId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: FillModeScreen(docId: docId),
        ),
      ),
    );
    await settle(tester);
  }

  /// Unmounts the screen so drift's stream cleanup runs before the test ends.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  /// The label of the selected page chip ("1", "2", …).
  String selectedChip(WidgetTester tester) {
    final chip = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .singleWhere((c) => c.selected);
    return (chip.label as Text).data!;
  }

  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await settle(tester);
  }

  testWidgets('no fields: swiping moves to the next page and its chip', (
    tester,
  ) async {
    await open(tester, await newDoc(tester));
    expect(find.byType(PageView), findsOneWidget);
    expect(selectedChip(tester), '1');

    await swipeLeft(tester);
    expect(selectedChip(tester), '2');
    await swipeLeft(tester);
    expect(selectedChip(tester), '3');

    // Back the other way.
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await settle(tester);
    expect(selectedChip(tester), '2');
    await close(tester);
  });

  testWidgets('no fields: tapping a chip moves the pages there', (
    tester,
  ) async {
    await open(tester, await newDoc(tester));
    await tester.tap(find.widgetWithText(ChoiceChip, '3'));
    await settle(tester);
    expect(selectedChip(tester), '3');
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pager.page, 2);
    await close(tester);
  });

  testWidgets('no fields: the chip row scrolls to a page swiped to', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester, await newDoc(tester, pages: 30));
    final row = find.ancestor(
      of: find.widgetWithText(ChoiceChip, '1'),
      matching: find.byType(Scrollable),
    );
    final scroll = tester.state<ScrollableState>(row).position;
    expect(scroll.pixels, 0);

    for (var i = 0; i < 12; i++) {
      await swipeLeft(tester);
    }
    expect(selectedChip(tester), '13');
    expect(scroll.pixels, greaterThan(0));
    final chip = tester.getRect(find.widgetWithText(ChoiceChip, '13'));
    expect(chip.left, greaterThanOrEqualTo(0));
    expect(chip.right, lessThanOrEqualTo(400));
    await close(tester);
  });

  testWidgets('with a field: the page does not swipe', (tester) async {
    await open(tester, await newDoc(tester, withField: true));
    expect(find.byType(PageView), findsNothing);
    await tester.fling(
      find.byType(FillModeScreen),
      const Offset(-300, 0),
      1000,
    );
    await settle(tester);
    expect(selectedChip(tester), '1');
    await close(tester);
  });

  testWidgets('one page: no chips and no swipe', (tester) async {
    await open(tester, await newDoc(tester, pages: 1));
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    await close(tester);
  });
}
