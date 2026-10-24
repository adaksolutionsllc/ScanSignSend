// On-device check, run by tool/verify/device_check.sh on an iOS simulator or
// an Android emulator: launches the real app, walks the main screens and
// prints `CAPTURE:<name>` wherever the script should take a screenshot for
// App Review / Play review notes.
//
// Only the share sheet is stood in for (a native sheet can't be driven from
// a test); everything else — database, PDF viewer, the store rating sheet and
// the store listing — is the real thing.

import 'dart:async';
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
import 'package:scan_sign_send/core/services/opened_file_service.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/features/fill_mode/presentation/fill_mode_screen.dart';
import 'package:scan_sign_send/shared/widgets/field_box.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/library/presentation/library_screen.dart';
import 'package:scan_sign_send/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scan_sign_send/features/send/presentation/send_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations.dart';
import 'package:scan_sign_send/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('device check', (tester) async {
    // One earlier send, so this run's send is the one that asks for a rating.
    // The tour was finished on an earlier version (no pages recorded), as
    // for everyone updating from 1.1.0: launch shows "What's new".
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
    await _waitFor(tester, find.byType(OnboardingScreen));
    FlutterError.onError = testOnError;
    ErrorWidget.builder = testErrorWidget;
    {
      final tl10n = AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      await _waitFor(tester, find.text(tl10n.tourWhatsNew));
      expect(find.text(tl10n.onboardPrefillTitle), findsOneWidget);
      expect(find.text(tl10n.onboardScanTitle), findsNothing);
      await _capture(tester, 'whats_new');
      await tester.tap(find.text(tl10n.tourGotIt));
    }
    await _waitFor(tester, find.byType(LibraryScreen));
    final seen = await SharedPreferences.getInstance();
    expect(seen.getStringList(kTourPagesSeen), kTourPageIds);
    _mark('INFO:whats new shown once');
    final ctx = tester.element(find.byType(LibraryScreen));
    final container = ProviderScope.containerOf(ctx);
    final l10n = AppLocalizations.of(ctx);
    final router = container.read(routerProvider);
    await _waitGone(tester, find.byType(CircularProgressIndicator));
    await _capture(tester, 'library');

    // My Details, as a user would save them (a made-up person).
    await container
        .read(profileRepositoryProvider)
        .update(
          UserProfileCompanion(
            firstName: const Value('Priya'),
            middleName: const Value('Kumari'),
            lastName: const Value('Raman'),
            email: const Value('priya@example.com'),
            phone: const Value('+1 512 555 0100'),
            address: const Value('12 Elm Street'),
            address2: const Value('Apt 4'),
            city: const Value('Austin'),
            state: const Value('TX'),
            zip: const Value('78701'),
            country: const Value('USA'),
            dateOfBirth: Value(DateTime(1990, 6, 15)),
          ),
        );

    // Settings, down to Support → Rate.
    router.push(AppRoutes.settings);
    // The list loads the profile first; wait for it, not just the app bar.
    await _waitFor(tester, find.text('Priya Raman'));
    await _capture(tester, 'settings');
    await tester.tap(find.text('Priya Raman'));
    await _waitFor(tester, find.text(l10n.myDetailsNote));
    await _capture(tester, 'my_details');
    router.pop();
    await _waitFor(tester, find.text('Priya Raman').hitTestable());
    await tester.scrollUntilVisible(
      find.text(l10n.settingsRateApp),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await _pause(tester, 400);
    await _capture(tester, 'settings_support');

    // Settings → App tour replays the whole tour; page 2 is PreFill.
    await tester.tap(find.text(l10n.settingsTour));
    await _waitFor(tester, find.text(l10n.onboardScanTitle));
    await _pause(tester, 600);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await _waitFor(tester, find.text(l10n.onboardPrefillTitle));
    await _capture(tester, 'tour_prefill');
    await tester.tap(find.text(l10n.actionBack));
    await _waitFor(tester, find.text(l10n.actionSkip));
    await _pause(tester, 500);
    await tester.tap(find.text(l10n.actionSkip));
    await _waitFor(tester, find.text(l10n.settingsTour).hitTestable());
    _mark('INFO:app tour from settings ok');
    await tester.scrollUntilVisible(
      find.text(l10n.settingsSectionDetection),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await _pause(tester, 400);
    await _capture(tester, 'settings_detection');

    // A form with its own fields (the IRS W-4, from test/fixtures), opened
    // the way a PDF arrives from Files or Mail: fields carry the captions
    // printed on the form, not internal names. Unlimited, so the 4-page form
    // isn't stopped at the free page limit.
    await container
        .read(profileRepositoryProvider)
        .update(const UserProfileCompanion(isPurchased: Value(true)));
    // The script copies the form into the app's temp folder on request;
    // compiled in as a constant, it stalled the debug build's start-up.
    final tmp = await getTemporaryDirectory();
    final w4 = File(p.join(tmp.path, 'fw4.pdf'));
    _mark('NEED:w4');
    final until = DateTime.now().add(const Duration(seconds: 30));
    while (!w4.existsSync() || w4.lengthSync() == 0) {
      if (DateTime.now().isAfter(until)) fail('fw4.pdf was not provided');
      await _pause(tester, 250);
    }
    await _pause(tester, 500); // let the copy finish
    router.push(
      AppRoutes.capture,
      extra: OpenedFile(path: w4.path, name: 'fw4.pdf'),
    );
    await _waitFor(tester, find.byType(FillModeScreen), seconds: 60);
    await _waitFor(tester, find.byType(FieldBox));
    await _pause(tester, 1500);
    await _capture(tester, 'w4_fill');

    // Fill mode freezes fields: dragging one (an app-made field, which Edit
    // Fields can move) leaves its position and size as they were.
    final w4Doc =
        (await container.read(documentRepositoryProvider).watchAll().first)
            .firstWhere((d) => d.title == 'fw4');
    const lockedBox = '{"x":0.55,"y":0.9,"w":0.3,"h":0.04}';
    final lockedId = await container
        .read(fieldRepositoryProvider)
        .addField(
          FieldsCompanion.insert(
            documentId: w4Doc.id,
            pageIndex: 0,
            type: 'text',
            boundingBoxJson: lockedBox,
            label: const Value('Locked check'),
          ),
        );
    await _waitFor(tester, find.byKey(ValueKey(lockedId)));
    await _pause(tester, 500);
    await tester.timedDrag(
      find.byKey(ValueKey(lockedId)),
      const Offset(-120, -160),
      const Duration(milliseconds: 600),
    );
    await _pause(tester, 800);
    final locked =
        (await container
                .read(fieldRepositoryProvider)
                .watchFields(w4Doc.id)
                .first)
            .firstWhere((f) => f.id == lockedId);
    expect(
      locked.boundingBoxJson,
      lockedBox,
      reason: 'fill mode moved a field',
    );
    _mark('INFO:fill-mode field stayed put');
    await container.read(fieldRepositoryProvider).deleteField(lockedId);
    await _pause(tester, 500);
    await tester.tap(find.byType(FieldBox).first);
    await _waitFor(tester, find.text('First name and middle initial'));
    // My Details suggestions, the matching one first.
    expect(find.text(l10n.prefillSuggestions), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Priya K'), findsOneWidget);
    await _capture(tester, 'w4_field_label');
    await tester.tap(find.text(l10n.actionCancel));
    await _pause(tester, 600);

    // PreFill: the bar offers the matching empty fields; Fill fills exactly
    // those, Undo empties them again.
    Future<Map<String, String>> w4Values() async => {
      for (final f
          in await container
              .read(fieldRepositoryProvider)
              .watchFields(w4Doc.id)
              .first)
        if (f.isFilled) f.label: f.value,
    };
    // Offered twice: the teal bar on top and a Fill button in the bottom
    // row. First fill from the bottom button.
    const barFill = ValueKey('prefill-fill-bar');
    const bottomFill = ValueKey('prefill-fill-bottom');
    await _waitFor(tester, find.byKey(barFill));
    await _waitFor(tester, find.byKey(bottomFill));
    await _pause(tester, 600);
    await _capture(tester, 'w4_prefill_offer');
    _expectEqualWidths(tester, [
      _button(l10n.fillEditFields),
      find.byKey(bottomFill),
      _button(l10n.fillReviewAndFinish),
    ]);
    await tester.tap(find.byKey(bottomFill));
    // Both buttons go once there's nothing left to fill.
    await _waitGone(tester, find.byKey(bottomFill), seconds: 5);
    await _waitGone(tester, find.byKey(barFill), seconds: 5);
    await _pause(tester, 800);
    _expectEqualWidths(tester, [
      _button(l10n.fillEditFields),
      _button(l10n.fillReviewAndFinish),
    ]);
    _mark('INFO:bottom buttons equal width');
    final filled = await w4Values();
    expect(filled['First name and middle initial'], 'Priya K');
    expect(filled['Last name'], 'Raman');
    expect(filled['Address'], '12 Elm Street, Apt 4');
    expect(filled['City or town, state, and ZIP code'], 'Austin, TX 78701');
    for (final label in filled.keys) {
      expect(
        label.toLowerCase(),
        isNot(anyOf(contains('social security'), contains('employer'))),
        reason: 'PreFill filled "$label"',
      );
    }
    _mark('INFO:prefill filled ${filled.length}: ${filled.keys.join(' | ')}');
    await _capture(tester, 'w4_prefilled');
    await tester.tap(find.text(l10n.actionUndo));
    final undoBy = DateTime.now().add(const Duration(seconds: 5));
    while ((await w4Values()).isNotEmpty && DateTime.now().isBefore(undoBy)) {
      await _pause(tester, 200);
    }
    expect(await w4Values(), isEmpty, reason: 'Undo left values behind');
    _mark('INFO:prefill undo ok');
    // Then from the bar.
    await _waitFor(tester, find.byKey(barFill));
    await tester.tap(find.byKey(barFill));
    await _pause(tester, 1500);
    expect((await w4Values()).length, filled.length);
    _mark('INFO:prefill bar + bottom button ok');
    // Let the snackbar go before the next taps.
    ScaffoldMessenger.of(
      tester.element(find.byType(FillModeScreen)),
    ).hideCurrentSnackBar();
    await _pause(tester, 600);
    // Review & Finish from fill mode; tapping a field there comes back to
    // fill mode with that field's input open.
    await tester.tap(find.text(l10n.fillReviewAndFinish));
    await _waitFor(tester, find.text('Last name'));
    await _capture(tester, 'w4_review_list');
    _mark('INFO:w4 labels ok');
    await tester.tap(find.text('Last name'));
    await _waitFor(tester, find.byType(TextField));
    await _waitFor(tester, find.widgetWithText(TextField, 'Raman'));
    await _capture(tester, 'w4_review_tap_opens_field');
    await tester.tap(find.text(l10n.actionCancel));
    await _pause(tester, 600);

    // Straight after scanning: Save PDF on the Review screen keeps the scan as
    // a plain PDF, after a confirmation, and opens Send.
    final scanId = await _scannedDocument(container);
    router.go(AppRoutes.review.replaceAll(':docId', '$scanId'));
    await _waitFor(tester, find.text(l10n.pressSavePdf));
    await _pause(tester, 1500);
    await _capture(tester, 'scan_review_save_pdf');
    await tester.tap(find.text(l10n.pressSavePdf));
    await _waitFor(tester, find.text(l10n.saveNoFieldsTitle));
    await _capture(tester, 'scan_save_confirm');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.pressSavePdf),
      ),
    );
    await _waitFor(tester, find.byType(SendScreen), seconds: 60);
    await _capture(tester, 'scan_saved_send');
    final scan = await container
        .read(documentRepositoryProvider)
        .getById(scanId);
    expect(scan?.fillablePdfPath, isNotNull, reason: 'no PDF saved');
    _mark('INFO:scan saved without fields');

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

    // Categories: the imported W-4 was sorted on its own (keywords on the
    // simulator, the phone's model where it has one). The Library shows the
    // chips; a card's category opens the Change category sheet.
    final docs = container.read(documentRepositoryProvider);
    for (var i = 0; i < 40; i++) {
      final all = await docs.watchAll().first;
      if (all.any((d) => d.category != null)) break;
      await _pause(tester, 250);
    }
    final sorted = (await docs.watchAll().first)
        .where((d) => d.category != null)
        .map((d) => '${d.title}=${d.category}')
        .join(', ');
    _mark('INFO:sorted $sorted');
    router.go(AppRoutes.library);
    await _waitFor(tester, find.byType(ChoiceChip));
    await _waitGone(tester, find.byType(CircularProgressIndicator));
    await _pause(tester, 800);
    await _capture(tester, 'library_categories');
    await tester.tap(
      find
          .bySemanticsLabel(RegExp('^${RegExp.escape(l10n.categoryChange)}: '))
          .first,
    );
    await _waitFor(tester, find.text(l10n.categoryNew));
    await _pause(tester, 500);
    await _capture(tester, 'category_sheet');
    await tester.tap(find.text(l10n.categorySchool).last);
    await _pause(tester, 800);
    await tester.longPress(find.byType(Card).first);
    await _waitFor(tester, find.text(l10n.librarySelectedCount(1)));
    await _capture(tester, 'library_selecting');
    await tester.tap(
      find.byTooltip(
        MaterialLocalizations.of(
          tester.element(find.byType(LibraryScreen)),
        ).closeButtonTooltip,
      ),
    );
    await _pause(tester, 400);

    router.go(AppRoutes.settings);
    await _waitFor(tester, find.text(l10n.settingsSectionProfile));
    await tester.scrollUntilVisible(
      find.text(l10n.settingsAutoSortTitle),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await _pause(tester, 600);
    await _capture(tester, 'settings_sorting');

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
    // Wait for the route transition: tapping mid-slide misses the row.
    await _waitFor(tester, find.text(l10n.settingsRateApp).hitTestable());
    await _pause(tester, 400);
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

/// A freshly scanned one-page document: pages, no fields.
Future<int> _scannedDocument(ProviderContainer container) async {
  final doc = await container
      .read(documentRepositoryProvider)
      .createDocument('Receipt');
  final pdf = PdfDocument();
  pdf.pages.add().graphics.drawString(
    'Receipt  #1042\nThank you for your purchase.',
    PdfStandardFont(PdfFontFamily.helvetica, 22),
    bounds: const Rect.fromLTWH(40, 40, 460, 120),
  );
  final bytes = await pdf.save();
  pdf.dispose();
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'imports', 'scan_${doc.id}', 'scan.pdf'));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  await container
      .read(pageRepositoryProvider)
      .addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: '${file.path}#page=0',
      );
  return doc.id;
}

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

/// The bottom-row buttons share the row equally.
void _expectEqualWidths(WidgetTester tester, List<Finder> buttons) {
  final widths = [for (final b in buttons) tester.getSize(b).width];
  for (final w in widths) {
    expect(w, closeTo(widths.first, 1.0), reason: 'button widths $widths');
  }
}

/// The button whose label is [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<ButtonStyleButton>(),
);

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
