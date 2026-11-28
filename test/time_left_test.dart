// The time left under a long job's page count (1.3.1, 1.3.2).

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:scan_sign_send/shared/utils/time_left.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('rough minutes: under 50 s is "less than a minute"', () {
    expect(roughMinutes(const Duration(seconds: 49)), isNull);
    expect(roughMinutes(const Duration(seconds: 50)), 1);
    expect(roughMinutes(const Duration(seconds: 89)), 1);
    expect(roughMinutes(const Duration(seconds: 90)), 2);
    expect(roughMinutes(const Duration(minutes: 7)), 7);
  });

  test('the line shown', () {
    expect(
      timeLeftText(l10n, const Duration(seconds: 160)),
      l10n.progressMinutesLeft(3),
    );
    expect(
      timeLeftText(l10n, const Duration(seconds: 10)),
      l10n.progressUnderMinuteLeft,
    );
  });
}
