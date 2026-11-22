/// One receipt in the spreadsheet.
class ReceiptCsvRow {
  const ReceiptCsvRow({
    required this.document,
    this.date,
    this.merchant = '',
    this.total,
    this.tax,
    this.currency = '',
  });

  final String document;
  final DateTime? date;
  final String merchant;

  /// Minor units (cents, paise).
  final int? total;
  final int? tax;
  final String currency;
}

/// The column titles, in the app's language.
class ReceiptCsvHeaders {
  const ReceiptCsvHeaders({
    required this.date,
    required this.merchant,
    required this.total,
    required this.tax,
    required this.currency,
    required this.document,
  });

  final String date, merchant, total, tax, currency, document;
}

/// Receipts → Export to spreadsheet: a .csv that Excel, Numbers and Google
/// Sheets open as columns.
///
/// Excel splits a .csv by the region's list separator: a comma where
/// numbers are written "1,234.56", a semicolon where they are "1.234,56".
/// So [decimalComma] (from the phone's region) picks both the separator and
/// how amounts are written. Dates are 2026-11-22, which every spreadsheet
/// reads as a date in any region. The byte-order mark makes Excel read ₹, €
/// and accents as UTF-8.
String buildReceiptCsv(
  List<ReceiptCsvRow> rows, {
  required ReceiptCsvHeaders headers,
  required bool decimalComma,
}) {
  final sep = decimalComma ? ';' : ',';
  String cell(String v) =>
      v.contains(sep) || v.contains('"') || v.contains('\n') || v.contains('\r')
      ? '"${v.replaceAll('"', '""')}"'
      : v;
  String amount(int? minor) {
    if (minor == null) return '';
    final s =
        '${minor ~/ 100}${decimalComma ? ',' : '.'}'
        '${(minor % 100).toString().padLeft(2, '0')}';
    return s;
  }

  String date(DateTime? d) => d == null
      ? ''
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  final lines = [
    [
      headers.date,
      headers.merchant,
      headers.total,
      headers.tax,
      headers.currency,
      headers.document,
    ].map(cell).join(sep),
    for (final r in rows)
      [
        date(r.date),
        cell(r.merchant),
        amount(r.total),
        amount(r.tax),
        cell(r.currency),
        cell(r.document),
      ].join(sep),
  ];
  // CRLF: what RFC 4180 and Excel expect.
  return '\uFEFF${lines.join('\r\n')}\r\n';
}
