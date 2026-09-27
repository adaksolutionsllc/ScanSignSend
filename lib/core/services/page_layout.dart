import 'dart:math' as math;
import 'dart:ui' show Rect;

/// A page's text and ruled lines, normalised to the page (0..1, origin
/// top-left) whatever it came from — a PDF's own text layer or OCR of a scan.
/// Field detection works only on this, so one set of rules serves both.
class PageLayout {
  const PageLayout({
    required this.lines,
    required this.rules,
    required this.aspect,
  });

  final List<LayoutLine> lines;

  /// Horizontal lines drawn on the page (solid or dotted) that aren't text.
  final List<Rect> rules;

  /// Page width / height.
  final double aspect;

  static const empty = PageLayout(lines: [], rules: [], aspect: 0.707);

  /// The body text size as a fraction of page height: the size most of the
  /// page's characters are set in (so a big title or small footnote doesn't
  /// skew it). Null when the page has no text.
  double? get bodyTextSize {
    final sizes = <double, int>{};
    for (final l in lines) {
      final chars = l.text.replaceAll(RegExp(r'[\s_.…]'), '').length;
      if (chars == 0 || l.fontSize <= 0) continue;
      // Bucket to 0.01% of page height (≈0.08pt on a letter page) so 11.5pt
      // and 11.49pt count together without blurring 11.5 into 12.
      final key = (l.fontSize * 10000).roundToDouble() / 10000;
      sizes[key] = (sizes[key] ?? 0) + chars;
    }
    if (sizes.isEmpty) return null;
    return sizes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class LayoutLine {
  const LayoutLine({
    required this.text,
    required this.box,
    required this.words,
    required this.fontSize,
    this.blanks = const [],
  });

  final String text;
  final Rect box;
  final List<LayoutWord> words;

  /// Font size as a fraction of page height; 0 when unknown.
  final double fontSize;

  /// Fill-in blanks written as text inside this line: runs of underscores or
  /// dot leaders, e.g. the `______` in "aged ______ years".
  final List<Rect> blanks;

  /// Text of this line with its blank runs removed.
  String get textWithoutBlanks =>
      text.replaceAll(blankRun, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Underscores (3+) or dot leaders (5+ dots / ellipses).
  static final blankRun = RegExp(r'_{3,}|(?:\.\s?|…){5,}');
}

class LayoutWord {
  const LayoutWord(this.text, this.box);
  final String text;
  final Rect box;
}

/// Horizontal extents of blank runs within [text], given each character's
/// box (PDF glyphs) — or, when only the word box is known (OCR), spread the
/// word's width evenly over its characters.
List<Rect> blankRunsIn(String text, Rect box, [List<Rect>? charBoxes]) {
  final out = <Rect>[];
  for (final m in LayoutLine.blankRun.allMatches(text)) {
    final Rect r;
    if (charBoxes != null && charBoxes.length == text.length) {
      final first = charBoxes[m.start];
      final last = charBoxes[m.end - 1];
      r = Rect.fromLTRB(first.left, box.top, last.right, box.bottom);
    } else {
      final per = box.width / math.max(text.length, 1);
      r = Rect.fromLTRB(
        box.left + per * m.start,
        box.top,
        box.left + per * m.end,
        box.bottom,
      );
    }
    if (r.width > 0) out.add(r);
  }
  return out;
}
