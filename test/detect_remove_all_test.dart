// Detect Fields: "Remove all" sits beside "Fill N fields", removes every
// field (the user's own too) and can be undone (1.3.1, TestFlight feedback:
// the old wand icon in the app bar wasn't readable).

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/field_detection/presentation/field_detection_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('Remove all clears every field, and Undo brings them back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    final fields = FieldRepository(db);
    final docId = (await tester.runAsync(() async {
      final doc = await DocumentRepository(db).createDocument('Form');
      await PageRepository(db).addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: '/missing/page_0.jpg',
      );
      FieldsCompanion row(String label, {required bool detected}) =>
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: 0,
            type: 'text',
            boundingBoxJson: const BoundingBox(
              x: 0.1,
              y: 0.1,
              w: 0.3,
              h: 0.03,
            ).toJsonString(),
            label: Value(label),
            sourceKind: const Value('app'),
            optionsJson: Value(fieldOptionsJson(detected: detected)),
          );
      await fields.addFields([
        row('found', detected: true),
        row('mine', detected: false),
      ]);
      return doc.id;
    }))!;

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: FieldDetectionScreen(docId: docId),
        ),
      ),
    );
    await settle();

    final removeAll = find.byKey(const ValueKey('detect-remove-all'));
    expect(find.text(l10n.detectFillFields(2)), findsOneWidget);
    expect(removeAll, findsOneWidget);
    expect(find.text(l10n.detectRemoveAll), findsOneWidget);
    // Beside the Fill button, on its right.
    expect(
      tester.getCenter(removeAll).dx,
      greaterThan(tester.getCenter(find.text(l10n.detectFillFields(2))).dx),
    );

    await tester.tap(removeAll);
    await settle();
    expect(find.text(l10n.detectRemovedAll(2)), findsOneWidget);
    expect(find.text(l10n.detectSkipToFill), findsOneWidget);
    expect(removeAll, findsNothing, reason: 'nothing left to remove');
    expect(
      (await tester.runAsync(() => fields.watchFields(docId).first))!,
      isEmpty,
    );

    await tester.tap(find.text(l10n.actionUndo));
    await settle();
    expect(find.text(l10n.detectFillFields(2)), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => fields.watchFields(docId).first,
      ))!.map((f) => f.label).toSet(),
      {'found', 'mine'},
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
