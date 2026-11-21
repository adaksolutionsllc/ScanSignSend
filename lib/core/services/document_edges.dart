import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The four corners of a document in a photo, each as a fraction of the
/// image's width and height (0–1, origin top-left).
class EdgeQuad {
  const EdgeQuad(this.tl, this.tr, this.br, this.bl);

  final math.Point<double> tl, tr, br, bl;

  /// The whole image: nothing to crop.
  static const full = EdgeQuad(
    math.Point(0, 0),
    math.Point(1, 0),
    math.Point(1, 1),
    math.Point(0, 1),
  );

  List<math.Point<double>> get points => [tl, tr, br, bl];

  /// [x0, y0, … x3, y3] in tl, tr, br, bl order — the platform channel form.
  List<double> toList() => [
    for (final p in points) ...[p.x, p.y],
  ];

  static EdgeQuad? fromList(List<dynamic>? v) {
    if (v == null || v.length != 8) return null;
    final d = [for (final e in v) (e as num).toDouble().clamp(0.0, 1.0)];
    return EdgeQuad(
      math.Point(d[0], d[1]),
      math.Point(d[2], d[3]),
      math.Point(d[4], d[5]),
      math.Point(d[6], d[7]),
    );
  }

  EdgeQuad withCorner(int i, math.Point<double> p) {
    final c = points..[i] = p;
    return EdgeQuad(c[0], c[1], c[2], c[3]);
  }

  /// Area as a fraction of the image (shoelace formula).
  double get area {
    final c = points;
    var s = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4];
      s += a.x * b.y - b.x * a.y;
    }
    return s.abs() / 2;
  }

  /// True when the corners turn the same way all round: a usable crop.
  bool get isConvex {
    final c = points;
    double? sign;
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4], d = c[(i + 2) % 4];
      final cross = (b.x - a.x) * (d.y - b.y) - (b.y - a.y) * (d.x - b.x);
      if (cross.abs() < 1e-9) return false;
      sign ??= cross.sign;
      if (cross.sign != sign) return false;
    }
    return true;
  }

  /// Whether cropping to this quad would change the page enough to be worth
  /// asking: the document must not already fill the image (every corner
  /// within [margin] of the image's own corner), and the quad must be a real
  /// document shape, not a sliver.
  bool get worthCropping {
    if (!isConvex || area < minArea) return false;
    final c = points;
    const corners = [
      math.Point(0.0, 0.0),
      math.Point(1.0, 0.0),
      math.Point(1.0, 1.0),
      math.Point(0.0, 1.0),
    ];
    for (var i = 0; i < 4; i++) {
      if (c[i].distanceTo(corners[i]) > margin) return true;
    }
    return false;
  }

  /// Corners closer than this to the image corners count as "already
  /// cropped".
  static const margin = 0.04;

  /// A document covering less than this share of the photo is more likely a
  /// misdetection (a label, a screen) than the page itself.
  static const minArea = 0.15;

  @override
  String toString() => 'EdgeQuad(${toList().map((v) => v.toStringAsFixed(3))})';
}

