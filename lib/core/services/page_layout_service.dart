import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../utils/path_resolver.dart';
import 'ocr_service.dart';
import 'page_layout.dart';
import 'page_raster_service.dart';

final pageLayoutServiceProvider = Provider<PageLayoutService>(
  (ref) => PageLayoutService(
    ref.watch(ocrServiceProvider),
    ref.watch(pageRasterServiceProvider),
  ),
);

/// Builds a [PageLayout] for a stored page.
///
/// - A PDF page with a text layer is read from the PDF itself: exact words,
///   glyph positions and font sizes, far more reliable than OCR of a render.
/// - A scan (or an image-only PDF page) is OCR'd.
/// - Either way the rendered page is scanned for drawn lines (solid or
///   dotted), which is how most printed forms mark a blank.
class PageLayoutService {
  PageLayoutService(this._ocr, this._raster);
  final OcrService _ocr;
  final PageRasterService _raster;

  /// Returns the layout and the OCR/PDF full text (for search).
  Future<(PageLayout, String)> analyse(String storedPath) async {
    final imagePath = await _raster.imageFor(storedPath);

    List<LayoutLine>? lines;
    double? aspect;
    final resolved = PathResolver.resolve(storedPath);
    final hash = resolved.indexOf('#page=');
    if (hash >= 0) {
      final pdf = resolved.substring(0, hash);
      final n = int.tryParse(resolved.substring(hash + 6)) ?? 0;
      final fromPdf = await compute(pdfTextLayout, (pdf, n));
      if (fromPdf != null && fromPdf.$1.isNotEmpty) {
        lines = fromPdf.$1;
        aspect = fromPdf.$2;
      }
    }

    if (lines == null) {
      final ocr = await _ocr.processPage(imagePath);
      lines = ocrLayout(ocr);
      aspect = ocr.imageWidth / math.max(ocr.imageHeight, 1);
    }

    final rules = await compute(detectRules, imagePath);
    final layout = PageLayout(
      lines: lines,
      rules: rules,
      aspect: aspect ?? 0.707,
    );
    return (layout, lines.map((l) => l.text).join('\n'));
  }
}

/// compute() entry: the text layer of page `args.$2` of the PDF at `args.$1`,
/// with the page's aspect ratio. Null when the file can't be read.
(List<LayoutLine>, double)? pdfTextLayout((String, int) args) {
  final (path, pageIndex) = args;
  PdfDocument? doc;
  try {
    doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    if (pageIndex < 0 || pageIndex >= doc.pages.count) return null;
    final size = doc.pages[pageIndex].size;
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return null;
    Rect norm(Rect r) =>
        Rect.fromLTRB(r.left / w, r.top / h, r.right / w, r.bottom / h);

    final out = <LayoutLine>[];
    for (final line in PdfTextExtractor(
      doc,
    ).extractTextLines(startPageIndex: pageIndex, endPageIndex: pageIndex)) {
      final words = <LayoutWord>[];
      final blanks = <Rect>[];
      for (final word in line.wordCollection) {
        // Syncfusion reports each space as a "word" of its own; keeping them
        // would hide every gap between real words.
        if (word.text.trim().isEmpty) continue;
        final box = norm(word.bounds);
        words.add(LayoutWord(word.text, box));
        final glyphs = word.glyphs;
        blanks.addAll(
          blankRunsIn(
            word.text,
            box,
            glyphs.length == word.text.length
                ? [for (final g in glyphs) norm(g.bounds)]
                : null,
          ),
        );
      }
      out.add(
        LayoutLine(
          text: line.text,
          box: norm(line.bounds),
          words: words,
          fontSize: line.fontSize / h,
          blanks: blanks,
        ),
      );
    }
    return (out, w / h);
  } catch (_) {
    return null;
  } finally {
    doc?.dispose();
  }
}

/// OCR result → layout. The OCR line box is a little taller than the font's
/// em (it spans ascenders to descenders), hence the 0.9.
List<LayoutLine> ocrLayout(OcrResult ocr) {
  final w = ocr.imageWidth.toDouble(), h = ocr.imageHeight.toDouble();
  if (w <= 1 || h <= 1) return const [];
  Rect norm(Rect r) =>
      Rect.fromLTRB(r.left / w, r.top / h, r.right / w, r.bottom / h);
  return [
    for (final block in ocr.blocks)
      for (final line in block.lines)
        () {
          final words = [
            for (final e in line.elements)
              LayoutWord(e.text, norm(e.boundingBox)),
          ];
          return LayoutLine(
            text: line.text,
            box: norm(line.boundingBox),
            words: words,
            fontSize: line.boundingBox.height * 0.9 / h,
            blanks: [for (final wd in words) ...blankRunsIn(wd.text, wd.box)],
          );
        }(),
  ];
}

