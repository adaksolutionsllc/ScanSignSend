import 'dart:io';

import 'package:intl/intl.dart';

/// The phone's region (not the app's language): it decides how a receipt's
/// dates are read, the currency a receipt without a sign is in, and how a
/// spreadsheet must be written for Excel to split it.
class Region {
  const Region(this.locale);

  /// From the phone's settings, e.g. "en_IN", "fr_FR".
  factory Region.device() {
    try {
      return Region(Intl.canonicalizedLocale(Platform.localeName));
    } catch (_) {
      return const Region('en_US');
    }
  }

  final String locale;

  String get country {
    final parts = locale.split(RegExp(r'[_-]'));
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }

  /// The region's currency code, "USD" when unknown.
  String get currency {
    try {
      return NumberFormat.simpleCurrency(locale: locale).currencyName ?? 'USD';
    } catch (_) {
      return 'USD';
    }
  }

  /// Whether "03/04" is the 3rd of April here. Month first only in the US
  /// and a few places that follow it.
  bool get dayFirst => !const {
    'US',
    'PH',
    'PR',
    'GU',
    'AS',
    'VI',
    'UM',
    'MP',
    'FM',
    'MH',
    'PW',
    'BZ',
  }.contains(country);

  /// Whether numbers are written "1.234,56" here; then Excel also expects
  /// ";" between columns.
  bool get decimalComma {
    try {
      return NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP == ',';
    } catch (_) {
      return false;
    }
  }
}
