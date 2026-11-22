// Copy text (F1): each page's text is read once and kept, read again after
// Rotate or Crop, and shown in a sheet to select, copy or share.

import 'dart:io';

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
import 'package:scan_sign_send/core/services/page_layout.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:scan_sign_send/core/services/page_text_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/features/review/presentation/review_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads a fixed text per image file name and counts the reads.
class _FakeLayouts implements PageLayoutService {
  _FakeLayouts(this.texts);
  final Map<String, String> texts;
  final reads = <String>[];

  @override
  Future<(PageLayout, String)> textOnly(String storedPath) async {
    final name = p.basename(storedPath);
    reads.add(name);
    final text = texts.entries
        .firstWhere(
          (e) => name.startsWith(e.key),
          orElse: () => const MapEntry('', ''),
        )
        .value;
    return (const PageLayout(lines: [], rules: [], aspect: 0.707), text);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('sss_text_');
    PathResolver.debugSetDocsDir(root);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
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

  /// A document of two image pages: page_0 has text, page_1 none.
  Future<int> twoPages() async {
    final doc = await DocumentRepository(db).createDocument('Lease');
    final dir = Directory(p.join(root.path, 'pages', 'lease'))
      ..createSync(recursive: true);
    for (var i = 0; i < 2; i++) {
      final f = File(p.join(dir.path, 'page_$i.jpg'))
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 30, height: 40)));
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: i, imagePath: f.path);
    }
    return doc.id;
  }

  test('read once and kept; read again after Rotate', () async {
    final docId = await twoPages();
    final layouts = _FakeLayouts({'page_0': '  Tenant: Jane Doe\nRent 900  '});
    final pages = PageRepository(db);
    final service = PageTextService(pages, layouts);

    var all = await pages.pagesOf(docId);
    expect(await service.textOf(all[0]), 'Tenant: Jane Doe\nRent 900');
    expect(await service.textOf(all[1]), '');
    all = await pages.pagesOf(docId);
    expect(all[0].ocrText, 'Tenant: Jane Doe\nRent 900');
    // Kept: no second read. A page with no text is tried again.
    expect(await service.textOf(all[0]), 'Tenant: Jane Doe\nRent 900');
    expect(await service.textOf(all[1]), '');
    expect(layouts.reads, ['page_0.jpg', 'page_1.jpg', 'page_1.jpg']);

    await pages.rotatePageClockwise(all[0].id);
    all = await pages.pagesOf(docId);
    expect(all[0].ocrText, isEmpty, reason: 'read from the old image');
    await service.textOf(all[0]);
    expect(layouts.reads, hasLength(4));

    expect(PageTextService.joined(['a', '', 'b']), 'a\n\nb');
  });

  testWidgets('Review → Text shows each page, and Copy all copies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final docId = (await tester.runAsync(twoPages))!;
    final layouts = _FakeLayouts({'page_0': 'Tenant: Jane Doe'});

    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pageTextServiceProvider.overrideWith(
            (ref) =>
                PageTextService(ref.watch(pageRepositoryProvider), layouts),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: ReviewScreen(docId: docId),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }

    await tester.tap(find.byKey(const ValueKey('page-text')));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text(l10n.textTitle), findsOneWidget);
    expect(find.text(l10n.textPageN(1)), findsOneWidget);
    expect(find.text(l10n.textPageN(2)), findsOneWidget);
    expect(
      find.widgetWithText(SelectableText, 'Tenant: Jane Doe'),
      findsOneWidget,
    );
    // The page OCR found nothing on says why, not just blank.
    expect(find.text(l10n.textNoneOnPage), findsOneWidget);

    await tester.tap(find.text(l10n.textCopyAll));
    await tester.pump();
    await tester.pump();
    expect(copied, 'Tenant: Jane Doe');
    expect(find.text(l10n.textCopied), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(l10n.textCopyAll), findsOneWidget);
  });
}
