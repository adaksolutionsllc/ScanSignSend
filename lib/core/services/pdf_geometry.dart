import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

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
  ) => Rect.fromLTWH(
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

/// Adds a page of [size] points with **no margins**.
///
/// Syncfusion gives every new page a 40pt margin on each side by default, and
/// its graphics origin and clip are the area inside that margin. Drawing a
/// full-page template onto such a page shifted everything 40pt right and down
/// and cut off the right-hand side of the text. Each page gets its own section
/// so pages of different sizes (an imported US Letter form, an A4 scan) keep
/// their own size in one document.
PdfPage addEdgeToEdgePage(PdfDocument doc, Size size) {
  final section = doc.sections!.add();
  section.pageSettings
    ..size = size
    ..margins.all = 0;
  return section.pages.add();
}

/// The size an output page should have for the stored page [path]: an
/// imported PDF page keeps its own size; a scan goes on A4.
Size outputPageSize(String path, PdfDocument? Function(String) openSource) {
  final hash = path.indexOf('#page=');
  if (hash >= 0) {
    final src = openSource(path.substring(0, hash));
    final n = int.tryParse(path.substring(hash + 6)) ?? 0;
    if (src != null && n >= 0 && n < src.pages.count) {
      final s = src.pages[n].size;
      if (s.width > 0 && s.height > 0) return s;
    }
  }
  return PdfPageSize.a4;
}
