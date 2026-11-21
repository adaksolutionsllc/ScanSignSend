// Typed signatures: the Type tab starts from the name in My Details, and
// "Use this" saves a cropped, transparent PNG and fills the field with it,
// just as a drawn signature does.

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
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/features/signature/presentation/signature_capture_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory docsDir;

  setUp(() {
    docsDir = Directory.systemTemp.createTempSync('sss_typed_');
    PathResolver.debugSetDocsDir(docsDir);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docsDir.path,
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
    docsDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<(int, int)> setUpField(WidgetTester tester, String type) async =>
      (await tester.runAsync(() async {
        await ProfileRepository(db).update(
          const UserProfileCompanion(
            firstName: Value('Priya'),
            lastName: Value('Raman'),
          ),
        );
        final doc = await DocumentRepository(db).createDocument('Lease');
        final id = await FieldRepository(db).addField(
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: 0,
            type: type,
            boundingBoxJson: '{"x":0.1,"y":0.8,"w":0.3,"h":0.06}',
          ),
        );
        return (doc.id, id);
      }))!;

  Future<void> open(
    WidgetTester tester,
    int docId,
    int fieldId, {
    bool initials = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => SignatureCaptureScreen(
                docId: docId,
                fieldId: fieldId,
                initials: initials,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('a typed signature fills the field with a transparent PNG', (
    tester,
  ) async {
    final (docId, fieldId) = await setUpField(tester, 'signature');
    await open(tester, docId, fieldId);
    await tester.tap(find.text(l10n.signModeType));
    await settle(tester);
    expect(
      find.widgetWithText(TextField, 'Priya Raman'),
      findsOneWidget,
      reason: 'starts from My Details',
    );

    await tester.tap(find.text(l10n.signUseThis));
    await settle(tester);
    final field = (await tester.runAsync(
      () => FieldRepository(db).watchFields(docId).first,
    ))!.single;
    expect(field.isFilled, isTrue);
    expect(field.signatureId, isNotNull);
    final png = img.decodePng(
      File(PathResolver.resolve(field.value)).readAsBytesSync(),
    )!;
    // Cropped to the ink, with the white made transparent.
    expect(png.width, greaterThan(png.height));
    expect(png.getPixel(0, 0).a, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('initials start from the name\'s first letters', (tester) async {
    final (docId, fieldId) = await setUpField(tester, 'initials');
    await open(tester, docId, fieldId, initials: true);
    await tester.tap(find.text(l10n.signModeType));
    await settle(tester);
    expect(find.widgetWithText(TextField, 'PR'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
