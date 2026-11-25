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
import 'package:scan_sign_send/core/services/background_work_service.dart';
import 'package:scan_sign_send/core/services/import_job.dart';
import 'package:scan_sign_send/core/services/import_job_runner.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/services/opened_file_service.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/models/document_model.dart';
import 'package:scan_sign_send/features/review/presentation/job_screen.dart';
import 'package:scan_sign_send/features/fill_mode/presentation/fill_mode_screen.dart';
import 'package:scan_sign_send/features/review/presentation/crop_screen.dart';
import 'package:scan_sign_send/features/review/presentation/review_screen.dart';
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
      extra: [OpenedFile(path: w4.path, name: 'fw4.pdf')],
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
    // Up to 5 s: on a busy emulator the writes take longer than 1.5 s.
    final fillBy = DateTime.now().add(const Duration(seconds: 5));
    while ((await w4Values()).length < filled.length &&
        DateTime.now().isBefore(fillBy)) {
      await _pause(tester, 200);
    }
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

    // A tilted photo of a page, opened from Files: its edges are found and
    // offered for confirmation; Crop straightens it before Review.
    final photoPath = await _tiltedPhoto(tmp, 'photo', 'receipt_photo.jpg');
    router.push(
      AppRoutes.capture,
      extra: [OpenedFile(path: photoPath, name: 'receipt_photo.jpg')],
    );
    await _waitFor(
      tester,
      find.byWidgetPredicate((w) => w is CropScreen || w is ReviewScreen),
      seconds: 60,
    );
    expect(
      find.byType(CropScreen),
      findsOneWidget,
      reason: 'no corner check for a tilted photo',
    );
    await _pause(tester, 1200);
    await _capture(tester, 'photo_crop');
    await tester.tap(find.text(l10n.cropApply));
    await _waitFor(tester, find.byType(ReviewScreen), seconds: 60);
    // The newest document (sorting may already have renamed it).
    final photoDoc =
        (await container.read(documentRepositoryProvider).watchAll().first)
            .reduce((a, b) => a.id > b.id ? a : b);
    final photoPage =
        (await container.read(pageRepositoryProvider).pagesOf(photoDoc.id))
            .single;
    final cropped = img.decodeJpg(
      await File(PathResolver.resolve(photoPage.imagePath)).readAsBytes(),
    )!;
    _mark('INFO:photo cropped to ${cropped.width}x${cropped.height}');
    expect(cropped.width, lessThan(1200), reason: 'photo was not cropped');
    await _pause(tester, 1500);
    await _capture(tester, 'photo_cropped_review');

    // A PDF that is only a photo of paper gets the same check; "Use whole
    // image" keeps it as it was.
    final photoPdf = await _photoOnlyPdf(tmp);
    router.go(AppRoutes.library);
    await _waitFor(tester, find.byType(LibraryScreen));
    router.push(
      AppRoutes.capture,
      extra: [OpenedFile(path: photoPdf, name: 'photo_scan.pdf')],
    );
    await _waitFor(tester, find.byType(CropScreen), seconds: 60);
    await _pause(tester, 1200);
    await _capture(tester, 'photo_pdf_crop');
    await tester.tap(find.text(l10n.cropUseWhole));
    await _waitFor(tester, find.byType(ReviewScreen), seconds: 60);
    _mark('INFO:photo-only pdf offered the corner check');

    // A long photo-only PDF: the user is asked first and told that it takes
    // longer for bigger files. Skip goes straight to Review, unchanged.
    Future<Document> newest() async =>
        (await container.read(documentRepositoryProvider).watchAll().first)
            .reduce((a, b) => a.id > b.id ? a : b);
    Future<void> openLong(String name, {int pages = 6}) async {
      final path = await _photoOnlyPdf(tmp, pages: pages, name: name);
      router.go(AppRoutes.library);
      await _waitFor(tester, find.byType(LibraryScreen));
      router.push(
        AppRoutes.capture,
        extra: [OpenedFile(path: path, name: name)],
      );
      await _waitFor(tester, find.text(l10n.straightenAskTitle), seconds: 60);
      // About how long it takes, from this phone's past runs.
      expect(
        find.textContaining(
          RegExp('For these $pages pages this takes (about|less)'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.straightenAskLater), findsOneWidget);
      expect(find.text(l10n.straightenKeep), findsOneWidget);
    }

    await openLong('long_scan.pdf');
    await _capture(tester, 'straighten_ask');
    await tester.tap(find.byKey(const ValueKey('straighten-skip')));
    await _waitFor(tester, find.byType(ReviewScreen), seconds: 60);
    final skipped = await container
        .read(pageRepositoryProvider)
        .pagesOf((await newest()).id);
    expect(skipped, hasLength(6));
    expect(
      skipped.every((pg) => pg.imagePath.contains('#page=')),
      isTrue,
      reason: 'Skip changed the pages',
    );
    _mark('INFO:long pdf skipped: 6 pdf pages kept');

    // Kept as is, then straightened later from Review: back on the same
    // Review, the pages now images.
    await _waitFor(tester, find.byKey(const ValueKey('review-straighten')));
    await _capture(tester, 'review_straighten_button');
    await tester.tap(find.byKey(const ValueKey('review-straighten')));
    await _waitFor(tester, find.byType(CropScreen), seconds: 180);
    await _pause(tester, 800);
    await tester.tap(find.text(l10n.cropApply));
    await _waitFor(tester, find.text(l10n.reviewPageOf(2, 6)));
    await tester.tap(find.byKey(const ValueKey('crop-use-whole-rest')));
    await _waitGone(tester, find.byType(CropScreen), seconds: 180);
    // The job screen shows the straightening, then returns to Review.
    await _waitGone(tester, find.byType(JobScreen), seconds: 180);
    await _pause(tester, 1000);
    expect(
      find.byType(ReviewScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'a second Review was opened',
    );
    final later = await container
        .read(pageRepositoryProvider)
        .pagesOf((await newest()).id);
    expect(
      later.any((pg) => pg.imagePath.contains('#page=')),
      isFalse,
      reason: 'Straighten pages left PDF pages',
    );
    _mark('INFO:straightened later from Review');

    // Again, straightened: page counts while it checks and while it
    // straightens; page 1 cropped, the rest kept whole in one tap.
    await openLong('long_scan_2.pdf');
    final watch = Stopwatch()..start();
    await tester.tap(find.byKey(const ValueKey('straighten-go')));
    final checkCount = await _waitNoting(
      tester,
      find.byType(CropScreen),
      find.textContaining(RegExp(r'^Checking page \d of 6')),
      seconds: 180,
    );
    _mark(
      'INFO:long pdf checked 6 pages in ${watch.elapsedMilliseconds} ms '
      '(count shown: $checkCount)',
    );
    await _pause(tester, 800);
    await tester.tap(find.text(l10n.cropApply));
    await _waitFor(tester, find.text(l10n.reviewPageOf(2, 6)));
    await _capture(tester, 'crop_use_whole_rest');
    await tester.tap(find.byKey(const ValueKey('crop-use-whole-rest')));
    watch.reset();
    final straightenCount = await _waitNoting(
      tester,
      find.byType(ReviewScreen),
      find.textContaining(RegExp(r'^Straightening page \d of 6')),
      seconds: 180,
    );
    _mark(
      'INFO:long pdf straightened 6 pages in ${watch.elapsedMilliseconds} ms '
      '(count shown: $straightenCount)',
    );
    final long = await container
        .read(pageRepositoryProvider)
        .pagesOf((await newest()).id);
    expect(long, hasLength(6));
    expect(
      long.any((pg) => pg.imagePath.contains('#page=')),
      isFalse,
      reason: 'not every page became an image',
    );
    Future<int> widthOf(String stored) async => img
        .decodeJpg(await File(PathResolver.resolve(stored)).readAsBytes())!
        .width;
    final w1 = await widthOf(long[0].imagePath);
    final w2 = await widthOf(long[1].imagePath);
    _mark('INFO:long pdf page widths $w1 (cropped) $w2 (whole)');
    expect(w1, lessThan(w2), reason: 'page 1 was not cropped');

    // Skip while the pages are checked: on to Review, nothing changed.
    Future<void> expectUnchanged(String why, {int pages = 6}) async {
      final kept = await container
          .read(pageRepositoryProvider)
          .pagesOf((await newest()).id);
      expect(kept, hasLength(pages));
      expect(
        kept.every((pg) => pg.imagePath.contains('#page=')),
        isTrue,
        reason: why,
      );
      expect(
        File(
          PathResolver.resolve(kept[0].imagePath.split('#page=').first),
        ).existsSync(),
        isTrue,
        reason: 'the PDF is gone after $why',
      );
    }

    await openLong('long_scan_3.pdf', pages: 24);
    await tester.tap(find.byKey(const ValueKey('straighten-go')));
    await _waitFor(tester, find.byKey(const ValueKey('edge-check-skip')));
    _mark('CAPTURE:edge_check_progress');
    await _pause(tester, 700); // the job screen slides in
    await tester.tap(find.byKey(const ValueKey('edge-check-skip')));
    await _waitFor(tester, find.byType(ReviewScreen), seconds: 60);
    await expectUnchanged('Skip while checking', pages: 24);
    _mark('INFO:skip while checking went to Review, pages kept');

    // Skip while the pages are straightened: the PDF stays as it was. More
    // pages, so that Skip lands while the job still works.
    await openLong('long_scan_4.pdf', pages: 24);
    await tester.tap(find.byKey(const ValueKey('straighten-go')));
    await _waitFor(tester, find.byType(CropScreen), seconds: 180);
    await _pause(tester, 800);
    await tester.tap(find.text(l10n.cropApply));
    await _waitFor(tester, find.text(l10n.reviewPageOf(2, 24)));
    await tester.tap(find.byKey(const ValueKey('crop-use-whole-rest')));
    await _waitFor(
      tester,
      find.byKey(const ValueKey('straighten-progress-skip')),
    );
    _mark('CAPTURE:straighten_progress');
    await _pause(tester, 700); // the job screen slides in
    await tester.tap(find.byKey(const ValueKey('straighten-progress-skip')));
    await _waitFor(tester, find.byType(ReviewScreen), seconds: 60);
    await expectUnchanged('Skip while straightening', pages: 24);
    _mark('INFO:skip while straightening went to Review, pdf kept');

    // Before the restart below: its new runner takes over the channel.
    // The phone ends the background time (iOS, phone locked; it shows
    // "Task failed"): the job pauses. Back in the app it goes on, and the
    // app says nothing was lost (tester, build 26).
    await openLong('long_scan_6.pdf', pages: 24);
    await tester.tap(find.byKey(const ValueKey('straighten-go')));
    await _waitFor(tester, find.byKey(const ValueKey('job-pause')));
    await _pause(tester, 700); // the job screen slides in
    final jobs = container.read(importJobRunnerProvider);
    final awayId = (await newest()).id;
    // What BackgroundWorkPlugin sends when iOS ends the time.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'com.scansignsend/background',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('expired')),
      (_) {},
    );
    await _waitFor(
      tester,
      find.byKey(const ValueKey('job-resume')),
      seconds: 60,
    );
    final awayBy = DateTime.now().add(const Duration(seconds: 60));
    while (jobs.view(awayId)!.running) {
      if (DateTime.now().isAfter(awayBy)) {
        fail('the system pause never stopped it');
      }
      await _pause(tester, 200);
    }
    final awayAt = jobs.view(awayId)!.done;
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    // The page after the last one finished; the progress shown while
    // paused may still name the one before.
    final told = find.textContaining(
      RegExp(
        RegExp.escape(l10n.jobResumedNotice(999)).replaceAll('999', r'\d+'),
      ),
    );
    await _waitFor(tester, told);
    final from = int.parse(
      RegExp(r'\d+').allMatches(tester.widget<Text>(told).data!).last[0]!,
    );
    expect(from, inInclusiveRange(awayAt + 1, awayAt + 2));
    await _pause(tester, 400);
    _mark('CAPTURE:job_resumed_after_lock');
    await _pause(tester, 1200);
    ScaffoldMessenger.of(
      tester.element(find.byType(JobScreen)),
    ).hideCurrentSnackBar();
    await jobs.skip(awayId);
    await _waitFor(tester, find.byType(ReviewScreen), seconds: 60);
    await _pause(tester, 600);
    _mark('INFO:system pause went on from page $from, told');

    // Pause, use the app, and go on after a restart (plan 1.3.2): the job
    // is saved after every page. A new runner stands in for a restarted
    // app: it reads the saved job, shows it paused, and finishes it.
    await openLong('long_scan_5.pdf', pages: 24);
    await tester.tap(find.byKey(const ValueKey('straighten-go')));
    await _waitFor(tester, find.byType(CropScreen), seconds: 180);
    await _pause(tester, 800);
    await tester.tap(find.text(l10n.cropApply));
    await _waitFor(tester, find.text(l10n.reviewPageOf(2, 24)));
    await tester.tap(find.byKey(const ValueKey('crop-use-whole-rest')));
    await _waitFor(tester, find.byKey(const ValueKey('job-pause')));
    await _pause(tester, 700); // the job screen slides in
    await tester.tap(find.byKey(const ValueKey('job-pause')));
    final runner = container.read(importJobRunnerProvider);
    final resumable = (await newest()).id;
    await _waitFor(
      tester,
      find.byKey(const ValueKey('job-resume')),
      seconds: 60,
    );
    // The pages in work finish first; then nothing runs.
    final stopBy = DateTime.now().add(const Duration(seconds: 60));
    while (runner.view(resumable)!.running) {
      if (DateTime.now().isAfter(stopBy)) fail('the pause never stopped it');
      await _pause(tester, 200);
    }
    final pausedAt = runner.view(resumable)!.done;
    _mark('INFO:paused at page $pausedAt of 24');
    expect(pausedAt, lessThan(24), reason: 'finished before the pause');
    await _capture(tester, 'job_paused');
    await tester.tap(find.byKey(const ValueKey('job-keep-using')));
    await _waitFor(tester, find.byType(LibraryScreen));
    await _waitFor(tester, find.text(l10n.jobPaused));
    await _pause(tester, 600);
    _mark('CAPTURE:library_job_paused');
    final restarted = ImportJobRunner(
      edges: container.read(edgeCheckServiceProvider),
      docRepo: container.read(documentRepositoryProvider),
      store: ImportJobStore(),
      phone: BackgroundWorkService(),
    );
    await restarted.restore();
    expect(restarted.view(resumable)?.paused, isTrue, reason: 'not saved');
    await restarted.resume(resumable);
    final resumeBy = DateTime.now().add(const Duration(seconds: 180));
    while (restarted.hasJob(resumable)) {
      if (DateTime.now().isAfter(resumeBy)) fail('the resumed job never ended');
      await _pause(tester, 250);
    }
    final resumed = await container
        .read(pageRepositoryProvider)
        .pagesOf(resumable);
    expect(resumed, hasLength(24));
    expect(
      resumed.any((pg) => pg.imagePath.contains('#page=')),
      isFalse,
      reason: 'the resumed job left PDF pages',
    );
    expect(
      resumed.map((pg) => pg.imagePath).toSet(),
      hasLength(24),
      reason: 'a page twice',
    );
    // The first runner still holds the paused job: Skip clears it.
    await runner.skip(resumable);
    await _pause(tester, 600);
    expect(find.text(l10n.jobPaused), findsNothing);
    _mark('INFO:paused job saved and resumed after a restart: 24 pages');

    // Photos with no words: Detect Fields finds nothing. TestFlight 1.3.1
    // (22): a painting got 7 fields from its brush strokes.
    final picture = (await newest()).id;
    router.go(AppRoutes.fieldDetection.replaceAll(':docId', '$picture'));
    await _waitFor(tester, find.text(l10n.detectSkipToFill), seconds: 120);
    await _pause(tester, 800);
    await _capture(tester, 'detect_picture_no_fields');
    _mark('INFO:photos with no words got no fields');

    // Straight after scanning: "Skip fields · Save & Share" on the Review
    // screen saves the scan as a finished (Completed) PDF, after a
    // confirmation, and opens Send.
    final scanId = await _scannedDocument(container);
    router.go(AppRoutes.review.replaceAll(':docId', '$scanId'));
    await _waitFor(tester, find.text(l10n.reviewSkipFieldsSave));
    await _pause(tester, 1500);
    await _capture(tester, 'scan_review_save_pdf');
    await tester.tap(find.text(l10n.reviewSkipFieldsSave));
    await _waitFor(tester, find.text(l10n.saveNoFieldsTitle));
    await _capture(tester, 'scan_save_confirm');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.saveAndShare),
      ),
    );
    await _waitFor(tester, find.byType(SendScreen), seconds: 60);
    await _capture(tester, 'scan_saved_send');
    final scan = await container
        .read(documentRepositoryProvider)
        .getById(scanId);
    expect(scan?.pressedPdfPath, isNotNull, reason: 'no PDF saved');
    expect(scan?.statusEnum, DocumentStatus.pressed, reason: 'not Completed');
    _mark('INFO:scan saved without fields as Completed');

    // A document with no fields swipes between pages in Fill mode, and the
    // page chips follow (tester, build 26: "click each page number").
    final plainId = await _plainPagesDocument(container, 12);
    router.go(AppRoutes.fillMode.replaceAll(':docId', '$plainId'));
    await _waitFor(tester, find.byType(PageView));
    await _pause(tester, 1200);
    String chip() =>
        (tester
                    .widgetList<ChoiceChip>(find.byType(ChoiceChip))
                    .singleWhere((c) => c.selected)
                    .label
                as Text)
            .data!;
    await _capture(tester, 'fill_swipe_page1');
    _mark('RECORD:fill_swipe');
    await _pause(tester, 800);
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
      await _pause(tester, 900);
    }
    expect(chip(), '5', reason: 'swipes did not move the page');
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1200);
    await _pause(tester, 900);
    expect(chip(), '4');
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '9'));
    await _pause(tester, 400);
    await tester.tap(find.widgetWithText(ChoiceChip, '9'));
    await _pause(tester, 900);
    expect(chip(), '9', reason: 'chip tap did not move the page');
    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
      await _pause(tester, 900);
    }
    expect(chip(), '12');
    _mark('STOP:fill_swipe');
    await _pause(tester, 600);
    await _capture(tester, 'fill_swipe_page12');
    _mark('INFO:no-fields doc swiped 1→5→4, chip 9, swiped to 12');

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

