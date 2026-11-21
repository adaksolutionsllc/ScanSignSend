// Send → "Password-protect": the password is asked twice (at least 6
// characters, both the same), and what Share sends then needs it to open.
// On iOS a fillable form with radio buttons doesn't offer it.

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/pdf_password_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/features/send/presentation/send_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory root;
  late List<String> shared;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    root = Directory.systemTemp.createTempSync('sss_send_pw');
    PathResolver.debugSetDocsDir(root);
    shared = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.britannio.in_app_review'),
      (_) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        shared.addAll(((call.arguments as Map)['paths'] as List).cast());
        return 'com.apple.UIKit.activity.Mail';
      },
    );
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<void> settleUntil(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      if (f.evaluate().isNotEmpty) return;
    }
  }

  /// A completed one-page document with a filled field, on the Send screen.
  Future<void> open(
    WidgetTester tester, {
    bool radios = false,
    PdfPasswordService? service,
  }) async {
    final docId = (await tester.runAsync(() async {
      final pdf = PdfDocument();
      pdf.pages.add();
      final file = File(p.join(root.path, 'done.pdf'))
        ..writeAsBytesSync(await pdf.save());
      pdf.dispose();
      final docs = DocumentRepository(db);
      final doc = await docs.createDocument('Lease');
      await PageRepository(db).addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: '${file.path}#page=0',
      );
      if (radios) {
        await FieldRepository(db).addField(
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: 0,
            type: 'radio',
            boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.03,"h":0.03}',
          ),
        );
        // Saved as a fillable form (not flattened).
        await docs.updateDocument(
          DocumentsCompanion(
            id: Value(doc.id),
            fillablePdfPath: Value(file.path),
          ),
        );
      } else {
        await docs.markCompleted(doc.id, file.path);
      }
      return doc.id;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (service != null)
            pdfPasswordServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: SendScreen(docId: docId),
        ),
      ),
    );
    await settleUntil(tester, find.text(l10n.sendSharePressed));
  }

  testWidgets('set twice, validated, and the shared PDF needs it', (
    tester,
  ) async {
    await open(tester, service: PdfPasswordService(useOsEncryption: false));
    await settleUntil(tester, find.text(l10n.sendPasswordProtect));
    await tester.tap(find.byKey(const ValueKey('password-protect')));
    await tester.pumpAndSettle();

    Future<void> enter(String a, String b) async {
      await tester.enterText(find.byKey(const ValueKey('password-1')), a);
      await tester.enterText(find.byKey(const ValueKey('password-2')), b);
      await tester.tap(find.byKey(const ValueKey('password-set')));
      await tester.pumpAndSettle();
    }

    await enter('12345', '12345');
    expect(find.text(l10n.passwordTooShort(6)), findsOneWidget);
    await enter('secret12', 'secret13');
    expect(find.text(l10n.passwordMismatch), findsOneWidget);
    await enter('secret12', 'secret12');
    expect(find.text(l10n.sendPasswordOnHint), findsOneWidget);

    await tester.tap(find.text(l10n.sendSharePressed));
    await settleUntil(tester, find.text(l10n.sendDocumentSent));
    final bytes = File(shared.single).readAsBytesSync();
    expect(() => PdfDocument(inputBytes: bytes), throwsA(anything));
    PdfDocument(inputBytes: bytes, password: 'secret12').dispose();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('iOS: a fillable form with radio buttons does not offer it', (
    tester,
  ) async {
    await open(
      tester,
      radios: true,
      service: PdfPasswordService(useOsEncryption: true),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(find.text(l10n.sendSharePressed), findsOneWidget);
    expect(find.text(l10n.sendPasswordProtect), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
