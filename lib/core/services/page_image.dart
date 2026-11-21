import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// How page photos go into an exported PDF.
class PageImageQuality {
  const PageImageQuality(this.dpi, this.jpegQuality);

  /// Pixels per inch at the printed page size.
  final int dpi;
  final int jpegQuality;

  /// Every export: sharp to read and to print (an A4 page is about
  /// 1654 × 2339 px). A phone photo has far more pixels than that.
  static const standard = PageImageQuality(200, 85);

  /// Send → "Smaller file", for email and upload size limits.
  static const smaller = PageImageQuality(150, 65);
}

/// The bytes a page photo goes into a PDF as: the Review [filter] applied,
/// no larger than it needs to be to fill a [pageW] × [pageH] point page at
/// [quality]'s resolution, and saved as JPEG. When nothing would change, or the result would be bigger,
/// [raw] comes back as it was; so does anything that can't be decoded.
///
/// Pure Dart, for the export isolates.
Uint8List pageImageForPdf(
  Uint8List raw, {
  required String filter,
  required double pageW,
  required double pageH,
  PageImageQuality quality = PageImageQuality.standard,
}) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return raw;
    }
    // The photo is drawn to fit the page (contain), so its size on the page
    // is set by whichever side fills first.
    final maxW = pageW / 72 * quality.dpi;
    final maxH = pageH / 72 * quality.dpi;
    final scale = math.min(maxW / decoded.width, maxH / decoded.height);
    final shrink = scale < 1;
    final filtered = filter == 'enhanced' || filter == 'bw';
    final recompress = quality != PageImageQuality.standard;
    if (!shrink && !filtered && !recompress) return raw;

    var out = shrink
        ? img.copyResize(
            decoded,
            width: math.max(1, (decoded.width * scale).round()),
            height: math.max(1, (decoded.height * scale).round()),
            interpolation: img.Interpolation.average,
          )
        : decoded;
    switch (filter) {
      case 'bw':
        // Kept as three equal channels: this JPEG encoder writes a
        // one-channel image with empty colour planes, which decodes red.
        out = img.grayscale(out);
      case 'enhanced':
        // Mild contrast/brightness lift — mirrors Review's on-screen filter.
        out = img.adjustColor(out, contrast: 1.2, brightness: 1.02);
    }
    final jpeg = img.encodeJpg(
      out,
      quality: quality.jpegQuality,
      chroma: img.JpegChroma.yuv420,
    );
    // A filter must show even if the file doesn't shrink.
    return filtered || jpeg.length < raw.length ? jpeg : raw;
  } catch (_) {
    return raw;
  }
}