/// A photo of a white page lying tilted on a dark table, saved as a JPEG in
/// its own folder under [tmp] (opened files are deleted with their folder).
Future<String> _tiltedPhoto(Directory tmp, String folder, String name) async {
  final image = img.Image(width: 1200, height: 1600);
  img.fill(image, color: img.ColorRgb8(70, 58, 50));
  img.fillPolygon(
    image,
    vertices: [
      img.Point(220, 180),
      img.Point(1010, 120),
      img.Point(1060, 1420),
      img.Point(160, 1460),
    ],
    color: img.ColorRgb8(246, 244, 238),
  );
  for (var i = 0; i < 12; i++) {
    img.fillRect(
      image,
      x1: 330,
      y1: 330 + i * 80,
      x2: 900 - (i % 3) * 120,
      y2: 344 + i * 80,
      color: img.ColorRgb8(35, 35, 40),
    );
  }
  final dir = Directory(p.join(tmp.path, 'opened_check', folder));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(img.encodeJpg(image, quality: 90));
  return file.path;
}

/// A PDF whose [pages] pages each hold only that photo: no text layer, no
/// fields.
Future<String> _photoOnlyPdf(
  Directory tmp, {
  int pages = 1,
  String name = 'photo_scan.pdf',
}) async {
  final jpg = await File(
    await _tiltedPhoto(tmp, 'pdfsrc', 'page.jpg'),
  ).readAsBytes();
  final pdf = PdfDocument();
  pdf.pageSettings.margins.all = 0;
  for (var i = 0; i < pages; i++) {
    final page = pdf.pages.add();
    final size = page.getClientSize();
    page.graphics.drawImage(
      PdfBitmap(jpg),
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
  }
  final bytes = await pdf.save();
  pdf.dispose();
  final dir = Directory(p.join(tmp.path, 'opened_check', 'pdf'));
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes);
  return file.path;
}

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

