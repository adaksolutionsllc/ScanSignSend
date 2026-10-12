// The first-run tour includes PreFill, right after scanning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('page 2 of the tour is PreFill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        home: OnboardingScreen(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardScanTitle), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(l10n.onboardPrefillTitle), findsOneWidget);
    expect(find.text(l10n.onboardPrefillBody), findsOneWidget);
  });
}
