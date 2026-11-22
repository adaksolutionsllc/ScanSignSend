// Send → Format (F2): Text and Word hold each page's text and what was
// filled in; the PDF-only options hide for other formats.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
import 'package:scan_sign_send/core/services/page_layout.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:scan_sign_send/core/services/page_text_service.dart';
import 'package:scan_sign_send/core/services/send_formats_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/send/presentation/send_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLayouts implements PageLayoutService {
  _FakeLayouts(this.text);
  final String text;

  @override
  Future<(PageLayout, String)> textOnly(String storedPath) async =>
      (const PageLayout(lines: [], rules: [], aspect: 0.707), text);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Field _field(
  String type, {
  String label = '',
  String value = '',
  bool checked = false,
  double y = 0.1,
  double x = 0.1,
}) => Field(
  id: 0,
  documentId: 1,
  pageIndex: 0,
  type: type,
  boundingBoxJson: '{"x":$x,"y":$y,"w":0.2,"h":0.05}',
  label: label,
  value: value,
  isChecked: checked,
  isFilled: value.isNotEmpty || checked,
  isRequired: false,
  sourceKind: 'app',
);

void main() {
  final l10n = AppLocalizationsEn();

  test('filled-in values: top to bottom; signatures left out', () {
    expect(
      filledLines([
        _field('checkbox', label: 'I agree', checked: true, y: 0.8),
        _field('text', label: 'Tenant name', value: 'Jane Doe', y: 0.2),
        _field('date', label: 'Date', value: '22/11/2026', y: 0.2, x: 0.6),
        _field('text', label: 'Unit', y: 0.3), // empty
        _field('checkbox', label: 'Pets', y: 0.4), // not ticked
        _field('radio', label: 'Monthly', checked: true, y: 0.5),
        _field('signature', label: 'Signature', value: 'x', y: 0.9),
        _field('text', value: 'no label', y: 0.6),
      ]),
      [
        'Tenant name: Jane Doe',
        'Date: 22/11/2026',
        '[x] Monthly',
        'no label',
        '[x] I agree',
      ],
    );
  });

  group('Send screen', () {
    late AppDatabase db;
    late Directory tmp;
    late List<String> shared;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      tmp = Directory.systemTemp.createTempSync('send_formats');
      shared = [];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            shared = [
              for (final f in (call.arguments as Map)['paths'] as List) '$f',
            ];
            return 'com.apple.UIKit.activity.Mail';
          },
        )
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        )
        ..setMockMethodCallHandler(
          const MethodChannel('dev.britannio.in_app_review'),
          (_) async => false,
        );
    });
    tearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> open(WidgetTester tester, {String pageText = ''}) async {
      final docId = (await tester.runAsync(() async {
        final docs = DocumentRepository(db);
        final doc = await docs.createDocument('Lease');
        final pdf = File(p.join(tmp.path, 'lease.pdf'))..writeAsBytesSync([0]);
        await docs.updateDocument(
          DocumentsCompanion(
            id: Value(doc.id),
            pressedPdfPath: Value(pdf.path),
          ),
        );
        await PageRepository(db).addPage(
          documentId: doc.id,
          pageIndex: 0,
          imagePath: p.join(tmp.path, 'page_0.jpg'),
        );
        await FieldRepository(db).addField(
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: 0,
            type: 'text',
            boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.3,"h":0.05}',
            label: const Value('Tenant name'),
            value: Value(pageText.isEmpty ? '' : 'Jane Doe'),
          ),
        );
        return doc.id;
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            pageTextServiceProvider.overrideWith(
              (ref) => PageTextService(
                ref.watch(pageRepositoryProvider),
                _FakeLayouts(pageText),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: SendScreen(docId: docId),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('Word: a .docx with the page text and the fill-ins', (
      tester,
    ) async {
      await open(tester, pageText: 'Residential lease');
      expect(find.text(l10n.sendSmallerFile), findsOneWidget);
      expect(find.text(l10n.sendSharePressed), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('format-word')));
      await settle(tester);
      expect(find.text(l10n.sendShareWord), findsOneWidget);
      expect(find.text(l10n.sendFormatTextHint), findsOneWidget);
      // Smaller file and Password-protect are PDF options.
      expect(find.text(l10n.sendSmallerFile), findsNothing);
      expect(find.text(l10n.sendPasswordProtect), findsNothing);

      await tester.tap(find.text(l10n.sendShareWord));
      await settle(tester);
      expect(shared, hasLength(1));
      expect(p.basename(shared.single), 'Lease.docx');
      final zip = ZipDecoder().decodeBytes(
        (await tester.runAsync(() => File(shared.single).readAsBytes()))!,
      );
      final doc = utf8.decode(
        zip.findFile('word/document.xml')!.content as List<int>,
      );
      expect(doc, contains('Residential lease'));
      expect(doc, contains('Tenant name: Jane Doe'));
      expect(find.text(l10n.sendDocumentSent), findsOneWidget);
    });

    testWidgets('Text with nothing to say: a message, no empty file', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('format-text')));
      await settle(tester);
      await tester.tap(find.text(l10n.sendShareText));
      await settle(tester);
      expect(shared, isEmpty);
      expect(find.text(l10n.sendNoText), findsOneWidget);
      expect(find.text(l10n.sendDocumentSent), findsNothing);

      // Back to PDF: the PDF options and label return.
      await tester.tap(find.byKey(const ValueKey('format-pdf')));
      await settle(tester);
      expect(find.text(l10n.sendSharePressed), findsOneWidget);
    });
  });
}
