import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';

import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/field_detection_engine.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';

/// Builds an [OcrResult] from simple (text, rect) tuples so tests can exercise
/// the detection heuristics without a real OCR backend.
OcrResult _ocr(List<(String, Rect)> lines, {int w = 1000, int h = 1400}) {
  final blocks = lines
      .map((l) => OcrTextBlock(
            text: l.$1,
            boundingBox: l.$2,
            lines: [OcrTextLine(text: l.$1, boundingBox: l.$2)],
          ))
      .toList();
  return OcrResult(
    fullText: lines.map((l) => l.$1).join('\n'),
    blocks: blocks,
    imageWidth: w,
    imageHeight: h,
  );
}

void main() {
  final engine = FieldDetectionEngine();

  test('detects a signature label', () {
    final result = engine.detect(_ocr([
      ('Signature:', const Rect.fromLTWH(100, 200, 120, 24)),
    ]));
    expect(result, isNotEmpty);
    expect(result.first.type, FieldType.signature);
  });

  test('detects a date label to the right', () {
    final result = engine.detect(_ocr([
      ('Date', const Rect.fromLTWH(100, 300, 60, 24)),
    ]));
    expect(result.any((f) => f.type == FieldType.date), isTrue);
  });

  test('detects an underscore blank as a text field', () {
    final result = engine.detect(_ocr([
      ('__________', const Rect.fromLTWH(100, 400, 300, 24)),
    ]));
    expect(result.any((f) => f.type == FieldType.text), isTrue);
  });

  test('does not treat ordinary printed text as a field', () {
    final result = engine.detect(_ocr([
      ('Please read the terms carefully.',
          const Rect.fromLTWH(50, 100, 500, 24)),
    ]));
    expect(result, isEmpty);
  });

  test('returns empty for zero-size image (never divides by zero)', () {
    final result = engine.detect(_ocr(
      [('Signature:', const Rect.fromLTWH(0, 0, 10, 10))],
      w: 0,
      h: 0,
    ));
    expect(result, isEmpty);
  });

  test('caps output at 8 fields even with many candidates', () {
    final lines = <(String, Rect)>[
      for (var i = 0; i < 30; i++)
        ('Signature:', Rect.fromLTWH(10, 10.0 + i * 40, 120, 24)),
    ];
    final result = engine.detect(_ocr(lines));
    expect(result.length, lessThanOrEqualTo(8));
  });

  test('produces normalised bboxes within 0..1', () {
    final result = engine.detect(_ocr([
      ('Signature:', const Rect.fromLTWH(100, 200, 120, 24)),
    ]));
    for (final f in result) {
      expect(f.bbox.x, inInclusiveRange(0.0, 1.0));
      expect(f.bbox.y, inInclusiveRange(0.0, 1.0));
      expect(f.bbox.w, inInclusiveRange(0.0, 1.0));
      expect(f.bbox.h, inInclusiveRange(0.0, 1.0));
    }
  });
}
