// Field detection: blanks become fields of the right type, sized to the
// document's text, signatures are found (and get a date), and plain text is
// left alone. The PDF case builds an affidavit-shaped document with the same
// structure as a real sample (inline underscore blanks, "Date: ____", a
// signature line over "DEPONENT (NAME)") without any real personal data.

import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/field_detection_engine.dart';
import 'package:scan_sign_send/core/services/field_hints.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';
import 'package:scan_sign_send/core/services/page_layout.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

final _engine = FieldDetectionEngine();

/// Builds a PDF whose pages carry [pages] lines of Helvetica 11.5pt text,
/// each at its given top (points), and returns its path.
String _pdf(List<List<(double, String)>> pages) {
  final doc = PdfDocument();
  doc.pageSettings.size = const Size(612, 792);
  doc.pageSettings.margins.all = 0;
  final font = PdfStandardFont(PdfFontFamily.helvetica, 11.5);
  for (final lines in pages) {
    final page = doc.pages.add();
    for (final (top, text) in lines) {
      page.graphics.drawString(
        text,
        font,
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        bounds: Rect.fromLTWH(72, top, 480, 16),
      );
    }
  }
  final path =
      '${Directory.systemTemp.path}/sss_detect_${DateTime.now().microsecondsSinceEpoch}.pdf';
  File(path).writeAsBytesSync(doc.saveSync());
  doc.dispose();
  return path;
}

DetectionResult _detectPdf(String path, int page) {
  final (lines, aspect) = pdfTextLayout((path, page))!;
  return _engine.detect(
    PageLayout(lines: lines, rules: const [], aspect: aspect),
  );
}

/// A one-line OCR result in a 1000×1414 image, as ML Kit would report it.
OcrResult _ocr(List<(Rect, List<(String, Rect)>)> lines) => OcrResult(
  fullText: lines.map((l) => l.$2.map((e) => e.$1).join(' ')).join('\n'),
  imageWidth: 1000,
  imageHeight: 1414,
  blocks: [
    for (final (box, words) in lines)
      OcrTextBlock(
        text: words.map((e) => e.$1).join(' '),
        boundingBox: box,
        lines: [
          OcrTextLine(
            text: words.map((e) => e.$1).join(' '),
            boundingBox: box,
            elements: [
              for (final (t, r) in words)
                OcrTextElement(text: t, boundingBox: r),
            ],
          ),
        ],
      ),
  ],
);

