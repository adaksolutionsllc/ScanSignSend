import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/iap_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/library/presentation/library_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

SemanticsHandle? _semantics;

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // ML Kit's recogniser is created (never used) by the sorter's providers.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
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
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      // Advance the clock too: sheets and dialogs animate in.
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<int> addDoc(WidgetTester tester, String title, String? category) =>
      tester
          .runAsync(() async {
            final d = await DocumentRepository(db).createDocument(title);
            await DocumentRepository(db).updateDocument(
              DocumentsCompanion(id: Value(d.id), category: Value(category)),
            );
            return d.id;
          })
          .then((v) => v!);

  Future<Document> doc(WidgetTester tester, int id) =>
      tester.runAsync(() => DocumentRepository(db).getById(id)).then((d) => d!);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(3000, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    _semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          isPurchasedProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    _semantics?.dispose();
    _semantics = null;
  }

  testWidgets('no chips until a document has a category', (tester) async {
    await addDoc(tester, 'Plain', null);
    await open(tester);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text(l10n.categoryNone), findsOneWidget); // on the card
    await close(tester);
  });

  testWidgets('chips filter the grid by category', (tester) async {
    await addDoc(tester, 'Lease', 'home');
    await addDoc(tester, 'W-4', 'tax');
    await addDoc(tester, 'Notes', null);
    await open(tester);

    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(4)); // All, Home, Tax, No category
    await tester.tap(find.widgetWithText(ChoiceChip, l10n.categoryTax));
    await settle(tester);
    expect(find.text('W-4'), findsOneWidget);
    expect(find.text('Lease'), findsNothing);
    expect(find.text('Notes'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, l10n.categoryNone));
    await settle(tester);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('W-4'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, l10n.libraryTabAll));
    await settle(tester);
    expect(find.text('Lease'), findsOneWidget);
    await close(tester);
  });

  testWidgets('changing a category from the card sticks as the user’s choice', (
    tester,
  ) async {
    final id = await addDoc(tester, 'Visit', 'tax');
    await open(tester);

    await tester.tap(
      find.bySemanticsLabel('${l10n.categoryChange}: ${l10n.categoryTax}'),
    );
    await settle(tester);
    expect(find.text(l10n.categorySortedAutomatically), findsOneWidget);
    await tester.tap(find.text(l10n.categoryMedical).last);
    await settle(tester);

    final after = await doc(tester, id);
    expect(after.category, 'medical');
    expect(after.categoryManual, isTrue);
    await close(tester);
  });

  testWidgets('a new category can be created from the sheet', (tester) async {
    final id = await addDoc(tester, 'Car loan', null);
    await open(tester);
    await tester.tap(
      find.bySemanticsLabel('${l10n.categoryChange}: ${l10n.categoryNone}'),
    );
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text(l10n.categoryNew),
      100,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text(l10n.categoryNew));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Car',
    );
    await tester.tap(find.text(l10n.actionSave));
    await settle(tester);

    final after = await doc(tester, id);
    expect(after.category, startsWith('u:'));
    expect(find.text('Car'), findsWidgets); // card + chip
    await close(tester);
  });

  testWidgets(
    'long-press selects; selected documents move or delete together',
    (tester) async {
      final a = await addDoc(tester, 'One', null);
      final b = await addDoc(tester, 'Two', null);
      final c = await addDoc(tester, 'Three', null);
      await open(tester);

      await tester.longPress(find.text('One'));
      await settle(tester);
      expect(find.text(l10n.librarySelectedCount(1)), findsOneWidget);
      await tester.tap(find.text('Two')); // a tap now selects
      await settle(tester);
      expect(find.text(l10n.librarySelectedCount(2)), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.categoryChange));
      await settle(tester);
      await tester.tap(find.text(l10n.categorySchool).last);
      await settle(tester);
      expect((await doc(tester, a)).category, 'school');
      expect((await doc(tester, b)).category, 'school');
      expect((await doc(tester, c)).category, isNull);
      expect(find.text(l10n.librarySelectedCount(2)), findsNothing);

      await tester.longPress(find.text('Three'));
      await settle(tester);
      await tester.tap(find.byTooltip(l10n.actionDelete));
      await settle(tester);
      expect(find.text(l10n.libraryDeleteManyTitle(1)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l10n.actionDelete));
      await settle(tester);
      expect(
        await tester.runAsync(() => DocumentRepository(db).getById(c)),
        isNull,
      );
      expect(find.text('One'), findsOneWidget);
      await close(tester);
    },
  );
}