/// A scanned document of [pages] image pages, each with its number large,
/// and no fields.
Future<int> _plainPagesDocument(ProviderContainer container, int pages) async {
  final doc = await container
      .read(documentRepositoryProvider)
      .createDocument('Sale deed');
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(dir.path, 'scans', 'plain_${doc.id}'));
  await folder.create(recursive: true);
  for (var i = 0; i < pages; i++) {
    final image = img.Image(width: 840, height: 1188);
    img.fill(image, color: img.ColorRgb8(250, 249, 245));
    for (var line = 0; line < 14; line++) {
      img.fillRect(
        image,
        x1: 90,
        y1: 380 + line * 50,
        x2: 750 - (line % 4) * 90,
        y2: 392 + line * 50,
        color: img.ColorRgb8(60, 60, 68),
      );
    }
    final number = img.Image(width: 120, height: 60);
    img.fill(number, color: img.ColorRgb8(250, 249, 245));
    img.drawString(
      number,
      '${i + 1}',
      font: img.arial48,
      x: 10,
      y: 5,
      color: img.ColorRgb8(30, 60, 150),
    );
    img.compositeImage(
      image,
      img.copyResize(number, width: 360),
      dstX: 90,
      dstY: 90,
    );
    final file = File(p.join(folder.path, 'page_$i.jpg'));
    await file.writeAsBytes(img.encodeJpg(image, quality: 85));
    await container
        .read(pageRepositoryProvider)
        .addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: PathResolver.toStorable(file.path),
        );
  }
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

/// Waits for [target] like [_waitFor], and says whether [note] showed on the
/// way (a progress text, which may be on screen only briefly).
Future<bool> _waitNoting(
  WidgetTester tester,
  Finder target,
  Finder note, {
  int seconds = 30,
}) async {
  var seen = false;
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (note.evaluate().isNotEmpty) seen = true;
    if (target.evaluate().isNotEmpty) return seen;
  }
  throw TestFailure('Timed out waiting for $target');
}

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