void main() {
  group('affidavit-style PDF', () {
    late String path;
    setUpAll(() {
      path = _pdf([
        [
          (100, 'AFFIDAVIT'),
          (170, 'I, the undersigned, A. PERSON, aged ______ years, residing'),
          (187, 'at ______________________________, in the district.'),
          (230, '1. I am the deponent herein and a citizen of India.'),
          (260, '2. I was born on ______, at ______, in the district.'),
          (300, '3. The statements above are true and correct.'),
        ],
        [
          (110, 'So I do hereby solemnly affirm the above.'),
          (170, 'Place: Chennai'),
          (190, 'Date: ______________________'),
          (250, '_______________________________'),
          (270, 'DEPONENT (A. PERSON)'),
        ],
      ]);
    });
    tearDownAll(() => File(path).deleteSync());

    test('every inline blank is a field of the right type', () {
      final r = _detectPdf(path, 0);
      final byLabel = {for (final f in r.fields) f.label: f.type};
      expect(byLabel, {
        'aged': FieldType.text,
        'residing at': FieldType.text,
        'born on': FieldType.date,
        'born at': FieldType.text,
      });
      // "at ____" appears twice. A bare "at" says nothing, so each takes the
      // word before it: from the line above ("…residing" / "at ____") and
      // from past the blank before it ("born on ____, at ____").
      expect(r.fields, hasLength(4), reason: 'no fields on plain sentences');
    });

    test('fields are one line of the document text tall, on the blank', () {
      final r = _detectPdf(path, 0);
      expect(
        r.textSize! * 792,
        closeTo(11.5, 0.3),
        reason: 'body text size is measured from the PDF',
      );
      for (final f in r.fields) {
        expect(f.bbox.h * 792, closeTo(11.5 * 1.45, 1.0));
        for (final v in [
          f.bbox.x,
          f.bbox.y,
          f.bbox.x + f.bbox.w,
          f.bbox.y + f.bbox.h,
        ]) {
          expect(v, inInclusiveRange(0.0, 1.0));
        }
      }
      final aged = r.fields.firstWhere((f) => f.label == 'aged');
      expect(
        aged.bbox.w * 612,
        greaterThan(25),
        reason: 'covers the underscore run, not a guessed width',
      );
    });

    test('signature line over the signer, with today\'s date paired', () {
      final r = _detectPdf(path, 1);
      final sig = r.fields.singleWhere((f) => f.type == FieldType.signature);
      expect(sig.label, 'DEPONENT (A. PERSON)');
      expect(
        sig.bbox.y + sig.bbox.h,
        closeTo(262 / 792, 0.02),
        reason: 'sits on the signature line',
      );
      final date = r.fields.singleWhere((f) => f.type == FieldType.date);
      expect(date.label, 'Date');
      expect(
        date.autoToday,
        isTrue,
        reason: 'the existing Date blank is paired with the signature',
      );
    });
  });

  test('a signature with no date nearby gets one added beside it', () {
    final path = _pdf([
      [
        (100, 'Terms and conditions apply to this agreement.'),
        (400, 'Signature: ______________________'),
      ],
    ]);
    final r = _detectPdf(path, 0);
    File(path).deleteSync();
    final sig = r.fields.singleWhere((f) => f.type == FieldType.signature);
    final date = r.fields.singleWhere((f) => f.type == FieldType.date);
    expect(date.autoToday, isTrue);
    expect(
      (date.bbox.y + date.bbox.h) - (sig.bbox.y + sig.bbox.h),
      lessThan(0.06),
      reason: 'placed beside (or just below) the signature',
    );
  });

  test('white space above a signer name is a signature, even with no line', () {
    final path = _pdf([
      [
        (100, 'I confirm the information given is correct.'),
        (640, 'APPLICANT (RAVI KUMAR)'),
      ],
    ]);
    final r = _detectPdf(path, 0);
    File(path).deleteSync();
    final sig = r.fields.singleWhere((f) => f.type == FieldType.signature);
    expect(
      sig.bbox.y + sig.bbox.h,
      lessThan(640 / 792),
      reason: 'in the gap above the name',
    );
  });

  test('plain text produces no fields', () {
    final path = _pdf([
      [
        (100, 'This is an ordinary paragraph with no blanks in it.'),
        (117, 'Neither does this line, which mentions the date only.'),
      ],
    ]);
    expect(_detectPdf(path, 0).fields, isEmpty);
    File(path).deleteSync();
  });

  group('scanned page (OCR)', () {
    test('underscores and signature keywords from OCR words', () {
      final layout = PageLayout(
        lines: ocrLayout(
          _ocr([
            (
              const Rect.fromLTRB(100, 300, 700, 322),
              [
                ('Name:', const Rect.fromLTRB(100, 300, 170, 322)),
                ('__________', const Rect.fromLTRB(180, 300, 480, 322)),
              ],
            ),
            (
              const Rect.fromLTRB(100, 900, 600, 922),
              [
                ('Signature', const Rect.fromLTRB(100, 900, 210, 922)),
                ('__________', const Rect.fromLTRB(220, 900, 520, 922)),
              ],
            ),
          ]),
        ),
        rules: const [],
        aspect: 1000 / 1414,
      );
      final r = _engine.detect(layout);
      expect(
        r.fields.map((f) => f.type),
        containsAll([FieldType.text, FieldType.signature, FieldType.date]),
      );
      expect(r.textSize, isNotNull);
    });

    test('a drawn line is a blank; an underline under words is not', () {
      final words = ocrLayout(
        _ocr([
          (
            const Rect.fromLTRB(100, 400, 260, 420),
            [('Father\'s name', const Rect.fromLTRB(100, 400, 260, 420))],
          ),
          (
            const Rect.fromLTRB(100, 500, 400, 520),
            [('IMPORTANT NOTICE', const Rect.fromLTRB(100, 500, 400, 520))],
          ),
        ]),
      );
      final layout = PageLayout(
        lines: words,
        rules: [
          // Free line to the right of the label → a blank.
          const Rect.fromLTRB(0.28, 0.2965, 0.7, 0.2975),
          // Line right under "IMPORTANT NOTICE" → underlined text.
          const Rect.fromLTRB(0.1, 0.369, 0.4, 0.370),
        ],
        aspect: 1000 / 1414,
      );
      final r = _engine.detect(layout);
      expect(r.fields, hasLength(1));
      expect(r.fields.single.type, FieldType.text);
      expect(r.fields.single.label, 'Father\'s name');
    });

    test('a checkbox glyph becomes a square checkbox', () {
      final layout = PageLayout(
        lines: ocrLayout(
          _ocr([
            (
              const Rect.fromLTRB(100, 600, 400, 620),
              [
                ('☐', const Rect.fromLTRB(100, 600, 120, 620)),
                ('I', const Rect.fromLTRB(130, 600, 136, 620)),
                ('agree', const Rect.fromLTRB(140, 600, 200, 620)),
              ],
            ),
          ]),
        ),
        rules: const [],
        aspect: 1000 / 1414,
      );
      final cb = _engine.detect(layout).fields.single;
      expect(cb.type, FieldType.checkbox);
      expect(cb.bbox.w * 1000, closeTo(cb.bbox.h * 1414, 1.0));
    });
  });

  test('two checkboxes on one line each get their own text', () {
    final layout = PageLayout(
      lines: ocrLayout(
        _ocr([
          (
            const Rect.fromLTRB(100, 600, 900, 620),
            [
              ('☐', const Rect.fromLTRB(100, 600, 120, 620)),
              ('I', const Rect.fromLTRB(130, 600, 136, 620)),
              ('have', const Rect.fromLTRB(140, 600, 190, 620)),
              ('pets', const Rect.fromLTRB(195, 600, 240, 620)),
              ('☐', const Rect.fromLTRB(500, 600, 520, 620)),
              ('Non-smoking', const Rect.fromLTRB(530, 600, 650, 620)),
              ('household', const Rect.fromLTRB(655, 600, 760, 620)),
            ],
          ),
        ]),
      ),
      rules: const [],
      aspect: 1000 / 1414,
    );
    final labels = [
      for (final f in _engine.detect(layout).fields)
        if (f.type == FieldType.checkbox) f.label,
    ];
    expect(labels, ['I have pets', 'Non-smoking household']);
  });

  test('the demo rental form: one checkbox per item, each with its text', () {
    final r = _detectPdf('tool/store_capture/forms/Rental_Application.pdf', 0);
    final labels = [
      for (final f in r.fields)
        if (f.type == FieldType.checkbox) f.label,
    ]..sort();
    expect(labels, [
      'I have pets',
      'Non-smoking household',
      'Parking space needed',
    ]);
  });

  test('line detector finds a free line, ignores text, underlines and boxes', () {
    final image = img.Image(width: 1000, height: 1414)
      ..clear(img.ColorRgb8(255, 255, 255));
    final black = img.ColorRgb8(0, 0, 0);
    // A free fill-in line.
    img.fillRect(image, x1: 300, y1: 400, x2: 700, y2: 401, color: black);
    // A dotted leader.
    for (var x = 300; x < 650; x += 6) {
      img.fillRect(image, x1: x, y1: 500, x2: x + 2, y2: 501, color: black);
    }
    // "Text": a row of tall glyph blocks.
    for (var x = 100; x < 600; x += 14) {
      img.fillRect(image, x1: x, y1: 700, x2: x + 9, y2: 716, color: black);
    }
    // Underlined text: glyphs sitting right on a line.
    for (var x = 100; x < 400; x += 14) {
      img.fillRect(image, x1: x, y1: 800, x2: x + 9, y2: 814, color: black);
    }
    img.fillRect(image, x1: 100, y1: 816, x2: 400, y2: 817, color: black);
    // A box (table cell).
    img.drawRect(image, x1: 500, y1: 900, x2: 800, y2: 960, color: black);

    final path =
        '${Directory.systemTemp.path}/sss_rules_${DateTime.now().microsecondsSinceEpoch}.png';
    File(path).writeAsBytesSync(img.encodePng(image));
    final rules = detectRules(path);
    File(path).deleteSync();

    expect(rules, hasLength(2));
    final ys = rules.map((r) => (r.top * 1414).round()).toList()..sort();
    expect(ys[0], closeTo(400, 2));
    expect(ys[1], closeTo(500, 2));
  });

  group('white space between words', () {
    test('a sentence interrupted by a gap, and "Label:" gaps, are blanks', () {
      final path = _pdf([
        [
          (100, 'I am aged                      years and live here.'),
          (140, 'Name:                                Age:'),
          (180, "Father's name:"),
        ],
      ]);
      final r = _detectPdf(path, 0);
      File(path).deleteSync();
      final labels = r.fields.map((f) => f.label).toSet();
      expect(labels, containsAll(['aged', 'Name', 'Age', "Father's name"]));
      expect(r.fields.every((f) => f.type == FieldType.text), isTrue);
    });

    test(
      'aligned columns, justified text and sentence-ending colons are not',
      () {
        final path = _pdf([
          [
            (100, 'ARUL DIVYA KUMAR            (Name at birth / in passport)'),
            (140, 'do hereby solemnly affirm and declare on oath that:'),
            (180, 'This   line   has   wide   but   ordinary   spacing.'),
          ],
        ]);
        expect(_detectPdf(path, 0).fields, isEmpty);
        File(path).deleteSync();
      },
    );
  });

  test('an invoice: table columns, header and footer get no fields', () {
    // Shaped like a real invoice (made-up business and customer): a header
    // with text beside a logo, a bill-to block with dates on the right, a
    // table (Description / Rate / Qty / Amount) with wrapped descriptions,
    // and a footer URL with the print date. Table borders count as drawn
    // lines, which makes the page look form-like — the hard case.
    final doc = PdfDocument();
    doc.pageSettings.size = const Size(612, 792);
    doc.pageSettings.margins.all = 0;
    final page = doc.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final right = PdfStringFormat(alignment: PdfTextAlignment.right);
    void at(double x, double y, String t, {bool alignRight = false}) =>
        page.graphics.drawString(
          t,
          font,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: alignRight
              ? Rect.fromLTWH(x - 120, y, 120, 12)
              : Rect.fromLTWH(x, y, 400, 12),
          format: alignRight ? right : null,
        );
    at(60, 60, 'Northwind Builders LLC');
    at(60, 76, 'Jordan Lee');
    at(60, 90, 'Business Number 5550104477');
    at(60, 104, 'jordan.lee@example.com');
    at(470, 104, '555-010-4477'); // text inside the logo
    at(60, 150, 'BILL TO');
    at(560, 150, 'DATE', alignRight: true);
    at(60, 164, 'Sam Rivera');
    at(560, 164, '04/06/2026', alignRight: true);
    at(60, 178, '12 Example Way, Springfield 00000');
    at(560, 190, 'DUE DATE', alignRight: true);
    at(560, 204, '04/06/2026', alignRight: true);
    at(72, 240, 'DESCRIPTION');
    at(440, 240, 'RATE', alignRight: true);
    at(500, 240, 'QTY');
    at(590, 240, 'AMOUNT', alignRight: true);
    const rows = [
      (
        'Framing',
        r'$3,000.00',
        'Framing of the rear walls, including a new door frame.',
      ),
      (
        'Drywall',
        r'$10,000.00',
        'Installation of drywall, with all joints and sanding.',
      ),
      (
        'Flooring',
        r'$6,000.00',
        'Surface preparation of the entire living space.',
      ),
      (
        'Lighting',
        r'$5,000.00',
        'Installation of recessed light fixtures and switches.',
      ),
      (
        'Paint',
        r'$1,000.00',
        'Painted the entire base to achieve a finished appearance.',
      ),
      ('Plumbing', r'$1,150.00', 'Installation of a new toilet and sink.'),
    ];
    var y = 262.0;
    for (final (item, rate, desc) in rows) {
      at(72, y, item);
      at(440, y, rate, alignRight: true);
      at(500, y, '1');
      at(590, y, rate, alignRight: true);
      at(72, y + 13, desc);
      y += 40;
    }
    at(40, 770, 'https://app.example.com/v/abc123XYZ');
    at(500, 770, '4/7/26, 9:54 AM');
    final path =
        '${Directory.systemTemp.path}/sss_invoice_${DateTime.now().microsecondsSinceEpoch}.pdf';
    File(path).writeAsBytesSync(doc.saveSync());
    doc.dispose();

    final (lines, aspect) = pdfTextLayout((path, 0))!;
    File(path).deleteSync();
    final r = _engine.detect(
      PageLayout(
        lines: lines,
        // A table border under the header row.
        rules: const [Rect.fromLTRB(0.1, 0.32, 0.92, 0.321)],
        aspect: aspect,
      ),
    );
    expect([for (final f in r.fields) '${f.type.name} "${f.label}"'], isEmpty);
  });

  test('a table row gap (rate, then qty) is a column, not a blank', () {
    // Each row: an amount, a wide gap, the quantity, then the total close
    // by — the gap stands out on its own line, but every row has it.
    final layout = PageLayout(
      lines: ocrLayout(
        _ocr([
          for (var row = 0; row < 5; row++)
            (
              Rect.fromLTWH(100, 400.0 + row * 50, 800, 24),
              [
                ('Item', Rect.fromLTWH(100, 400.0 + row * 50, 60, 24)),
                ('cost', Rect.fromLTWH(170, 400.0 + row * 50, 50, 24)),
                ('total', Rect.fromLTWH(230, 400.0 + row * 50, 60, 24)),
                ('due', Rect.fromLTWH(300, 400.0 + row * 50, 40, 24)),
                ('now', Rect.fromLTWH(560, 400.0 + row * 50, 40, 24)),
                ('ok', Rect.fromLTWH(610, 400.0 + row * 50, 30, 24)),
              ],
            ),
        ]),
      ),
      // A table border right under the first row (an underline, not a
      // blank), which makes the page look form-like.
      rules: const [Rect.fromLTRB(0.1, 0.2996, 0.9, 0.3003)],
      aspect: 1000 / 1414,
    );
    expect([
      for (final f in _engine.detect(layout).fields)
        '${f.type.name} "${f.label}" x=${f.bbox.x.toStringAsFixed(3)} y=${f.bbox.y.toStringAsFixed(3)}',
    ], isEmpty);
  });

  group('unlabelled gaps need a reason to be a blank', () {
    // One line of words (x positions in a 1000-wide page) at [y], on a page
    // made form-like by an underline elsewhere; returns the fields found.
    List<String> detectLine(double y, List<(String, double, double)> words) {
      final layout = PageLayout(
        lines: ocrLayout(
          _ocr([
            (
              Rect.fromLTRB(words.first.$2, y, words.last.$3, y + 20),
              [
                for (final (t, l, r) in words)
                  (t, Rect.fromLTRB(l, y, r, y + 20)),
              ],
            ),
            // An underlined heading: form-like, but itself no blank.
            (
              const Rect.fromLTRB(100, 300, 300, 320),
              [('Application', const Rect.fromLTRB(100, 300, 300, 320))],
            ),
          ]),
        ),
        rules: const [Rect.fromLTRB(0.1, 0.2264, 0.3, 0.2268)],
        aspect: 1000 / 1414,
      );
      return [for (final f in _engine.detect(layout).fields) f.label];
    }

    test('the same sentence mid-page is a blank (control)', () {
      expect(
        detectLine(700, [
          ('I', 100, 110),
          ('am', 120, 150),
          ('aged', 160, 210),
          ('years', 500, 560),
          ('old', 570, 610),
        ]),
        ['aged'],
      );
    });

    test('in the footer band it is not', () {
      expect(
        detectLine(1360, [
          ('I', 100, 110),
          ('am', 120, 150),
          ('aged', 160, 210),
          ('years', 500, 560),
          ('old', 570, 610),
        ]),
        isEmpty,
      );
    });

    test('after an email address or a URL it is not', () {
      expect(
        detectLine(700, [
          ('Write', 100, 160),
          ('to', 170, 190),
          ('sam@example.com', 200, 380),
          ('for', 640, 670),
          ('help', 680, 730),
        ]),
        isEmpty,
      );
    });

    test('before a date or an amount it is not', () {
      expect(
        detectLine(700, [
          ('Bill', 100, 140),
          ('to', 150, 170),
          ('Sam', 180, 220),
          ('Rivera', 230, 300),
          ('04/06/2026', 640, 760),
        ]),
        isEmpty,
      );
    });

    test('after a colon that ends a sentence it is not', () {
      expect(
        detectLine(700, [
          ('Married', 100, 180),
          ('filing', 190, 250),
          ('jointly):', 260, 350),
          ('enter', 640, 700),
          ('both', 710, 760),
        ]),
        isEmpty,
      );
    });
  });

  test('an article with headings and a "following:" line has no fields', () {
    // Shaped like a help page: paragraphs, short title-case headings after
    // white space, a sentence ending in a colon and a "(Note:" aside.
    final path = _pdf([
      [
        (100, 'Graphic art on this site is offered in multiple formats.'),
        (117, 'When using other formats, please note the following:'),
        (151, 'PDF, the Adobe Portable Document Format, preserves the'),
        (168, 'look and feel of the original. (Note: your system may'),
        (185, 'show the file extension as PS.) See http://example.com/.'),
        (480, 'Flash Animation'),
        (510, 'Some materials are offered as animations for the web.'),
        (700, 'Graphic File Formats'),
        (730, 'Files are compressed to make downloading faster.'),
      ],
    ]);
    expect(_detectPdf(path, 0).fields, isEmpty);
    File(path).deleteSync();
  });

  test('prose whose word boxes are narrower than the words has no gaps', () {
    // Seen on Android: every word box covered only part of the word, so each
    // ordinary space measured several em wide.
    const words = ['most', 'of', 'the', 'images', 'you', 'see', 'are', 'low'];
    final layout = PageLayout(
      lines: ocrLayout(
        _ocr([
          for (var row = 0; row < 4; row++)
            (
              Rect.fromLTWH(100, 200.0 + row * 40, 960, 30),
              [
                for (var i = 0; i < words.length; i++)
                  (
                    words[i],
                    Rect.fromLTWH(100.0 + i * 120, 200.0 + row * 40, 20, 30),
                  ),
              ],
            ),
        ]),
      ),
      rules: const [],
      aspect: 1000 / 1414,
    );
    expect(_engine.detect(layout).fields, isEmpty);
  });

  group('learning from the user', () {
    PageLayout layoutOf(String path) {
      final (lines, aspect) = pdfTextLayout((path, 0))!;
      return PageLayout(lines: lines, rules: const [], aspect: aspect);
    }

    test('a phrase the user keeps adding a field after gets one', () {
      final path = _pdf([
        [(200, 'Aadhaar No. 1234 is required for this application form.')],
        [(200, 'Aadhaar No.')],
      ]);
      const hints = LearnedHints({
        'aadhaar no': {'text': (2, 0)},
      });
      final (lines, aspect) = pdfTextLayout((path, 1))!;
      final learned = _engine
          .detect(
            PageLayout(lines: lines, rules: const [], aspect: aspect),
            hints: hints,
          )
          .fields;
      expect(learned.single.type, FieldType.text);
      expect(learned.single.label, 'Aadhaar No');
      // Not where the phrase is followed straight on by more text.
      final (l0, a0) = pdfTextLayout((path, 0))!;
      expect(
        _engine
            .detect(
              PageLayout(lines: l0, rules: const [], aspect: a0),
              hints: hints,
            )
            .fields,
        isEmpty,
      );
      File(path).deleteSync();
    });

    test('the user\'s type wins, and repeated deletions suppress', () {
      final path = _pdf([
        [(260, '2. I was born on ______, at ______, in the district.')],
      ]);
      final layout = layoutOf(path);
      File(path).deleteSync();
      final baseline = _engine.detect(layout).fields;
      expect(
        baseline.map((f) => f.type),
        containsAll([FieldType.date, FieldType.text]),
      );

      final taught = _engine
          .detect(
            layout,
            hints: const LearnedHints({
              'born on': {'text': (3, 0), 'date': (0, 3)},
              'born at': {'text': (0, 2)},
            }),
          )
          .fields;
      expect(taught.single.label, 'born on');
      expect(taught.single.type, FieldType.text);
    });

    test('one-off edits never change behaviour', () {
      const hints = LearnedHints({
        'born on': {'text': (1, 0), 'date': (0, 1)},
      });
      expect(hints.preferredType('born on'), isNull);
      expect(hints.suppressed('born on', FieldType.date), isFalse);
      expect(normalizePhrase("Father's  Name :"), "father's name");
    });
  });

  test('labels keep short phrases whole and drop leading filler', () {
    final path = _pdf([
      [
        (100, 'Date of birth: ______________   Phone: ______________'),
        (140, '2. I was born on ______, at ______, in the district.'),
        (180, 'I, the undersigned, A. PERSON, aged ______ years.'),
      ],
    ]);
    final labels = _detectPdf(path, 0).fields.map((f) => f.label).toList();
    File(path).deleteSync();
    expect(
      labels,
      containsAll(['Date of birth', 'Phone', 'born on', 'born at', 'aged']),
    );
  });
}
