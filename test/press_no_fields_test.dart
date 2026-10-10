// A document with no fields can't be finished: there's nothing to fill or
// sign, and on the free tier it would use up a document for nothing.

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
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
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: PressScreen(docId: docId),
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

  testWidgets('no fields: both finish buttons are off, with a way forward', (
    tester,
  ) async {
    await open(tester, await newDoc(tester, withField: false));
    expect(find.text(l10n.pressNoFieldsTitle), findsOneWidget);
    expect(find.text(l10n.pressAddFields), findsOneWidget);
    expect(find.textContaining('free documents'), findsNothing);
    expect(button(tester, l10n.pressSaveDraft).onPressed, isNull);
    expect(button(tester, l10n.pressFlattenAndSign).onPressed, isNull);
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

  testWidgets('adding a field enables finishing without leaving the screen', (
    tester,
  ) async {
    final docId = await newDoc(tester, withField: false);
    await open(tester, docId);
    expect(button(tester, l10n.pressSaveDraft).onPressed, isNull);
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
    await close(tester);
  });
}
