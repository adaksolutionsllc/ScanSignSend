// The extra lines under a long job's page count (1.3.1): a rough time left
// from the speed so far, and a light line that changes every few seconds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:scan_sign_send/shared/widgets/progress_extras.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('rough minutes: under 50 s is "less than a minute"', () {
    expect(roughMinutes(const Duration(seconds: 49)), isNull);
    expect(roughMinutes(const Duration(seconds: 50)), 1);
    expect(roughMinutes(const Duration(seconds: 89)), 1);
    expect(roughMinutes(const Duration(seconds: 90)), 2);
    expect(roughMinutes(const Duration(minutes: 7)), 7);
  });

  Future<void> show(WidgetTester tester, int done, int total, int seconds) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: Scaffold(
            body: ProgressExtras(
              done: done,
              total: total,
              elapsed: Duration(seconds: seconds),
            ),
          ),
        ),
      );

  testWidgets('time left from the speed so far', (tester) async {
    await show(tester, 0, 18, 0);
    expect(find.textContaining('left'), findsNothing, reason: 'no speed yet');

    // 2 pages in 20 s: 16 more take about 160 s.
    await show(tester, 2, 18, 20);
    expect(find.text(l10n.progressMinutesLeft(3)), findsOneWidget);

    await show(tester, 17, 18, 170);
    expect(find.text(l10n.progressUnderMinuteLeft), findsOneWidget);

    await show(tester, 18, 18, 180);
    expect(find.textContaining('left'), findsNothing, reason: 'done');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the light line changes every 3 seconds', (tester) async {
    await show(tester, 1, 6, 5);
    expect(find.text(l10n.progressQuip1), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.progressQuip2), findsOneWidget);
    expect(find.text(l10n.progressQuip1), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
