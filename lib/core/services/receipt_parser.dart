import 'dart:math' as math;

import 'page_layout.dart';

/// What could be read from a receipt. Any part may be missing; the user
/// corrects or completes it before exporting.
class ReceiptGuess {
  const ReceiptGuess({
    this.date,
    this.merchant,
    this.total,
    this.tax,
    this.currency,
  });

  final DateTime? date;
  final String? merchant;

  /// Amounts in minor units (cents, paise): no rounding errors.
  final int? total;
  final int? tax;

  /// ISO 4217 code ("INR", "EUR"), or null when the receipt doesn't say.
  final String? currency;
}

/// The page's text as rows, top to bottom, each row's pieces left to right.
///
/// OCR often returns a receipt's label column ("TOTAL") and its amount
/// column ("45.60") as separate lines; joining lines whose middles are at
/// the same height puts them back on one row.
List<String> receiptRows(PageLayout layout) {
  final lines = [...layout.lines]
    ..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));
  final rows = <List<LayoutLine>>[];
  for (final line in lines) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null) {
      final ref = row.first.box;
      final tolerance = math.min(ref.height, line.box.height) * 0.6;
      if ((line.box.center.dy - ref.center.dy).abs() <= tolerance) {
        row.add(line);
        continue;
      }
    }
    rows.add([line]);
  }
  return [
    for (final row in rows)
      ([...row]..sort((a, b) => a.box.left.compareTo(b.box.left)))
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join('  '),
  ].where((r) => r.isNotEmpty).toList();
}

/// Reads date, merchant, total, tax and currency from a receipt's [rows].
///
/// Receipts are printed in many styles, so each part is a best guess, and
/// one the user can correct. [dayFirst] decides "03/04/2026" when nothing
/// else does (false for US-style dates). [now] bounds plausible dates.
ReceiptGuess parseReceipt(
  List<String> rows, {
  bool dayFirst = true,
  DateTime? now,
}) {
  final currency = _currency(rows);
  return ReceiptGuess(
    date: _date(rows, dayFirst: currency == 'USD' ? false : dayFirst, now: now),
    merchant: _merchant(rows),
    total: _total(rows),
    tax: _tax(rows),
    currency: currency,
  );
}

// ── Amounts ──────────────────────────────────────────────────────────────

/// A money amount: digits with optional thousands separators and two
/// decimals ("1,234.56", "1.234,56", "1 234,56", "1,23,456.78"), or whole
/// digits.
final _amount = RegExp(
  r"(?<![\d.,])(\d{1,3}(?:[,.\u00A0 ']\d{2,3})+(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)(?![\d])",
);

/// [token] in minor units, or null. The last separator is the decimal one
/// when one or two digits follow it ("12,5" is 12.50); three digits after
/// it are thousands.
int? parseAmount(String token) {
  final t = token.replaceAll(RegExp(r"[\u00A0 ']"), '');
  final m = RegExp(r'^(.*?)[.,](\d{1,2})$').firstMatch(t);
  final whole = (m == null ? t : m.group(1)!).replaceAll(RegExp(r'[.,]'), '');
  if (whole.isEmpty || !RegExp(r'^\d+$').hasMatch(whole)) return null;
  if (whole.length > 9) return null;
  final cents = m == null ? 0 : int.parse(m.group(2)!.padRight(2, '0'));
  return int.parse(whole) * 100 + cents;
}

/// The amounts on [row], left to right, skipping percentages ("18%") and
/// numbers that are part of a date or a time.
List<(int, bool)> _amountsIn(String row) {
  final cleaned = row
      .replaceAll(_dateLike, ' ')
      .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?\b'), ' ');
  final out = <(int, bool)>[];
  for (final m in _amount.allMatches(cleaned)) {
    final after = cleaned.substring(m.end).trimLeft();
    if (after.startsWith('%')) continue;
    final v = parseAmount(m.group(1)!);
    // The flag: written with decimals, as money nearly always is.
    if (v != null) out.add((v, RegExp(r'[.,]\d{2}$').hasMatch(m.group(1)!)));
  }
  return out;
}

