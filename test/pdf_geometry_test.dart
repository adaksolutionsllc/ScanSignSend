import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/pdf_geometry.dart';

void main() {
  // A4 in points (72 dpi): 595 × 842.
  const pw = 595.0;
  const ph = 842.0;

  test('normToPdf scales by page point size', () {
    const b = BoundingBox(x: 0.1, y: 0.2, w: 0.5, h: 0.05);
    final r = PdfGeometry.normToPdf(b, pw, ph);
    expect(r.left, closeTo(59.5, 0.001));
    expect(r.top, closeTo(168.4, 0.001));
    expect(r.width, closeTo(297.5, 0.001));
    expect(r.height, closeTo(42.1, 0.001));
  });

  test('round-trips norm → pdf → norm within epsilon', () {
    const cases = [
      BoundingBox(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
      BoundingBox(x: 0.1, y: 0.2, w: 0.5, h: 0.05),
      BoundingBox(x: 0.73, y: 0.91, w: 0.2, h: 0.03),
    ];
    for (final b in cases) {
      final back = PdfGeometry.pdfToNorm(
          PdfGeometry.normToPdf(b, pw, ph), pw, ph);
      expect(back.x, closeTo(b.x, 1e-9));
      expect(back.y, closeTo(b.y, 1e-9));
      expect(back.w, closeTo(b.w, 1e-9));
      expect(back.h, closeTo(b.h, 1e-9));
    }
  });

  test('pdfToNorm clamps out-of-range / inverted input', () {
    // A widget partly off the page → clamped into [0,1], positive w/h.
    final r = const Rect.fromLTWH(-10, -10, 5000, 5000);
    final b = PdfGeometry.pdfToNorm(r, pw, ph);
    expect(b.x, 0.0);
    expect(b.y, 0.0);
    expect(b.w, 1.0);
    expect(b.h, 1.0);
  });

  test('pdfToNorm is safe on a degenerate (zero-size) page', () {
    final b = PdfGeometry.pdfToNorm(const Rect.fromLTWH(0, 0, 10, 10), 0, 0);
    expect(b.w, greaterThan(0));
    expect(b.h, greaterThan(0));
  });

  group('scanPageSize', () {
    test('a scan taller than A4 keeps its shape (no side strips)', () {
      // Indian stamp paper / US Legal: 8.5 × 14 in.
      final s = scanPageSize(1700, 2800);
      expect(s.width, pw);
      expect(s.height / s.width, closeTo(2800 / 1700, 1e-9));
    });

    test('a scan wider than A4 keeps its shape (no top/bottom strips)', () {
      final s = scanPageSize(1700, 2200); // US Letter
      expect(s.width, pw);
      expect(s.height / s.width, closeTo(2200 / 1700, 1e-9));
    });

    test('a scan within 2% of A4 goes on exact A4', () {
      expect(scanPageSize(1240, 1754), const Size(pw, ph));
      expect(scanPageSize(1240, 1720), const Size(pw, ph)); // 1.9% short
      expect(scanPageSize(1240, 1680), isNot(const Size(pw, ph))); // 4%
    });

    test('a landscape scan gets a landscape page', () {
      expect(scanPageSize(1754, 1240), const Size(ph, pw));
      final s = scanPageSize(3000, 1000);
      expect(s.height, pw);
      expect(s.width, closeTo(pw * 3, 1e-9));
    });

    test('a degenerate image falls back to A4', () {
      expect(scanPageSize(0, 100), const Size(pw, ph));
    });
  });
}
