// The first-run tour includes PreFill; after an update, only the pages added
// since are shown, once ("What's new"); Settings can replay the whole tour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();

  Future<void> pump(
    WidgetTester tester, {
    Set<String>? only,
    VoidCallback? done,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        home: OnboardingScreen(onDone: done ?? () {}, only: only),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('which tour to show at launch', () {
    test('first run: the whole tour', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await unseenTourPages(), isNull);
    });

    test('updated from 1.1.0 or earlier: only the PreFill page', () async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      expect(await unseenTourPages(), {'prefill'});
    });

    test('seen everything: nothing', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        kTourPagesSeen: kTourPageIds,
      });
      expect(await unseenTourPages(), isEmpty);
    });
  });

  testWidgets('page 2 of the whole tour is PreFill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.text(l10n.onboardScanTitle), findsOneWidget);
    expect(find.text(l10n.tourWhatsNew), findsNothing);
    expect(find.text(l10n.actionSkip), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardPrefillTitle), findsOneWidget);
    expect(find.text(l10n.onboardPrefillBody), findsOneWidget);
  });

  testWidgets("What's new: just the new page, and it's then seen", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    var done = false;
    await pump(tester, only: {'prefill'}, done: () => done = true);
    expect(find.text(l10n.tourWhatsNew), findsOneWidget);
    expect(find.text(l10n.onboardPrefillTitle), findsOneWidget);
    expect(find.text(l10n.onboardScanTitle), findsNothing);
    expect(find.text(l10n.actionSkip), findsNothing);

    await tester.tap(find.text(l10n.tourGotIt));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(await unseenTourPages(), isEmpty);
  });
}