/// Finds a document (a sheet lighter than what it lies on) in [image] —
/// the Dart fallback for phones without Apple's Vision framework.
///
/// Works on a small grey copy: Otsu's threshold splits paper from background,
/// the largest bright region is taken as the page, and its corners are the
/// region's extreme points along the two diagonals. Returns null when nothing
/// page-shaped is found; the user can still drag the corners.
EdgeQuad? detectDocumentEdges(img.Image image) {
  const side = 256;
  final small = img.copyResize(
    image,
    width: image.width >= image.height ? side : null,
    height: image.height > image.width ? side : null,
    interpolation: img.Interpolation.average,
  );
  final grey = img.gaussianBlur(img.grayscale(small), radius: 2);
  final w = grey.width, h = grey.height;
  if (w < 16 || h < 16) return null;

  final lum = Uint8List(w * h);
  final hist = List<int>.filled(256, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = grey.getPixel(x, y).r.toInt().clamp(0, 255);
      lum[y * w + x] = v;
      hist[v]++;
    }
  }
  final t = _otsu(hist, w * h);
  // A flat image (one tone) has no edge to find.
  if (t == null) return null;

  final mask = Uint8List(w * h);
  for (var i = 0; i < mask.length; i++) {
    if (lum[i] > t) mask[i] = 1;
  }
  final region = _largestRegion(mask, w, h);
  if (region == null || region.length < w * h * EdgeQuad.minArea) return null;

  // Extreme points along the diagonals: tl minimises x+y, br maximises it;
  // tr maximises x−y, bl minimises it.
  var tl = region.first, tr = tl, br = tl, bl = tl;
  int sx(int i) => i % w;
  int sy(int i) => i ~/ w;
  for (final i in region) {
    final x = sx(i), y = sy(i);
    if (x + y < sx(tl) + sy(tl)) tl = i;
    if (x + y > sx(br) + sy(br)) br = i;
    if (x - y > sx(tr) - sy(tr)) tr = i;
    if (x - y < sx(bl) - sy(bl)) bl = i;
  }
  math.Point<double> norm(int i) =>
      math.Point((sx(i) + 0.5) / w, (sy(i) + 0.5) / h);
  final quad = EdgeQuad(norm(tl), norm(tr), norm(br), norm(bl));
  if (!quad.isConvex) return null;

  // Page-shaped: the region should about fill its own quad. A blob (a hand,
  // a lamp, a white mug) fills much less, and a round one spills far outside
  // the quad its diagonals give.
  final fill = region.length / (w * h) / quad.area;
  if (fill < 0.85 || fill > 1.12) return null;
  return quad;
}

/// Otsu's method: the grey level that best splits [hist] into two classes.
/// Null when the image is (almost) one tone.
int? _otsu(List<int> hist, int total) {
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0.0, wB = 0, best = -1.0;
  int? threshold;
  for (var i = 0; i < 256; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += i * hist[i];
    final mB = sumB / wB, mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = i;
    }
  }
  if (threshold == null) return null;
  // Too little contrast between the classes to be paper on a background.
  var lo = 0.0, hi = 0.0, nLo = 0, nHi = 0;
  for (var i = 0; i < 256; i++) {
    if (i <= threshold) {
      lo += i * hist[i];
      nLo += hist[i];
    } else {
      hi += i * hist[i];
      nHi += hist[i];
    }
  }
  if (nLo == 0 || nHi == 0 || hi / nHi - lo / nLo < 30) return null;
  return threshold;
}

/// Indices of the largest 4-connected run of 1s in [mask].
List<int>? _largestRegion(Uint8List mask, int w, int h) {
  final seen = Uint8List(mask.length);
  List<int>? best;
  final stack = <int>[];
  for (var start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || seen[start] == 1) continue;
    final region = <int>[];
    stack.add(start);
    seen[start] = 1;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      region.add(i);
      final x = i % w;
      for (final n in [
        if (x > 0) i - 1,
        if (x < w - 1) i + 1,
        if (i >= w) i - w,
        if (i < mask.length - w) i + w,
      ]) {
        if (mask[n] == 1 && seen[n] == 0) {
          seen[n] = 1;
          stack.add(n);
        }
      }
    }
    if (best == null || region.length > best.length) best = region;
  }
  return best;
}

/// Straightens the part of [src] inside [quad] into an upright rectangle,
/// sized from the quad's own edge lengths so text keeps its proportions.
img.Image cropToQuad(img.Image src, EdgeQuad quad) {
  math.Point<double> px(math.Point<double> p) =>
      math.Point(p.x * src.width, p.y * src.height);
  final tl = px(quad.tl), tr = px(quad.tr), br = px(quad.br), bl = px(quad.bl);
  final width = math.max(tl.distanceTo(tr), bl.distanceTo(br)).round();
  final height = math.max(tl.distanceTo(bl), tr.distanceTo(br)).round();
  final out = img.Image(
    width: math.max(width, 1),
    height: math.max(height, 1),
    numChannels: src.numChannels,
  );
  img.Point ip(math.Point<double> p) => img.Point(p.x, p.y);
  return img.copyRectify(
    src,
    topLeft: ip(tl),
    topRight: ip(tr),
    bottomLeft: ip(bl),
    bottomRight: ip(br),
    interpolation: img.Interpolation.linear,
    toImage: out,
  );
}
