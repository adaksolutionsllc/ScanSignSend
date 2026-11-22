// Receipts → Export to spreadsheet (F3): columns that Excel splits the
// right way in each region, amounts that stay numbers, text that stays one
// cell.

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/receipt_csv.dart';

const headers = ReceiptCsvHeaders(
  date: 'Date',
  merchant: 'Merchant',
  total: 'Total',
  tax: 'Tax',
  currency: 'Currency',
  document: 'Document',
);

final rows = [
  ReceiptCsvRow(
    document: 'Lunch, team',
    date: DateTime(2026, 11, 14),
    merchant: 'Cafe "Day"',
    total: 31500,
    tax: 1500,
    currency: 'INR',
  ),
  const ReceiptCsvRow(document: 'Taxi', total: 905),
];

void main() {
  test('dot regions: commas between columns, dot decimals', () {
    expect(
      buildReceiptCsv(rows, headers: headers, decimalComma: false),
      '\uFEFFDate,Merchant,Total,Tax,Currency,Document\r\n'
      '2026-11-14,"Cafe ""Day""",315.00,15.00,INR,"Lunch, team"\r\n'
      ',,9.05,,,Taxi\r\n',
    );
  });

  test('comma regions: semicolons between columns, comma decimals', () {
    expect(
      buildReceiptCsv(rows, headers: headers, decimalComma: true),
      '\uFEFFDate;Merchant;Total;Tax;Currency;Document\r\n'
      '2026-11-14;"Cafe ""Day""";315,00;15,00;INR;Lunch, team\r\n'
      ';;9,05;;;Taxi\r\n',
    );
  });
}
