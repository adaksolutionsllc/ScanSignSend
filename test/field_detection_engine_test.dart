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
        'at': FieldType.text,
        'born on': FieldType.date,
      });
      // "at ____" appears twice (address line, place of birth): both found.
      expect(r.fields.where((f) => f.label == 'at'), hasLength(2));
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
              'at': {'text': (0, 2)},
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
      containsAll(['Date of birth', 'Phone', 'born on', 'at', 'aged']),
    );
  });
}