/// compute() entry: horizontal lines drawn on the page image at [path] —
/// solid rules and dotted/dashed leaders — normalised to the page.
///
/// A candidate row segment counts as a rule only if it is thin and has blank
/// paper just above and below it. That is what separates a fill-in line from
/// a row of text (letters are tall) and from underlined text (the letters sit
/// right on top of the line). Segments that meet a vertical stroke at either
/// end are box or table edges, not blanks, and are dropped.
List<Rect> detectRules(String path) {
  final Uint8List bytes;
  try {
    bytes = File(path).readAsBytesSync();
  } catch (_) {
    return const [];
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const [];
  const targetW = 1000;
  final src = decoded.width > targetW
      ? img.copyResize(decoded, width: targetW)
      : decoded;
  final w = src.width, h = src.height;
  if (w < 50 || h < 50) return const [];

  // Luminance, then a threshold relative to the paper's brightness so grey
  // scans and bright PDF renders are treated alike.
  final rgb = src
      .convert(format: img.Format.uint8, numChannels: 3)
      .getBytes(order: img.ChannelOrder.rgb);
  final lum = Uint8List(w * h);
  final hist = List<int>.filled(256, 0);
  for (var i = 0; i < w * h; i++) {
    final l =
        ((299 * rgb[i * 3] + 587 * rgb[i * 3 + 1] + 114 * rgb[i * 3 + 2]) ~/
                1000)
            .clamp(0, 255);
    lum[i] = l;
    hist[l]++;
  }
  var acc = 0, paper = 255;
  for (var v = 255; v >= 0; v--) {
    acc += hist[v];
    if (acc >= w * h * 0.5) {
      paper = v;
      break;
    }
  }
  final threshold = (paper * 0.62).round();
  bool dark(int x, int y) => lum[y * w + x] < threshold;

  double coverage(int y, int x0, int x1) {
    if (y < 0 || y >= h) return 0;
    var n = 0;
    for (var x = x0; x < x1; x++) {
      if (dark(x, y)) n++;
    }
    return n / math.max(x1 - x0, 1);
  }

  final minLen = (w * 0.04).round();
  const maxGap = 7; // dotted leaders: dots a few px apart at this scale
  final found = <Rect>[];

  for (var y = 1; y < h - 1; y++) {
    var x = 0;
    while (x < w) {
      if (!dark(x, y)) {
        x++;
        continue;
      }
      final start = x;
      var last = x, darkCount = 0;
      while (x < w && x - last <= maxGap) {
        if (dark(x, y)) {
          last = x;
          darkCount++;
        }
        x++;
      }
      final end = last + 1;
      final len = end - start;
      if (len < minLen || len > w * 0.9) continue;
      final cov = darkCount / len;
      if (cov < 0.3) continue;

      // Thickness: neighbouring rows that carry the same stroke.
      var top = y, bottom = y;
      while (top > 0 &&
          coverage(top - 1, start, end) > cov * 0.5 &&
          y - top < 6) {
        top--;
      }
      while (bottom < h - 1 &&
          coverage(bottom + 1, start, end) > cov * 0.5 &&
          bottom - y < 6) {
        bottom++;
      }
      if (bottom - top > 4) continue; // a block of ink, not a line
      // Clear paper just above and below — rejects text rows and underlines.
      final above = coverage(top - 3, start, end);
      final below = coverage(bottom + 3, start, end);
      if (above > 0.08 || below > 0.08) continue;
      // Box / table edge: a vertical stroke at either end.
      // A box's top edge has its side stroke only below it, a bottom edge
      // only above, so look each way separately.
      bool strokeFrom(int cx, int y0, int dir) {
        var run = 0;
        for (var i = 1; i <= 12; i++) {
          final yy = y0 + dir * i;
          if (yy < 0 || yy >= h) break;
          var hit = false;
          for (
            var xx = math.max(0, cx - 1);
            xx <= math.min(w - 1, cx + 1);
            xx++
          ) {
            if (dark(xx, yy)) {
              hit = true;
              break;
            }
          }
          if (!hit) break;
          run++;
        }
        return run >= 8;
      }

      bool verticalAt(int cx) =>
          strokeFrom(cx, top, -1) || strokeFrom(cx, bottom, 1);

      if (verticalAt(start) || verticalAt(end - 1)) continue;

      final r = Rect.fromLTRB(start / w, top / h, end / w, (bottom + 1) / h);
      // The same stroke is met again on its other rows — keep one.
      if (!found.any((f) => f.overlaps(r.inflate(1 / h)))) found.add(r);
    }
  }
  return found;
}
