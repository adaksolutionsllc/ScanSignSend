// Review → Select pages → Move to new document: the picked pages and their
// fields leave for a new document; Move is off when every page is picked
// (a document keeps at least one page).

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
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
    root = Directory.systemTemp.createTempSync('sss_split_');
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
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('move picked pages to a new document', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final docId = (await tester.runAsync(() async {
      final docs = DocumentRepository(db);
      final pages = PageRepository(db);
      final doc = await docs.createDocument('Lease');
      final dir = Directory(p.join(root.path, 'pages', 'scan'))
        ..createSync(recursive: true);
      final png = img.encodePng(img.Image(width: 30, height: 40));
      for (var i = 0; i < 3; i++) {
        final f = File(p.join(dir.path, 'page_$i.png'))..writeAsBytesSync(png);
        await pages.addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: f.path,
        );
      }
      await docs.updateDocument(
        DocumentsCompanion(id: Value(doc.id), pageCount: const Value(3)),
      );
      await FieldRepository(db).addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 2,
          type: 'text',
          boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.3,"h":0.05}',
          value: const Value('page three'),
        ),
      );
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
    await tester.tap(find.byKey(const ValueKey('select-pages')));
    await settle(tester);

    // Every page picked: Move is off, Copy is on.
    for (final box in find.byType(Checkbox).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
      await tester.pump();
    }
    expect(find.text(l10n.reviewSelectedPages(3)), findsOneWidget);
    FilledButton copy() =>
        tester.widget(find.byKey(const ValueKey('copy-pages')));
    OutlinedButton move() =>
        tester.widget(find.byKey(const ValueKey('move-pages')));
    expect(copy().onPressed, isNotNull);
    expect(move().onPressed, isNull);

    // Keep only page 3 picked, then move it.
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(move().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('move-pages')));
    await settle(tester);

    final (left, all) = (await tester.runAsync(() async {
      return (
        await PageRepository(db).pagesOf(docId),
        await DocumentRepository(db).watchAll().first,
      );
    }))!;
    expect(left, hasLength(2));
    final made = all.singleWhere((d) => d.id != docId);
    expect(made.title, l10n.extractedName('Lease', '3'));
    final moved = (await tester.runAsync(
      () => FieldRepository(db).watchFields(made.id).first,
    ))!;
    expect(moved.single.value, 'page three');
    expect(moved.single.pageIndex, 0);
    expect(find.text(l10n.newDocumentMade), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).persist,
      isFalse,
      reason: 'the note must not follow the user to other screens',
    );
    expect(find.byType(Checkbox), findsNothing, reason: 'picking ends');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
