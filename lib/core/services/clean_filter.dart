import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The "Clean" page filter: removes shadows and uneven light, and turns the
/// paper white, keeping the ink's colour.
///
/// Each pixel is divided by the paper's own brightness at that spot. The
/// paper is found by shrinking the photo, taking the brightest value around
/// each point (which wipes out the text) and blurring it. A shadow darkens
/// paper and ink alike, so dividing it out leaves even, white paper.
///
/// Pure Dart, for isolates. The blur and the neighbourhood scale with the
/// image, so a small preview looks like the full-size export.
img.Image cleanPage(img.Image src) {
  final w = src.width, h = src.height;
  if (w < 2 || h < 2) return src;
  final rgb = src.getBytes(order: img.ChannelOrder.rgb);

  // The paper, at about 1/8 size.
  final sw = math.max(2, w ~/ 8), sh = math.max(2, h ~/ 8);
  var small = img.copyResize(
    img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rgb.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    ),
    width: sw,
    height: sh,
    interpolation: img.Interpolation.average,
  );
  // Wider than a line of text at this size, so no ink survives.
  final reach = math.max(2, math.max(sw, sh) ~/ 40);
  final paper = _maxFilter(
    small.getBytes(order: img.ChannelOrder.rgb),
    sw,
    sh,
    reach,
  );
  small = img.gaussianBlur(
    img.Image.fromBytes(
      width: sw,
      height: sh,
      bytes: paper.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    ),
    radius: reach * 2,
  );
  final bg = img
      .copyResize(
        small,
        width: w,
        height: h,
        interpolation: img.Interpolation.linear,
      )
      .getBytes(order: img.ChannelOrder.rgb);

  // Divide out the paper, then set the levels: near-white goes white, and
  // faint ink is darkened so it still reads.
  const black = 0.12 * 255, white = 0.90 * 255;
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = ((v - black) / (white - black) * 255).round().clamp(0, 255);
  }
  final out = Uint8List(rgb.length);
  for (var i = 0; i < rgb.length; i++) {
    final paper = math.max(bg[i], 16);
    final v = math.min(255, rgb[i] * 255 ~/ paper);
    out[i] = lut[v];
  }
  return img.Image.fromBytes(
    width: w,
    height: h,
    bytes: out.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
}

/// The largest value of each channel within [r] pixels (a square), in two
/// passes: across, then down.
Uint8List _maxFilter(Uint8List rgb, int w, int h, int r) {
  final across = Uint8List(rgb.length);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
      for (var c = 0; c < 3; c++) {
        var m = 0;
        for (var k = x0; k <= x1; k++) {
          final v = rgb[(y * w + k) * 3 + c];
          if (v > m) m = v;
        }
        across[(y * w + x) * 3 + c] = m;
      }
    }
  }
  final out = Uint8List(rgb.length);
  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 3; c++) {
        var m = 0;
        for (var k = y0; k <= y1; k++) {
          final v = across[(k * w + x) * 3 + c];
          if (v > m) m = v;
        }
        out[(y * w + x) * 3 + c] = m;
      }
    }
  }
  return out;
}
