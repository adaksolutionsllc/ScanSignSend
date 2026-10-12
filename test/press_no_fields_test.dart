// A document with no fields can still be kept as a plain PDF (the scanner /
// organiser use), after the user confirms. Flatten & Sign isn't offered:
// there's nothing signed for its certificate page to record.

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/press/presentation/press_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;

  // Synchronous stream close: otherwise drift leaves a cleanup timer behind
  // when the screen's field stream is cancelled, which widget tests reject.
  setUp(
    () => db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    ),
  );
  tearDown(() => db.close());

  Future<int> newDoc(WidgetTester tester, {required bool withField}) async =>
      (await tester.runAsync(() async {
        final doc = await DocumentRepository(db).createDocument('Lease');
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

  Future<void> open(WidgetTester tester, int docId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => PressScreen(docId: docId)),
              GoRoute(
                path: AppRoutes.send,
                builder: (_, s) => Text('send ${s.pathParameters['docId']}'),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  /// Unmounts the screen so drift's stream cleanup timer runs before the
  /// test ends.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  ButtonStyleButton button(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );

  testWidgets('no fields: Save PDF asks first, and Cancel keeps the doc', (
    tester,
  ) async {
    final docId = await newDoc(tester, withField: false);
    await open(tester, docId);
    expect(find.text(l10n.pressNoFieldsTitle), findsOneWidget);
    expect(find.text(l10n.pressAddFields), findsOneWidget);
    expect(find.text(l10n.pressFlattenAndSign), findsNothing);
    expect(find.text(l10n.pressSaveDraft), findsNothing);
    expect(button(tester, l10n.pressSavePdf).onPressed, isNotNull);

    await tester.tap(find.text(l10n.pressSavePdf));
    await tester.pumpAndSettle();
    expect(find.text(l10n.saveNoFieldsTitle), findsOneWidget);
    expect(find.text(l10n.saveNoFieldsBody), findsOneWidget);

    await tester.tap(find.text(l10n.actionCancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.saveNoFieldsTitle), findsNothing);
    final doc = await tester.runAsync(
      () => DocumentRepository(db).getById(docId),
    );
    expect(doc!.fillablePdfPath, isNull, reason: 'Cancel must not save');
    expect(doc.countedFree, isFalse);
    await close(tester);
  });

  testWidgets('with a field: both finish buttons are on', (tester) async {
    await open(tester, await newDoc(tester, withField: true));
    expect(find.text(l10n.pressNoFieldsTitle), findsNothing);
    expect(find.text(l10n.pressFieldSummary), findsOneWidget);
    expect(button(tester, l10n.pressSaveDraft).onPressed, isNotNull);
    expect(button(tester, l10n.pressFlattenAndSign).onPressed, isNotNull);
    await close(tester);
  });

  testWidgets('adding a field brings back the usual finish buttons', (
    tester,
  ) async {
    final docId = await newDoc(tester, withField: false);
    await open(tester, docId);
    expect(find.text(l10n.pressSaveDraft), findsNothing);
    await tester.runAsync(
      () => FieldRepository(db).addField(
        FieldsCompanion.insert(
          documentId: docId,
          pageIndex: 0,
          type: 'signature',
          boundingBoxJson: '{"x":0.1,"y":0.8,"w":0.3,"h":0.06}',
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(button(tester, l10n.pressSaveDraft).onPressed, isNotNull);
    expect(button(tester, l10n.pressFlattenAndSign).onPressed, isNotNull);
    expect(find.text(l10n.pressSavePdf), findsNothing);
    await close(tester);
  });
}
