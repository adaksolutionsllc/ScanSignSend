import 'dart:ui' show Rect;

import '../models/field_model.dart';

/// Coordinate transforms between our normalised field boxes and PDF geometry.
///
/// Our [BoundingBox] is normalised `[0,1]`, origin **top-left**, relative to a
/// page's rendered rect. Syncfusion exposes both `PdfPage.size` and
/// `PdfField.bounds` in **PDF points** with a **top-left origin** (it hides the
/// PDF spec's native bottom-left origin), so the mapping is a straight scale by
/// the page's point dimensions — no Y-flip at this layer.
///
/// IMPORTANT: the reference frame differs by source:
///   - imported PDF page → use that page's own point size (`page.size`).
///   - synthesised scan page → use the A4 point size we render onto.
class PdfGeometry {
  const PdfGeometry._();

  /// Normalised box → a rect in PDF points for a page of [pageWidthPts] ×
  /// [pageHeightPts].
  static Rect normToPdf(
    BoundingBox b,
    double pageWidthPts,
    double pageHeightPts,
  ) =>
      Rect.fromLTWH(
        b.x * pageWidthPts,
        b.y * pageHeightPts,
        b.w * pageWidthPts,
        b.h * pageHeightPts,
      );

  /// A rect in PDF points → normalised box. Values are clamped to `[0,1]`
  /// (width/height kept strictly positive) so a malformed source widget can
  /// never produce an out-of-range or inverted box.
  static BoundingBox pdfToNorm(
    Rect r,
    double pageWidthPts,
    double pageHeightPts,
  ) {
    if (pageWidthPts <= 0 || pageHeightPts <= 0) {
      return const BoundingBox(x: 0, y: 0, w: 0.001, h: 0.001);
    }
    return BoundingBox(
      x: (r.left / pageWidthPts).clamp(0.0, 1.0),
      y: (r.top / pageHeightPts).clamp(0.0, 1.0),
      w: (r.width / pageWidthPts).clamp(0.001, 1.0),
      h: (r.height / pageHeightPts).clamp(0.001, 1.0),
    );
  }
}
