// The Clean page filter (F4): a page with a shadow across it comes out with
// even, white paper, and the text is still dark.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/services/clean_filter.dart';
import 'package:scan_sign_send/core/services/page_image.dart';

/// Grey paper with lines of dark text, and a shadow over the left half that
/// fades out to the right, as a hand or a phone casts.
img.Image shadowedPage({int w = 900, int h = 1200}) {
  final page = img.Image(width: w, height: h);
  img.fill(page, color: img.ColorRgb8(205, 200, 190));
  for (var y = 120; y < h - 120; y += 60) {
    img.fillRect(
      page,
      x1: 80,
      y1: y,
      x2: w - 80,
      y2: y + 8,
      color: img.ColorRgb8(40, 40, 50),
    );
  }
  for (final px in page) {
    final shade = (0.45 + 0.55 * (px.x / (w * 0.6))).clamp(0.45, 1.0);
    px
      ..r = px.r * shade
      ..g = px.g * shade
      ..b = px.b * shade;
  }
  return page;
}

double _lum(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

void main() {
  test('Clean evens out a shadow and whitens the paper', () {
    final src = shadowedPage();
    final out = cleanPage(src);
    expect(out.width, src.width);
    expect(out.height, src.height);

    // Paper between the lines, in the shadow and in the light.
    final inShadow = _lum(out.getPixel(40, 150));
    final inLight = _lum(out.getPixel(860, 150));
    final before = _lum(src.getPixel(860, 150)) - _lum(src.getPixel(40, 150));
    expect(before, greaterThan(80), reason: 'the test page has a shadow');
    expect(inShadow, greaterThan(240));
    expect(inLight, greaterThan(240));

    // Text stays dark in both halves.
    expect(_lum(out.getPixel(100, 124)), lessThan(90));
    expect(_lum(out.getPixel(800, 124)), lessThan(90));

    final dir = Platform.environment['CLEAN_FILTER_OUT'];
    if (dir != null) {
      File('$dir/before.png').writeAsBytesSync(img.encodePng(src));
      File('$dir/after.png').writeAsBytesSync(img.encodePng(out));
    }
  });

  test('a preview and the full-size page look the same', () {
    final full = cleanPage(shadowedPage());
    final small = cleanPage(shadowedPage(w: 300, h: 400));
    for (final (x, y) in [(0.05, 0.12), (0.95, 0.12), (0.5, 0.6)]) {
      final a = _lum(full.getPixel((x * 900).round(), (y * 1200).round()));
      final b = _lum(small.getPixel((x * 300).round(), (y * 400).round()));
      expect((a - b).abs(), lessThan(25), reason: '($x, $y)');
    }
  });

  test('every export applies Clean to the page photo', () {
    final raw = img.encodeJpg(shadowedPage(), quality: 95);
    final out = img.decodeJpg(
      pageImageForPdf(raw, filter: 'clean', pageW: 595, pageH: 842),
    )!;
    // Paper in the shadow comes out white; with no filter it stays grey.
    expect(_lum(out.getPixel(40, 150)), greaterThan(235));
    final plain = img.decodeJpg(
      pageImageForPdf(raw, filter: 'original', pageW: 595, pageH: 842),
    )!;
    expect(_lum(plain.getPixel(40, 150)), lessThan(120));
  });

  test('a tiny image comes back as it was', () {
    final one = img.Image(width: 1, height: 1);
    expect(identical(cleanPage(one), one), isTrue);
  });
}
