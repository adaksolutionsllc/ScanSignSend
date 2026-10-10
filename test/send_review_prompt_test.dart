// The Send screen asks for a store rating only after a real send: not on a
// dismissed share sheet, not twice for one document, not over the lock screen
// or another route, and a failing store never gets in the way of sending.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/app_lock_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/send/presentation/send_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _share = MethodChannel('dev.fluttercommunity.plus/share');
const _review = MethodChannel('dev.britannio.in_app_review');

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory tmp;
  late String shareResult;
  late bool reviewFails;
  late int reviewRequests;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('send_review');
    shareResult = 'com.apple.UIKit.activity.Mail'; // a completed share
    reviewFails = false;
    reviewRequests = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_share, (_) async => shareResult);
    messenger.setMockMethodCallHandler(_review, (call) async {
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'requestReview':
          if (reviewFails) throw PlatformException(code: 'error');
          reviewRequests++;
      }
      return null;
    });
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  /// A finished (pressed) document on the Send screen. [sendsBefore] seeds
  /// the count of earlier sends.
  Future<ProviderContainer> open(
    WidgetTester tester, {
    int sendsBefore = 0,
  }) async {
    SharedPreferences.setMockInitialValues({'review_send_count': sendsBefore});
    final docId = (await tester.runAsync(() async {
      final docs = DocumentRepository(db);
      final doc = await docs.createDocument('Lease');
      final pdf = File('${tmp.path}/${doc.id}.pdf')..writeAsBytesSync([0]);
      await docs.updateDocument(
        DocumentsCompanion(id: Value(doc.id), pressedPdfPath: Value(pdf.path)),
      );
      return doc.id;
    }))!;
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: SendScreen(docId: docId),
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  /// Taps a share button and waits until the share has finished (the
  /// screen shows "sent", or stays unsent for a dismissed sheet).
  Future<void> tapShare(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          find.text(l10n.sendOpeningShareSheet).evaluate().isEmpty) {
        break;
      }
    }
  }

  testWidgets('the second send asks, about a second after the sheet closes', (
    tester,
  ) async {
    await open(tester, sendsBefore: 1);
    await tapShare(tester, l10n.sendSharePressed);
    expect(find.text(l10n.sendDocumentSent), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(reviewRequests, 0, reason: 'too soon: the share sheet is closing');
    await settle(tester);
    expect(reviewRequests, 1);
  });

  testWidgets('the first send never asks', (tester) async {
    await open(tester);
    await tapShare(tester, l10n.sendSharePressed);
    await settle(tester);
    expect(reviewRequests, 0);
    expect(await sendCount(tester), 1);
  });

  testWidgets('a dismissed share sheet is not a send', (tester) async {
    shareResult = ''; // share_plus's "dismissed"
    await open(tester, sendsBefore: 1);
    await tapShare(tester, l10n.sendSharePressed);
    await settle(tester);
    expect(reviewRequests, 0);
    expect(await sendCount(tester), 1);
  });

  testWidgets('sharing the same document again is not another send', (
    tester,
  ) async {
    await open(tester);
    await tapShare(tester, l10n.sendSharePressed);
    await settle(tester);
    await tapShare(tester, l10n.sendShareAgain);
    await settle(tester);
    expect(reviewRequests, 0);
    expect(await sendCount(tester), 1);
  });

  testWidgets('never asks over the lock screen', (tester) async {
    final container = await open(tester, sendsBefore: 1);
    await tapShare(tester, l10n.sendSharePressed);
    container.read(appLockProvider.notifier).lock();
    await settle(tester);
    expect(reviewRequests, 0);
  });

  testWidgets('never asks over another screen', (tester) async {
    await open(tester, sendsBefore: 1);
    await tapShare(tester, l10n.sendSharePressed);
    Navigator.of(
      tester.element(find.byType(SendScreen)),
    ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await settle(tester);
    expect(reviewRequests, 0);
  });

  testWidgets('never asks from the background', (tester) async {
    await open(tester, sendsBefore: 1);
    await tapShare(tester, l10n.sendSharePressed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);
    expect(reviewRequests, 0);
  });

  testWidgets('a store error leaves the send intact', (tester) async {
    reviewFails = true;
    await open(tester, sendsBefore: 1);
    await tapShare(tester, l10n.sendSharePressed);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.sendDocumentSent), findsOneWidget);
    expect(find.text(l10n.sendBackToLibrary), findsWidgets);
  });
}

/// Lets real I/O (drift, file copies) and fake timers both advance.
Future<void> settle(
  WidgetTester tester, {
  Duration upTo = const Duration(milliseconds: 1500),
}) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < upTo; t += step) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(step);
  }
}

Future<int> sendCount(WidgetTester tester) async =>
    (await tester.runAsync(
      SharedPreferences.getInstance,
    ))!.getInt('review_send_count') ??
    0;
