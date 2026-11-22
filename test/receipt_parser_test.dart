// Receipt details (F3): date, merchant, total, tax and currency read from
// receipt text as OCR returns it, for the receipts people in our markets
// actually get.

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/page_layout.dart';
import 'package:scan_sign_send/core/services/receipt_parser.dart';

final now = DateTime(2026, 11, 22);

ReceiptGuess read(String text, {bool dayFirst = true}) =>
    parseReceipt(text.trim().split('\n'), dayFirst: dayFirst, now: now);

void main() {
  test('amounts in every style, in minor units', () {
    expect(parseAmount('45.60'), 4560);
    expect(parseAmount('1,234.56'), 123456);
    expect(parseAmount('1.234,56'), 123456);
    expect(parseAmount('1 234,56'), 123456);
    expect(parseAmount('1,23,456.78'), 12345678);
    expect(parseAmount("1'234.50"), 123450);
    expect(parseAmount('450'), 45000);
    expect(parseAmount('12,5'), 1250);
    expect(parseAmount('1,234'), 123400);
    expect(parseAmount('12a'), isNull);
  });

  test('US grocery receipt', () {
    final r = read('''
TRADER JOE'S
2001 Point West Way
Sacramento CA 95815
11/03/2026 14:22
BANANAS 0.99
OAT MILK 3.49
SUBTOTAL 4.48
TAX 0.37
TOTAL 4.85
VISA 4.85
CHANGE 0.00
''', dayFirst: false);
    expect(r.merchant, "Trader Joe's");
    expect(r.date, DateTime(2026, 11, 3));
    expect(r.total, 485);
    expect(r.tax, 37);
    expect(r.currency, isNull, reason: r'no $ sign: the app uses the region');
  });

  test('India: GST tax invoice, CGST + SGST added up', () {
    final r = read('''
TAX INVOICE
CAFE COFFEE DAY
MG Road, Bengaluru 560001
GSTIN: 29AAACC1206D1ZI
Date: 14-11-2026  Time: 18:05
Cappuccino 1 x 180.00 180.00
Brownie 1 x 120.00 120.00
Sub Total 300.00
CGST @2.5% 7.50
SGST @2.5% 7.50
Grand Total ₹ 315.00
''');
    expect(r.merchant, 'Cafe Coffee Day');
    expect(r.date, DateTime(2026, 11, 14));
    expect(r.total, 31500);
    expect(r.tax, 1500);
    expect(r.currency, 'INR');
  });

  test('India: Rs. and a net payable line, lakh separators', () {
    final r = read('''
Reliance Digital
Bill No 4521   Dt 05/11/2026
LED TV 1 1,04,990.00
Net Payable Rs. 1,04,990.00
''');
    expect(r.total, 10499000);
    expect(r.currency, 'INR');
    expect(r.date, DateTime(2026, 11, 5));
  });

  test('France: TVA and TOTAL TTC, comma decimals', () {
    final r = read('''
CARREFOUR MARKET
12 rue de la Paix 75002 Paris
Le 08/11/2026 à 10:41
BAGUETTE 1,20
FROMAGE 4,85
TOTAL HT 5,50
TVA 5,5% 0,55
TOTAL TTC 6,05 €
CB 6,05
''');
    expect(r.merchant, 'Carrefour Market');
    expect(r.date, DateTime(2026, 11, 8));
    expect(r.total, 605);
    expect(r.tax, 55);
    expect(r.currency, 'EUR');
  });

  test('Spain: IVA, importe total, a written month', () {
    final r = read('''
Mercadona S.A.
C/ Gran Vía 10, Madrid
12 nov. 2026
TOTAL A PAGAR 23,40 €
IVA 10% 2,13
''');
    expect(r.date, DateTime(2026, 11, 12));
    expect(r.total, 2340);
    expect(r.tax, 213);
  });

  test('Brazil: R\$ with dot thousands', () {
    final r = read('''
PADARIA BOM PÃO LTDA
CNPJ 12.345.678/0001-90
20/10/2026
VALOR TOTAL R\$ 1.050,00
''');
    expect(r.merchant, 'Padaria Bom Pão Ltda');
    expect(r.total, 105000);
    expect(r.currency, 'BRL');
    expect(r.date, DateTime(2026, 10, 20));
  });

  test('UK: amount due after a total of items', () {
    final r = read('''
Boots
Nov 2, 2026
Total items 3
VAT 1.50
AMOUNT DUE £9.00
''');
    expect(r.total, 900);
    expect(r.tax, 150);
    expect(r.currency, 'GBP');
    expect(r.date, DateTime(2026, 11, 2));
  });

  test('nothing readable: nothing guessed', () {
    final r = read('hello world');
    expect(r.total, isNull);
    expect(r.tax, isNull);
    expect(r.date, isNull);
  });

  test('a future date or a phone number is not the date', () {
    final r = read('''
Shop
Ph 080-2345-6789
Valid till 31/12/2027
Date 01/11/2026
TOTAL 10.00
''');
    expect(r.date, DateTime(2026, 11, 1));
  });

  test('rows: a split label column and amount column join again', () {
    LayoutLine line(String text, double left, double top) => LayoutLine(
      text: text,
      box: Rect.fromLTWH(left, top, 0.2, 0.02),
      words: const [],
      fontSize: 0.02,
    );
    final rows = receiptRows(
      PageLayout(
        lines: [
          line('SUBTOTAL', 0.1, 0.50),
          line('TOTAL', 0.1, 0.53),
          line('4.48', 0.7, 0.501),
          line('4.85', 0.7, 0.532),
          line('STORE', 0.3, 0.1),
        ],
        rules: const [],
        aspect: 0.5,
      ),
    );
    expect(rows, ['STORE', 'SUBTOTAL  4.48', 'TOTAL  4.85']);
  });
}
