// On-device check, run by tool/verify/device_check.sh on an iOS simulator or
// an Android emulator: launches the real app, walks the main screens and
// prints `CAPTURE:<name>` wherever the script should take a screenshot for
// App Review / Play review notes.
//
// Only the share sheet is stood in for (a native sheet can't be driven from
// a test); everything else — database, PDF viewer, the store rating sheet and
// the store listing — is the real thing.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/library/presentation/library_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations.dart';
import 'package:scan_sign_send/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('device check', (tester) async {
    // One earlier send, so this run's send is the one that asks for a rating.
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'review_send_count': 1,
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (_) async => 'device-check', // a completed share
    );

    final testOnError = FlutterError.onError;
    final testErrorWidget = ErrorWidget.builder;
    app.main();
    await _waitFor(tester, find.byType(LibraryScreen));
    FlutterError.onError = testOnError;
    ErrorWidget.builder = testErrorWidget;
    final ctx = tester.element(find.byType(LibraryScreen));
    final container = ProviderScope.containerOf(ctx);
    final l10n = AppLocalizations.of(ctx);
    final router = container.read(routerProvider);
    await _waitGone(tester, find.byType(CircularProgressIndicator));
    await _capture(tester, 'library');

    // Settings, down to Support → Rate.
    router.push(AppRoutes.settings);
    // The list loads the profile first; wait for it, not just the app bar.
    await _waitFor(tester, find.text(l10n.settingsSectionProfile));
    await _capture(tester, 'settings');
    await tester.scrollUntilVisible(
      find.text(l10n.settingsRateApp),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await _pause(tester, 400);
    await _capture(tester, 'settings_support');

    // A finished document on the Send screen.
    final docId = await _pressedDocument(container);
    router.go(AppRoutes.send.replaceAll(':docId', '$docId'));
    await _waitFor(tester, find.text(l10n.sendSharePressed));
    await _capture(tester, 'send');

    // The viewer still opens the pressed PDF.
    await tester.tap(find.text(l10n.sendPreviewDocument));
    await _pause(tester, 2500);
    await _capture(tester, 'viewer');
    router.pop();
    // The Send screen stays mounted under the viewer: wait until it's on top.
    await _waitFor(tester, find.text(l10n.sendSharePressed).hitTestable());

    // Send → after ~1 s the store's own rating sheet (iOS simulator shows it;
    // a sideloaded Android build gets no Play sheet, by design).
    await tester.tap(find.text(l10n.sendSharePressed));
    await _waitFor(tester, find.text(l10n.sendDocumentSent));
    await _pause(tester, 2500);
    await _capture(tester, 'review_prompt');
    final prefs = await SharedPreferences.getInstance();
    _mark(
      'INFO:sends=${prefs.getInt('review_send_count')} '
      'asks=${prefs.getInt('review_ask_count') ?? 0}',
    );

    // Settings → Rate opens the store listing (leaves the app; keep last).
    router.go(AppRoutes.settings);
    // The list loads the profile first; wait for it, not just the app bar.
    await _waitFor(tester, find.text(l10n.settingsSectionProfile));
    await tester.scrollUntilVisible(
      find.text(l10n.settingsRateApp),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    // The store is another app, and iOS suspends this one behind it, so the
    // script takes this shot a few seconds after the tap and then brings the
    // app back. (The iOS simulator has no App Store app; Safari shows an error
    // there. A device opens the listing.)
    _mark('LEAVE:rate_store');
    await tester.tap(find.text(l10n.settingsRateApp));
    final back = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(back)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          _leftApp) {
        break;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _leftApp = true;
      }
    }
    expect(_leftApp, isTrue, reason: 'Rate should open the store');
  });
}

bool _leftApp = false;

/// A one-page document that has been through Flatten & Sign.
Future<int> _pressedDocument(ProviderContainer container) async {
  final docs = container.read(documentRepositoryProvider);
  final doc = await docs.createDocument('Device check');
  final pdf = PdfDocument();
  pdf.pages.add().graphics.drawString(
    'Device check',
    PdfStandardFont(PdfFontFamily.helvetica, 28),
    bounds: const Rect.fromLTWH(40, 40, 400, 60),
  );
  final bytes = await pdf.save();
  pdf.dispose();
  final rel = p.join('pressed', 'device_check_${doc.id}.pdf');
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, rel));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  await docs.updateDocument(
    DocumentsCompanion(id: Value(doc.id), pressedPdfPath: Value(rel)),
  );
  return doc.id;
}

/// Asks device_check.sh for a screenshot.
Future<void> _capture(WidgetTester tester, String name) async {
  await _pause(tester, 900); // let route transitions finish
  _mark('CAPTURE:$name');
  await _pause(tester, 1500);
}

// ignore: avoid_print
void _mark(String m) => print(m);

Future<void> _pause(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitGone(
  WidgetTester tester,
  Finder f, {
  int seconds = 30,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isEmpty) return;
  }
  throw TestFailure('Still showing $f');
}

Future<void> _waitFor(WidgetTester tester, Finder f, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}
