// "Next field" in Fill mode: the bar opens the first empty field, the
// sheet's Next saves and opens the following one, and a signature is only
// highlighted, never opened for the user.

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/fill_mode/presentation/fill_mode_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:scan_sign_send/shared/widgets/field_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory tmp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('google_mlkit_text_recognizer'),
          (_) async => null,
        );
    tmp = Directory.systemTemp.createTempSync('sss_next');
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('Next walks the empty fields and stops at the signature', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final ids = (await tester.runAsync(() async {
      final page = File('${tmp.path}/page.png')
        ..writeAsBytesSync(
          img.encodePng(
            img.fill(
              img.Image(width: 300, height: 400),
              color: img.ColorRgb8(255, 255, 255),
            ),
          ),
        );
      final doc = await DocumentRepository(db).createDocument('Form');
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: 0, imagePath: page.path);
      Future<int> add(String label, String type, double y) =>
          FieldRepository(db).addField(
            FieldsCompanion.insert(
              documentId: doc.id,
              pageIndex: 0,
              type: type,
              boundingBoxJson: '{"x":0.1,"y":$y,"w":0.5,"h":0.05}',
              label: Value(label),
            ),
          );
      final sign = await add('Signature', 'signature', 0.7);
      final email = await add('Email', 'text', 0.3);
      final name = await add('Name', 'text', 0.1);
      return (doc.id, name, email, sign);
    }))!;
    final (docId, nameId, emailId, signId) = ids;

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
    expect(find.text(l10n.fillNextField(3)), findsOneWidget);

    // The bar opens the first field in reading order: Name.
    await tester.tap(find.byKey(const ValueKey('next-field')));
    await settle(tester);
    expect(find.text('Name'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Priya Raman');
    await tester.tap(find.byKey(const ValueKey('sheet-next')));
    await settle(tester);

    // Next saved Name and opened Email.
    await tester.enterText(find.byType(TextField), 'priya@example.com');
    await tester.tap(find.byKey(const ValueKey('sheet-next')));
    await settle(tester);

    // The signature is highlighted, not opened: no sheet, no navigation.
    expect(find.byType(TextField), findsNothing);
    final values = {
      for (final f in (await tester.runAsync(
        () => FieldRepository(db).watchFields(docId).first,
      ))!)
        f.id: f.value,
    };
    expect(values[nameId], 'Priya Raman');
    expect(values[emailId], 'priya@example.com');
    final sign = tester.widget<FieldBox>(
      find.byWidgetPredicate(
        (w) => w is FieldBox && w.key == ValueKey(signId),
      ),
    );
    expect(sign.highlighted, isTrue);
    expect(find.text(l10n.fillNextField(1)), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