/// Words that mark the amount to pay, strongest first. OCR reads Latin
/// script only, so receipts in India are matched by their English words.
const _totalWords = [
  // Strongest: the final amount.
  [
    'grand total',
    'amount due',
    'balance due',
    'total due',
    'net payable',
    'amount payable',
    'total payable',
    'net amount',
    'net amt',
    'bill amount',
    'total amount',
    'total to pay',
    'total ttc',
    'total à payer',
    'total a payer',
    'net à payer',
    'net a payer',
    'montant total',
    'montant ttc',
    'total a pagar',
    'importe total',
    'valor total',
    'valor a pagar',
    'total geral',
  ],
  ['total'],
];

/// Rows that say "total" but are not the amount to pay.
final _notTotal = RegExp(
  r'sub\s*-?\s*total|sous[\s-]*total|total\s+(items?|qty|quantity|'
  r'savings?|discount|tax|gst|vat|tva|iva|articles?|art[ií]culos?|'
  r'itens|weight)|total\s+hors|\bht\b',
  caseSensitive: false,
);

int? _total(List<String> rows) {
  for (final words in _totalWords) {
    var best = 0;
    for (final (i, row) in rows.indexed) {
      final lower = row.toLowerCase();
      if (!words.any(lower.contains) || _notTotal.hasMatch(lower)) continue;
      var amounts = _amountsIn(row);
      // The amount can sit on the next row when the row split anyway.
      if (amounts.isEmpty && i + 1 < rows.length) {
        amounts = _amountsIn(rows[i + 1]);
      }
      // The last amount on the row: "TOTAL 3 items 45.60".
      final money = amounts.where((a) => a.$2).toList();
      final pick = (money.isNotEmpty ? money : amounts).lastOrNull;
      if (pick != null && pick.$1 > best) best = pick.$1;
    }
    if (best > 0) return best;
  }
  return null;
}

/// Tax lines; CGST + SGST (India) are added up, as are several VAT rates.
final _taxRow = RegExp(
  r'\b(c\s*gst|s\s*gst|ut\s*gst|i\s*gst|gst|vat|tva|iva|tax|taxes|'
  r'impuestos?|impostos?|icms)\b',
  caseSensitive: false,
);

int? _tax(List<String> rows) {
  var sum = 0;
  var found = false;
  final seen = <String>{};
  for (final row in rows) {
    final lower = row.toLowerCase();
    final m = _taxRow.firstMatch(lower);
    if (m == null) continue;
    // "Total incl. tax" and "GSTIN: 29ABCDE…" are not tax amounts.
    if (RegExp(
      r'gstin|tax\s*invoice|incl|inclu|excl|registration|reg\.? no|'
      r'\bno\b|number|tax id|vat no',
    ).hasMatch(lower)) {
      continue;
    }
    final money = _amountsIn(row).where((a) => a.$2).toList();
    if (money.isEmpty) continue;
    // One line per kind of tax: a summary repeating "CGST 9.00" counts once.
    final key = '${m.group(1)!.replaceAll(' ', '')}:${money.last.$1}';
    if (!seen.add(key)) continue;
    sum += money.last.$1;
    found = true;
  }
  return found ? sum : null;
}

// ── Currency ─────────────────────────────────────────────────────────────

const _currencySigns = [
  (r'R\$|\bBRL\b|\breais\b', 'BRL'),
  (r'₹|\bINR\b|\bRs\.?(?=\s*\d)|\bRs\b', 'INR'),
  (r'€|\bEUR\b', 'EUR'),
  (r'£|\bGBP\b', 'GBP'),
  (r'\bCAD\b|C\$', 'CAD'),
  (r'\bAUD\b|A\$', 'AUD'),
  (r'\bUSD\b|US\$', 'USD'),
  (r'\bMXN\b', 'MXN'),
  (r'\bCHF\b', 'CHF'),
  (r'\$', 'USD'),
];

String? _currency(List<String> rows) {
  final all = rows.join('\n');
  for (final (pattern, code) in _currencySigns) {
    if (RegExp(pattern).hasMatch(all)) return code;
  }
  // India: GST lines without a currency sign.
  if (RegExp(r'\b[cs]\s*gst\b|gstin', caseSensitive: false).hasMatch(all)) {
    return 'INR';
  }
  return null;
}

