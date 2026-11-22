// Receipts → Export to spreadsheet (F3): details are read once from the
// pages and kept, the user's corrections are never read over, and the .csv
// is written for the phone's region.

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
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
import 'package:scan_sign_send/core/services/receipt_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/region.dart';
import 'package:scan_sign_send/features/receipts/presentation/receipts_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// OCR stand-in: each page image's name picks its receipt lines, one per
/// row; the reads are counted.
class _FakeLayouts implements PageLayoutService {
  _FakeLayouts(this.receipts);
  final Map<String, List<String>> receipts;
  var reads = 0;

  @override
  Future<(PageLayout, String)> textOnly(String storedPath) async {
    reads++;
    final lines = receipts[p.basenameWithoutExtension(storedPath)] ?? [];
    return (
      PageLayout(
        lines: [
          for (final (i, t) in lines.indexed)
            LayoutLine(
              text: t,
              box: Rect.fromLTWH(0.1, 0.05 * i, 0.8, 0.03),
              words: const [],
              fontSize: 0.03,
            ),
        ],
        rules: const [],
        aspect: 0.5,
      ),
      lines.join('\n'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _coffee = [
  'CAFE COFFEE DAY',
  'Date: 14-11-2026',
  'CGST 7.50',
  'SGST 7.50',
  'Grand Total 315.00',
];
const _taxi = ['City Cabs', '03/11/2026', 'Fare total 9.05'];

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory tmp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('receipts');
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

  Future<int> receipt(String title, String image) async {
    final doc = await DocumentRepository(db).createDocument(title);
    await PageRepository(db).addPage(
      documentId: doc.id,
      pageIndex: 0,
      imagePath: p.join(tmp.path, '$image.jpg'),
    );
    return doc.id;
  }

  test(
    'read once and kept; corrections kept; gone with the document',
    () async {
      final layouts = _FakeLayouts({'coffee': _coffee, 'taxi': _taxi});
      final service = ReceiptService(db, PageRepository(db), layouts);
      final coffee = await receipt('Lunch', 'coffee');
      final taxi = await receipt('Ride', 'taxi');

      final d = await service.detailsFor(coffee, const Region('en_IN'));
      expect(d.merchant, 'Cafe Coffee Day');
      expect(d.total, 31500);
      expect(d.tax, 1500);
      expect(d.currency, 'INR');
      expect(d.date, DateTime(2026, 11, 14));
      expect(d.edited, isFalse);

      // No currency sign: the phone's region decides; US dates month first.
      final t = await service.detailsFor(taxi, const Region('en_US'));
      expect(t.currency, 'USD');
      expect(t.date, DateTime(2026, 3, 11));
      expect(t.total, 905);
      expect(layouts.reads, 2);

      expect(
        (await service.detailsFor(coffee, const Region('en_IN'))).total,
        31500,
      );
      expect(layouts.reads, 2, reason: 'kept, not read again');

      await service.save(t.copyWith(merchant: 'Blue Cab'));
      final saved = await service.detailsFor(taxi, const Region('en_US'));
      expect(saved.merchant, 'Blue Cab');
      expect(saved.edited, isTrue);

      await DocumentRepository(db).deleteDocument(taxi);
      expect(
        (await db.select(db.receiptDetails).get()).map((r) => r.documentId),
        [coffee],
      );
    },
  );

  testWidgets('the list, a correction, and a .csv for a comma region', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ids = (await tester.runAsync(
      () async => [
        await receipt('Lunch', 'coffee'),
        await receipt('Ride', 'taxi'),
      ],
    ))!;
    var csv = '';
    var bom = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          final path =
              ((call.arguments as Map)['paths'] as List).single as String;
          bom = File(path).readAsBytesSync().sublist(0, 3);
          csv = File(path).readAsStringSync();
          return 'done';
        },
      )
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => tmp.path,
      );
    final layouts = _FakeLayouts({'coffee': _coffee, 'taxi': _taxi});

    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          receiptServiceProvider.overrideWith(
            (ref) => ReceiptService(db, PageRepository(db), layouts),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: ReceiptsScreen(docIds: ids, region: const Region('fr_FR')),
        ),
      ),
    );
    await settle();
    expect(find.text('Cafe Coffee Day'), findsOneWidget);
    expect(find.text('City Cabs'), findsOneWidget);
    expect(find.textContaining('₹315.00'), findsOneWidget);
    expect(find.text(l10n.receiptsReading), findsNothing);

    // Correct the taxi's total; a bad amount is refused first.
    await tester.tap(find.text('City Cabs'));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('receipt-total')), 'abc');
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    await settle();
    expect(find.text(l10n.receiptAmountInvalid), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('receipt-total')), '9,50');
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    await settle();
    final kept = (await tester.runAsync(
      () => db.select(db.receiptDetails).get(),
    ))!.firstWhere((r) => r.documentId == ids[1]);
    expect(kept.total, 950);
    expect(kept.edited, isTrue);

    await tester.tap(find.text(l10n.receiptsExportCsv));
    await settle();
    // UTF-8 with a byte-order mark, so Excel shows ₹ and accents.
    expect(bom, [0xEF, 0xBB, 0xBF]);
    expect(csv, startsWith('Date;Merchant;Total;Tax;Currency;Document'));
    expect(csv, contains('2026-11-14;Cafe Coffee Day;315,00;15,00;INR;Lunch'));
    expect(csv, contains(';City Cabs;9,50;;EUR;Ride'));
  });
}
