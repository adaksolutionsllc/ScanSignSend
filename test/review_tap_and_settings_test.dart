// Review & Finish: tapping a field returns its id to fill mode.
// Settings: a switch redraws as soon as its value is saved.

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/press/presentation/press_screen.dart';
import 'package:scan_sign_send/features/settings/presentation/settings_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;

  setUp(
    () => db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    ),
  );
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('tapping a field in Review & Finish returns its id', (
    tester,
  ) async {
    final (docId, fieldId) = (await tester.runAsync(() async {
      final doc = await DocumentRepository(db).createDocument('Lease');
      final id = await FieldRepository(db).addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: 'text',
          boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.3,"h":0.05}',
          label: const Value('Tenant name'),
        ),
      );
      return (doc.id, id);
    }))!;

    Object? popped = 'not popped';
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async =>
                popped = await context.push<int>('/press'),
            child: const Text('open'),
          ),
        ),
        GoRoute(
          path: '/press',
          builder: (_, _) => PressScreen(docId: docId),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text(l10n.pressFieldSummary), findsOneWidget);

    await tester.tap(find.text('Tenant name'));
    await settle(tester);
    expect(popped, fieldId);
    await close(tester);
  });

  testWidgets('a Settings switch shows its new value once saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await settle(tester);
    await tester.scrollUntilVisible(find.text(l10n.settingsBackupTitle), 200);

    bool backupSwitch() => tester
        .widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, l10n.settingsBackupTitle),
        )
        .value;
    expect(backupSwitch(), isFalse);

    // Written straight to the database, as the switch's onChanged does
    // before the platform call: the screen must follow the row.
    await tester.runAsync(
      () => ProfileRepository(db).update(
        const UserProfileCompanion(includeInDeviceBackup: Value(true)),
      ),
    );
    await settle(tester);
    expect(backupSwitch(), isTrue);
    await close(tester);
  });

  testWidgets('Settings has no AI detection switch', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text(l10n.settingsSectionDetection),
      200,
    );
    expect(find.text(l10n.settingsSectionDetection), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);
    await close(tester);
  });
}