// ── Date ─────────────────────────────────────────────────────────────────

final _dateLike = RegExp(r'\b\d{1,4}[/.\-]\d{1,2}[/.\-]\d{2,4}\b');

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7,
  'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  // French, Spanish, Portuguese (first letters, after the English ones).
  'janv': 1, 'fév': 2, 'fev': 2, 'mars': 3, 'avr': 4, 'mai': 5, 'juin': 6,
  'juil': 7, 'aoû': 8, 'aou': 8, 'sept': 9, 'déc': 12,
  'ene': 1, 'abr': 4, 'ago': 8, 'dic': 12,
  'fevereiro': 2, 'set': 9, 'out': 10, 'dez': 12,
};

final _wordDate = RegExp(
  r'\b(\d{1,2})(?:st|nd|rd|th|er)?[\s\-.]*(?:de\s+)?([a-zéû]{3,9})\.?[\s\-,]*(?:de\s+)?(\d{2,4})\b'
  r'|\b([a-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
  caseSensitive: false,
);

DateTime? _date(List<String> rows, {required bool dayFirst, DateTime? now}) {
  final today = now ?? DateTime.now();
  bool plausible(DateTime d) =>
      d.year >= 2000 && !d.isAfter(today.add(const Duration(days: 1)));

  for (final row in rows) {
    for (final m in _dateLike.allMatches(row)) {
      final parts = m.group(0)!.split(RegExp(r'[/.\-]'));
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      var c = int.parse(parts[2]);
      DateTime? d;
      if (parts[0].length == 4) {
        d = _ymd(a, b, c);
      } else {
        if (parts[2].length == 2) c += 2000;
        if (parts[2].length == 3) continue;
        // A day over 12 settles the order; otherwise the region's habit.
        final dmy = _ymd(c, b, a);
        final mdy = _ymd(c, a, b);
        if (a > 12) {
          d = dmy;
        } else if (b > 12) {
          d = mdy;
        } else {
          d = dayFirst ? dmy : mdy;
        }
      }
      if (d != null && plausible(d)) return d;
    }
    for (final m in _wordDate.allMatches(row.toLowerCase())) {
      final (dayS, monS, yearS) = m.group(1) != null
          ? (m.group(1)!, m.group(2)!, m.group(3)!)
          : (m.group(5)!, m.group(4)!, m.group(6)!);
      final month = _monthOf(monS);
      if (month == null) continue;
      var year = int.parse(yearS);
      if (yearS.length == 2) year += 2000;
      final d = _ymd(year, month, int.parse(dayS));
      if (d != null && plausible(d)) return d;
    }
  }
  return null;
}

int? _monthOf(String word) {
  final w = word.toLowerCase();
  for (var n = math.min(w.length, 9); n >= 3; n--) {
    final m = _months[w.substring(0, n)];
    if (m != null) return m;
  }
  return null;
}

DateTime? _ymd(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  // DateTime rolls 31 April over into May: that wasn't a date.
  return date.month == m ? date : null;
}

// ── Merchant ─────────────────────────────────────────────────────────────

/// Rows near the top that are not the shop's name.
final _notMerchant = RegExp(
  r'receipt|invoice|bill\b|tax|gstin|vat|tel|phone|ph\b|fax|www\.|\.com|'
  r'@|welcome|bienvenue|bienvenido|bem-vindo|order|table|cashier|date|'
  r'ticket|recibo|reçu|facture|factura|nota fiscal|cnpj|siret|nif|cif|'
  r'original|copy|duplicate',
  caseSensitive: false,
);

String? _merchant(List<String> rows) {
  for (final row in rows.take(6)) {
    final text = row.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(text).length;
    // A name: mostly letters, not an address line (digits), not a label.
    if (letters < 3 || letters < text.length * 0.6) continue;
    if (_notMerchant.hasMatch(text)) continue;
    return _titleCase(text);
  }
  return null;
}

/// "BIG BAZAAR" → "Big Bazaar"; mixed case is kept as printed.
String _titleCase(String s) {
  if (s != s.toUpperCase()) return s;
  return s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
