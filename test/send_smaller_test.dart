// Send → "Smaller file": shown when the document has photo pages, it makes
// a lighter copy, shows both sizes, and Share sends that copy. A document
// of imported PDF pages has nothing to shrink and doesn't offer it.

import 'dart:io';
import 'dart:math';

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
import 'package:scan_sign_send/core/services/fillable_form_export_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/features/send/presentation/send_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _share = MethodChannel('dev.fluttercommunity.plus/share');

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
    root = Directory.systemTemp.createTempSync('sss_send_small');
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
    messenger.setMockMethodCallHandler(_share, (call) async {
      final args = call.arguments as Map;
      shared.addAll((args['paths'] as List).cast<String>());
      return 'com.apple.UIKit.activity.Mail';
    });
  });

  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<void> settleUntil(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (f.evaluate().isNotEmpty) return;
    }
  }

  Future<void> open(WidgetTester tester, int docId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: SendScreen(docId: docId),
        ),
      ),
    );
    await settleUntil(tester, find.text(l10n.sendSharePressed));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('a scan saved without fields: smaller copy is what is shared', (
    tester,
  ) async {
    final (docId, original) = (await tester.runAsync(() async {
      final r = Random(3);
      final im = img.Image(width: 1800, height: 2400);
      for (var y = 0; y < im.height; y++) {
        for (var x = 0; x < im.width; x++) {
          im.setPixelRgb(x, y, 200 + r.nextInt(40), 190, 170 + r.nextInt(50));
        }
      }
      final dir = Directory(p.join(root.path, 'pages', 'u'))
        ..createSync(recursive: true);
      final page = File(p.join(dir.path, 'page_0.jpg'))
        ..writeAsBytesSync(img.encodeJpg(im, quality: 92));
      final docs = DocumentRepository(db);
      final doc = await docs.createDocument('Receipt');
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: 0, imagePath: page.path);
      // As "Skip fields · Save & Share" does it.
      final pdf = await FillableFormExportService(
        docs,
        PageRepository(db),
        FieldRepository(db),
      ).export(doc.id);
      await docs.markCompleted(doc.id, pdf);
      return (doc.id, pdf);
    }))!;

    await open(tester, docId);
    await settleUntil(tester, find.text(l10n.sendSmallerFile));
    expect(find.text(l10n.sendSmallerFile), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('smaller-file')));
    await settleUntil(tester, find.textContaining('→'));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            RegExp(r'^[\d.,]+ [KM]B → [\d.,]+ [KM]B$').hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.sendSharePressed));
    await settleUntil(tester, find.text(l10n.sendDocumentSent));
    final sent = File(shared.single).lengthSync();
    expect(p.basename(shared.single), 'Receipt.pdf');
    expect(sent, lessThan(File(original).lengthSync() * 0.9));
    // The rating ask records the send, then waits a second: let both pass.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('imported PDF pages: nothing to shrink, no switch', (
    tester,
  ) async {
    final docId = (await tester.runAsync(() async {
      final docs = DocumentRepository(db);
      final doc = await docs.createDocument('Form');
      final pdf = File(p.join(root.path, 'form.pdf'))..writeAsBytesSync([0]);
      await PageRepository(db).addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: '${pdf.path}#page=0',
      );
      await docs.markCompleted(doc.id, pdf.path);
      return doc.id;
    }))!;
    await open(tester, docId);
    // Long enough for the page check to answer (it shows within a second
    // when there is something to shrink).
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text(l10n.sendSmallerFile), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
