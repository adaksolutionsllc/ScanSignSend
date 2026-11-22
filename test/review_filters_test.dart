// Review page filters (F4): Clean shows a worked-out preview and is saved
// for the exports; "Apply to all pages" gives every image page the filter.

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/features/review/presentation/review_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('sss_filters_');
    PathResolver.debugSetDocsDir(root);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => root.path,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'),
        (_) async => null,
      );
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<List<String>> filters(WidgetTester tester, int docId) async =>
      (await tester.runAsync(
        () async => [
          for (final pg in await PageRepository(db).pagesOf(docId))
            pg.activeFilter,
        ],
      ))!;

  testWidgets('Clean on one page, then Apply to all pages', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final docId = (await tester.runAsync(() async {
      final doc = await DocumentRepository(db).createDocument('Notes');
      final dir = Directory(p.join(root.path, 'pages', 'notes'))
        ..createSync(recursive: true);
      final page = img.Image(width: 120, height: 160);
      img.fill(page, color: img.ColorRgb8(150, 145, 140));
      for (var i = 0; i < 2; i++) {
        final f = File(p.join(dir.path, 'page_$i.jpg'))
          ..writeAsBytesSync(img.encodeJpg(page));
        await PageRepository(
          db,
        ).addPage(documentId: doc.id, pageIndex: i, imagePath: f.path);
      }
      return doc.id;
    }))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: ReviewScreen(docId: docId),
        ),
      ),
    );
    await settle(tester);
    expect(await filters(tester, docId), ['enhanced', 'enhanced']);
    expect(find.text(l10n.filterApplyAll), findsNWidgets(2));

    await tester.tap(find.text(l10n.filterClean).first);
    await settle(tester);
    expect(await filters(tester, docId), ['clean', 'enhanced']);
    // The worked-out page replaces the photo once it is ready.
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.filterApplyAll).first);
    await settle(tester);
    expect(await filters(tester, docId), ['clean', 'clean']);
    final chips = tester.widgetList<ChoiceChip>(
      find.widgetWithText(ChoiceChip, l10n.filterClean),
    );
    expect(chips.map((c) => c.selected), [true, true]);
  });

  test('Apply to all leaves imported PDF pages alone', () async {
    final doc = await DocumentRepository(db).createDocument('Mixed');
    final pages = PageRepository(db);
    await pages.addPage(
      documentId: doc.id,
      pageIndex: 0,
      imagePath: p.join(root.path, 'a.jpg'),
    );
    await pages.addPage(
      documentId: doc.id,
      pageIndex: 1,
      imagePath: p.join(root.path, 'form.pdf#page=0'),
    );
    final other = await DocumentRepository(db).createDocument('Other');
    await pages.addPage(
      documentId: other.id,
      pageIndex: 0,
      imagePath: p.join(root.path, 'b.jpg'),
    );
    await pages.setFilterForAll(doc.id, 'bw');
    expect(
      [for (final pg in await pages.pagesOf(doc.id)) pg.activeFilter],
      ['bw', 'enhanced'],
    );
    expect((await pages.pagesOf(other.id)).single.activeFilter, 'enhanced');
  });

  testWidgets('one page: no Apply to all', (tester) async {
    final docId = (await tester.runAsync(() async {
      final doc = await DocumentRepository(db).createDocument('One');
      final f = File(p.join(root.path, 'one.jpg'))
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 30, height: 40)));
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: 0, imagePath: f.path);
      return doc.id;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: ReviewScreen(docId: docId),
        ),
      ),
    );
    await settle(tester);
    expect(find.text(l10n.filterClean), findsOneWidget);
    expect(find.text(l10n.filterApplyAll), findsNothing);
  });
}
