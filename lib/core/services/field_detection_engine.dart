import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_model.dart';
import 'field_hints.dart';
import 'page_layout.dart';

final fieldDetectionEngineProvider = Provider<FieldDetectionEngine>(
  (ref) => FieldDetectionEngine(),
);

class DetectedField {
  final FieldType type;
  final BoundingBox bbox; // normalised 0..1
  final String label;

  /// A date that belongs to a signature: filled with today's date when the
  /// user signs.
  final bool autoToday;

  const DetectedField({
    required this.type,
    required this.bbox,
    required this.label,
    this.autoToday = false,
  });
}

class DetectionResult {
  const DetectionResult(this.fields, this.textSize);
  final List<DetectedField> fields;

  /// The page's body text size, as a fraction of page height (null if the
  /// page has no text). New fields and filled-in text are sized from this.
  final double? textSize;
}

/// Finds fill-in places on a page from its [PageLayout].
///
///   1. **Blanks** — underscore runs / dot leaders inside the text, and lines
///      drawn on the page, become fields covering exactly the blank. Most are
///      text; the words just before a blank decide otherwise ("born on ___"
///      is a date, "Signature: ___" a signature).
///   2. **Signatures** — signature words next to a blank, a blank line
///      directly above a signer's name ("DEPONENT (NAME)", "(Name)", an
///      all-caps name), or a gap of white space above such a name.
///   3. **Dates for signatures** — a signature nearly always needs today's
///      date. An existing date blank near the signature is marked for it;
///      otherwise one is added beside or below the signature.
///   4. **Checkboxes** — explicit box glyphs (☐ □ ▢) or "[ ]".
///
/// Every field is sized from the page's own text size, so a text field is one
/// line of the document's body text tall.
class FieldDetectionEngine {
  static final _sigWords = RegExp(
    r'\b(signature|signed|sign here|signatory|deponent|declarant|applicant|'
    r'witness|authori[sz]ed by|firma|assinatura|हस्ताक्षर|கையொப்பம்|సంతకం)\b',
    caseSensitive: false,
    unicode: true,
  );
  static final _initialWords = RegExp(
    r'\b(initials?|paraphe|iniciales|rubrica)\b',
    caseSensitive: false,
  );
  static final _dateWords = RegExp(
    r'(\bdate[d]?\b|\bd\.?\s?o\.?\s?b\.?|\bborn on\b|\bmarried on\b|'
    r'\bissued on\b|\bdated\b|\bexpir\w*|\bfecha\b|\bdata\b|दिनांक|तारीख|'
    r'தேதி|తేదీ)',
    caseSensitive: false,
    unicode: true,
  );

  /// A signer line under a signature: a role word, or a bracketed name.
  static final _signerLine = RegExp(
    r'^\s*(\(.*\)|(deponent|declarant|applicant|witness|signature|'
    r'authori[sz]ed signatory|borrower|tenant|landlord|employee|employer|'
    r'guardian|parent|signed)\b.*)$',
    caseSensitive: false,
  );
  static final _checkboxGlyph = RegExp(r'^[☐□▢❏]$|^\[\s?\]$');

  static const _maxFieldsPerPage = 60;

  DetectionResult detect(
    PageLayout layout, {
    LearnedHints hints = LearnedHints.none,
  }) {
    // Fallback ≈ 11pt on a letter/A4 page.
    final textSize = layout.bodyTextSize ?? 0.0145;
    final lineH = textSize * 1.45;
    final sigH = textSize * 3.2;
    final lines = [...layout.lines]
      ..sort((a, b) => a.box.top.compareTo(b.box.top));

    final found = <_Candidate>[];

    // ── 1a. Blanks written as text (underscores / dot leaders) ─────────────
    for (final line in lines) {
      for (final blank in line.blanks) {
        found.add(
          _Candidate(
            rect: blank,
            line: line,
            left: _wordsBefore(line, blank),
            standalone: line.textWithoutBlanks.isEmpty,
          ),
        );
      }
    }

    // ── 1c. Unexplained white space between words ──────────────────────────
    // "aged        years" or "Name:          Age:" — a blank with no line
    // drawn. White space is mostly layout, so this is deliberately
    // skeptical: only on a page that is plainly a form (it has a real blank,
    // or several "Label:" prompts), and only where the gap reads as a blank:
    // the sentence carries on after it, or a "Label:" precedes it. A missed
    // blank costs one tap to add; a page of false fields costs many to clear.
    final formLike =
        found.isNotEmpty ||
        layout.rules.isNotEmpty ||
        _labelPrompts(lines) >= 3;
    for (final gap
        in formLike
            ? _wordGaps(lines, layout.aspect, textSize)
            : const <({Rect rect, LayoutLine line})>[]) {
      if (found.any(
        (c) =>
            _hOverlap(c.rect, gap.rect) > 0 &&
            (c.rect.center.dy - gap.rect.center.dy).abs() < lineH,
      )) {
        continue;
      }
      found.add(
        _Candidate(
          rect: gap.rect,
          line: gap.line,
          left: _wordsBefore(gap.line, gap.rect),
          standalone: false,
        ),
      );
    }

    // ── 1b. Drawn lines that aren't already a text blank or an underline ──
    for (final rule in layout.rules) {
      bool near(Rect r) =>
          r.left < rule.right &&
          r.right > rule.left &&
          (r.bottom - rule.top).abs() < lineH;
      if (found.any((c) => near(c.rect))) continue;
      // Text sitting right on the line is underlined text, not a blank.
      final onTop = layout.lines.any(
        (l) => l.words.any(
          (w) =>
              w.box.bottom <= rule.top + textSize * 0.3 &&
              w.box.bottom > rule.top - textSize * 0.8 &&
              _hOverlap(w.box, rule) > w.box.width * 0.5 &&
              !LayoutLine.blankRun.hasMatch(w.text),
        ),
      );
      if (onTop) continue;
      final line = _lineOnBaseline(lines, rule, textSize);
      found.add(
        _Candidate(
          rect: rule,
          line: line,
          left: line == null ? '' : _wordsBefore(line, rule),
          standalone:
              line == null ||
              !line.words.any(
                (w) => _hOverlap(w.box, rule) > 0 || w.box.left > rule.right,
              ),
        ),
      );
    }

    // ── Classify blanks ─────────────────────────────────────────────────────
    final fields = <_Field>[];
    for (final c in found) {
      final below = _lineBelow(lines, c.rect, lineH * 2.2);
      final above = _lineAbove(lines, c.rect, lineH * 2.2);
      final right = c.line == null ? '' : _wordsAfter(c.line!, c.rect);
      final context = '${c.left} $right';

      FieldType type;
      String label = _cleanLabel(c.left);
      if (_initialWords.hasMatch(context)) {
        type = FieldType.initials;
      } else if (_sigWords.hasMatch(c.left) ||
          (c.standalone &&
              ((below != null &&
                      (_sigWords.hasMatch(below.text) ||
                          _signerLine.hasMatch(below.text) ||
                          _looksLikeName(below.text))) ||
                  (above != null &&
                      _sigWords.hasMatch(above.text) &&
                      _cleanLabel(above.text).split(' ').length <= 4)))) {
        type = FieldType.signature;
        if (label.isEmpty) {
          label = _signerLabel(below?.text ?? above?.text ?? '');
        }
      } else if (_dateWords.hasMatch(_lastWords(c.left, 3))) {
        type = FieldType.date;
      } else {
        type = FieldType.text;
      }

      final minW = type == FieldType.signature ? 0.22 : 0.05;
      final w = math.max(c.rect.width, minW);
      final h = type == FieldType.signature ? sigH : lineH;
      // Sit on the blank: the field's bottom is the line/underscore.
      final bottom = c.rect.bottom;
      fields.add(_Field(type, _box(c.rect.left, bottom - h, w, h), label));
    }

    // ── 2. White space above a signer's name, with no line drawn ───────────
    // A bare name ("RAVI KUMAR") counts only on a page that talks about
    // signing; otherwise every heading after a paragraph break would do.
    final mentionsSigning = lines.any((l) => _sigWords.hasMatch(l.text));
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final text = l.text.trim();
      if (l.blanks.isNotEmpty || text.isEmpty) continue;
      final signer =
          _signerLine.hasMatch(text) ||
          (mentionsSigning && _looksLikeName(text) && l.box.top > 0.5);
      if (!signer) continue;
      final prevBottom = i == 0 ? 0.0 : lines[i - 1].box.bottom;
      final gap = l.box.top - prevBottom;
      if (gap < lineH * 2.4) continue;
      final h = math.min(sigH, gap - lineH * 0.4);
      final box = _box(
        l.box.left,
        l.box.top - h - textSize * 0.2,
        math.max(l.box.width, 0.25),
        h,
      );
      if (fields.any((f) => _overlaps(f.box, box))) continue;
      fields.add(_Field(FieldType.signature, box, _signerLabel(text)));
    }

    // ── 4. Checkbox glyphs ──────────────────────────────────────────────────
    for (final l in lines) {
      for (final w in l.words) {
        if (!_checkboxGlyph.hasMatch(w.text.trim())) continue;
        final side = w.box.height;
        fields.add(
          _Field(
            FieldType.checkbox,
            _box(w.box.left, w.box.top, side / layout.aspect, side),
            _cleanLabel(_wordsAfter(l, w.box)),
          ),
        );
      }
    }

    // ── 5. What this user's own edits have taught ───────────────────────────
    if (!hints.isEmpty) {
      // Their type for a phrase wins; detections they keep deleting go.
      for (final f in [...fields]) {
        final preferred = hints.preferredType(f.label);
        if (preferred != null && preferred != f.type) {
          f.type = preferred;
          if (f.type.isToggle || f.type.isInk) {
            f.box = _box(
              f.box.x,
              f.box.y +
                  f.box.h -
                  (f.type == FieldType.signature ? sigH : lineH),
              math.max(f.box.w, f.type == FieldType.signature ? 0.22 : 0.05),
              f.type == FieldType.signature ? sigH : lineH,
            );
          }
        }
        if (hints.suppressed(f.label, f.type)) fields.remove(f);
      }
      // Phrases after which they reliably add a field get one, even with no
      // line or gap on the page.
      for (final (phrase, type) in hints.learnedPlacements) {
        for (final spot in _afterPhrase(
          lines,
          phrase,
          layout.aspect,
          textSize,
        )) {
          final h = type == FieldType.signature ? sigH : lineH;
          final box = _box(
            spot.rect.left,
            spot.rect.bottom - h,
            math.max(spot.rect.width, 0.05),
            h,
          );
          if (fields.any((f) => _overlaps(f.box, box))) continue;
          if (lines.any(
            (l) => l.words.any(
              (w) => _overlapsRect(box, w.box) && w.box.left > spot.rect.left,
            ),
          )) {
            continue;
          }
          fields.add(_Field(type, box, spot.label));
        }
      }
    }

    // ── 3. Every signature gets a date ─────────────────────────────────────
    for (final sig
        in fields.where((f) => f.type == FieldType.signature).toList()) {
      final near = fields.where(
        (f) =>
            f.type == FieldType.date &&
            (f.box.y - sig.box.y).abs() < 0.14 &&
            (f.box.x < sig.box.x + sig.box.w + 0.4),
      );
      if (near.isNotEmpty) {
        for (final d in near) {
          d.autoToday = true;
        }
        continue;
      }
      final dateW = 0.2, dateH = lineH;
      final candidates = [
        // Beside the signature, on its bottom line.
        _box(
          sig.box.x + sig.box.w + 0.04,
          sig.box.y + sig.box.h - dateH,
          dateW,
          dateH,
        ),
        // Below it.
        _box(sig.box.x, sig.box.y + sig.box.h + lineH * 1.2, dateW, dateH),
      ];
      for (final box in candidates) {
        if (box.x + box.w > 0.97 || box.y + box.h > 0.97) continue;
        final hitsText = lines.any((l) => _overlapsRect(box, l.box));
        final hitsField = fields.any((f) => _overlaps(f.box, box));
        if (hitsText || hitsField) continue;
        fields.add(_Field(FieldType.date, box, '')..autoToday = true);
        break;
      }
    }

    // ── Tidy: drop duplicates, keeping the more specific type ──────────────
    const rank = {
      FieldType.signature: 0,
      FieldType.initials: 1,
      FieldType.date: 2,
      FieldType.checkbox: 3,
      FieldType.radio: 4,
      FieldType.text: 5,
    };
    fields.sort((a, b) => rank[a.type]!.compareTo(rank[b.type]!));
    final kept = <_Field>[];
    for (final f in fields) {
      if (kept.any((k) => _iou(k.box, f.box) > 0.3)) continue;
      kept.add(f);
    }
    kept.sort(
      (a, b) => (a.box.y - b.box.y).abs() > 0.005
          ? a.box.y.compareTo(b.box.y)
          : a.box.x.compareTo(b.box.x),
    );

    return DetectionResult([
      for (final f in kept.take(_maxFieldsPerPage))
        DetectedField(
          type: f.type,
          bbox: f.box,
          label: f.label,
          autoToday: f.autoToday,
        ),
    ], layout.bodyTextSize);
  }

  /// The label phrase just before [box] on its line — what a user-placed
  /// field is "after" — cleaned the same way as detected labels. Empty when
  /// nothing precedes it.
  static String phraseBefore(PageLayout layout, BoundingBox box) {
    final cy = box.y + box.h / 2;
    LayoutLine? best;
    var bestDist = double.infinity;
    for (final l in layout.lines) {
      final slack = math.max(l.box.height, 0.01);
      if (cy < l.box.top - slack || cy > l.box.bottom + slack) continue;
      final d = (l.box.center.dy - cy).abs();
      if (d < bestDist) {
        bestDist = d;
        best = l;
      }
    }
    if (best == null) return '';
    final before = best.words
        .where((w) => w.box.right <= box.x + 0.01)
        .map((w) => w.text)
        .join(' ')
        .replaceAll(LayoutLine.blankRun, ' ');
    return _cleanLabel(before);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Where [phrase] (already normalised) ends a run of words on a line, the
  /// space after it: up to the next word when there's a real gap, or out
  /// toward the margin when the phrase ends the line.
  static Iterable<({Rect rect, String label})> _afterPhrase(
    List<LayoutLine> lines,
    String phrase,
    double aspect,
    double textSize,
  ) sync* {
    final n = phrase.split(' ').length;
    final em = textSize > 0 ? textSize : 0.0145;
    final pad = em * 0.3 / aspect;
    for (final line in lines) {
      final words = [...line.words]
        ..sort((a, b) => a.box.left.compareTo(b.box.left));
      for (var j = n - 1; j < words.length; j++) {
        final run = words.sublist(j - n + 1, j + 1);
        if (normalizePhrase(run.map((w) => w.text).join(' ')) != phrase) {
          continue;
        }
        final end = words[j].box.right;
        final double right;
        if (j + 1 < words.length) {
          final next = words[j + 1].box.left;
          if ((next - end) * aspect < em * 1.2) continue; // no room to write
          right = next - pad;
        } else {
          right = (end + 0.35).clamp(0.0, 0.95).toDouble();
        }
        if (right - end < 0.04) continue;
        yield (
          rect: Rect.fromLTRB(end + pad, line.box.top, right, line.box.bottom),
          label: run
              .map((w) => w.text)
              .join(' ')
              .replaceAll(RegExp(r'[:.,;]+$'), ''),
        );
      }
    }
  }

  /// Short "Label:" prompts on the page ("Name:", "Date of birth:") — one
  /// to three words ending in a colon, not the tail of a sentence ("note the
  /// following:", "(Note:") or a URL ("http://").
  static int _labelPrompts(List<LayoutLine> lines) {
    var n = 0;
    for (final l in lines) {
      // Each segment is the words since the previous prompt on the line.
      for (final seg in l.textWithoutBlanks.split(RegExp(r'(?<=:)\s'))) {
        final t = seg.trim();
        if (_labelPrompt.hasMatch(t) && t.split(RegExp(r'\s+')).length <= 3) {
          n++;
        }
      }
    }
    return n;
  }

  static final _labelPrompt = RegExp(r'^[^a-z\s.,;!?()\[\]][^.;!?()\[\]:]*:$');

  static final _endsSentence = RegExp(r'[.!?;)\]"”’]$');
  static final _continues = RegExp(r'^[a-z0-9]');

  /// Blank spans between words (and after a trailing "Label:") on each line.
  /// Widths are compared in page-height units: a gap of [x] page widths is
  /// `x * aspect` page heights, the unit [textSize] is in.
  static Iterable<({Rect rect, LayoutLine line})> _wordGaps(
    List<LayoutLine> lines,
    double aspect,
    double textSize,
  ) sync* {
    final em = textSize > 0 ? textSize : 0.0145;
    final pad = em * 0.3 / aspect; // breathing room each side, in widths
    double fontOf(LayoutLine l) => l.fontSize > 0 ? l.fontSize : em;
    List<LayoutWord> sorted(LayoutLine l) =>
        [...l.words]..sort((a, b) => a.box.left.compareTo(b.box.left));
    List<double> gapsOf(List<LayoutWord> w) => [
      for (var i = 0; i + 1 < w.length; i++)
        (w[i + 1].box.left - w[i].box.right) * aspect,
    ];

    // The page's ordinary word spacing, in font sizes. Word boxes from OCR
    // (or a PDF text layer) can be narrower than the ink, making every space
    // look wide; a blank has to stand out against the spacing actually
    // measured, not against a fixed width.
    final pageRel = _median([
      for (final l in lines)
        for (final g in gapsOf(sorted(l))) g / fontOf(l),
    ]);

    for (final line in lines) {
      final words = sorted(line);
      final fs = fontOf(line);
      final gaps = gapsOf(words);
      for (var i = 0; i + 1 < words.length; i++) {
        final a = words[i], b = words[i + 1];
        final gapH = gaps[i];
        final others = [...gaps]..removeAt(i);
        final typical = others.length >= 2
            ? _median(others)
            : (pageRel ?? 0.3) * fs;
        if (gapH < math.max(fs * 3, (typical ?? 0) * 4)) continue;
        final prev = a.text.trim(), next = b.text.trim();
        if (LayoutLine.blankRun.hasMatch(prev) ||
            LayoutLine.blankRun.hasMatch(next)) {
          continue;
        }
        final labelled = prev.endsWith(':');
        final midSentence =
            _continues.hasMatch(next) && !_endsSentence.hasMatch(prev);
        if (!labelled && !midSentence) continue;
        yield (
          rect: Rect.fromLTRB(
            a.box.right + pad,
            line.box.top,
            b.box.left - pad,
            line.box.bottom,
          ),
          line: line,
        );
      }
      // A short "Label:" line with nothing after it: the answer goes there.
      // Short only — "…declare on oath that:" ends a sentence, not a label.
      if (words.isNotEmpty &&
          words.length <= 4 &&
          words.last.text.trim().endsWith(':')) {
        final last = words.last.box;
        final right = (last.right + 0.4).clamp(0.0, 0.92);
        if (right - last.right > 0.12) {
          yield (
            rect: Rect.fromLTRB(
              last.right + pad,
              line.box.top,
              right,
              line.box.bottom,
            ),
            line: line,
          );
        }
      }
    }
  }

  static double? _median(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static BoundingBox _box(double x, double y, double w, double h) {
    final cw = w.clamp(0.001, 1.0).toDouble();
    final ch = h.clamp(0.001, 1.0).toDouble();
    return BoundingBox(
      x: x.clamp(0.0, 1.0 - cw).toDouble(),
      y: y.clamp(0.0, 1.0 - ch).toDouble(),
      w: cw,
      h: ch,
    );
  }

  static double _hOverlap(Rect a, Rect b) =>
      math.max(0, math.min(a.right, b.right) - math.max(a.left, b.left));

  static bool _overlapsRect(BoundingBox b, Rect r) =>
      b.x < r.right &&
      b.x + b.w > r.left &&
      b.y < r.bottom &&
      b.y + b.h > r.top;

  static bool _overlaps(BoundingBox a, BoundingBox b) =>
      a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

  static double _iou(BoundingBox a, BoundingBox b) {
    final ix = math.max(
      0.0,
      math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x),
    );
    final iy = math.max(
      0.0,
      math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y),
    );
    final inter = ix * iy;
    final union = a.w * a.h + b.w * b.h - inter;
    return union <= 0 ? 0 : inter / union;
  }

  /// Text of the words on [line] ending before [blank] (the blank's label).
  static String _wordsBefore(LayoutLine line, Rect blank) => line.words
      .where((w) => w.box.right <= blank.left + 0.002)
      .map((w) => w.text)
      .join(' ')
      .replaceAll(LayoutLine.blankRun, ' ');

  static String _wordsAfter(LayoutLine line, Rect blank) => line.words
      .where((w) => w.box.left >= blank.right - 0.002)
      .map((w) => w.text)
      .join(' ')
      .replaceAll(LayoutLine.blankRun, ' ');

  static String _lastWords(String s, int n) {
    final parts = s.trim().split(RegExp(r'\s+'));
    return parts.sublist(math.max(0, parts.length - n)).join(' ');
  }

  /// The label a blank is known by: the phrase right before it, after the
  /// last punctuation, at most two words ("I, the undersigned, X, aged" →
  /// "aged"; "2. I was born on" → "born on").
  static String _cleanLabel(String s) {
    var t = s.replaceAll(RegExp(r'[\s,:;.\-–—]+$'), '');
    final cut = t.lastIndexOf(RegExp(r'[,:;.]'));
    if (cut >= 0) t = t.substring(cut + 1);
    // Up to three words, minus leading filler: "Date of birth" stays whole,
    // "I was born on" → "born on", "I am aged" → "aged".
    final words = _lastWords(
      t.replaceAll(RegExp(r'^[\d.()\s]+'), ''),
      3,
    ).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    while (words.length > 1 && _filler.contains(words.first.toLowerCase())) {
      words.removeAt(0);
    }
    t = words.join(' ');
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  static const _filler = {
    'i',
    'am',
    'is',
    'was',
    'were',
    'be',
    'been',
    'the',
    'a',
    'an',
    'my',
    'our',
    'your',
    'his',
    'her',
    'their',
    'and',
    'or',
    'to',
    'we',
    'he',
    'she',
    'they',
    'it',
    'this',
    'that',
  };

  /// A signature is named by its whole signer line ("DEPONENT (ANBU MAHESH)").
  static String _signerLabel(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  /// A short line that reads like a person's name: 2–5 words, mostly
  /// capitalised, no sentence punctuation.
  static bool _looksLikeName(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 48 || RegExp(r'[.:;!?]$').hasMatch(t)) {
      return false;
    }
    final words = t
        .replaceAll(RegExp(r'[()\[\],]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < 2 || words.length > 5) return false;
    final capped = words.where((w) => RegExp(r'^[A-Z]').hasMatch(w)).length;
    return capped >= words.length - 1;
  }

  static LayoutLine? _lineOnBaseline(
    List<LayoutLine> lines,
    Rect rule,
    double textSize,
  ) {
    for (final l in lines) {
      if ((l.box.bottom - rule.bottom).abs() < textSize * 0.9) return l;
    }
    return null;
  }

  static LayoutLine? _lineBelow(List<LayoutLine> lines, Rect r, double within) {
    for (final l in lines) {
      if (l.box.top >= r.bottom - 0.002 && l.box.top - r.bottom < within) {
        if (_hOverlap(l.box, r) > 0 || (l.box.left - r.left).abs() < 0.15) {
          return l;
        }
      }
    }
    return null;
  }

  static LayoutLine? _lineAbove(List<LayoutLine> lines, Rect r, double within) {
    for (final l in lines.reversed) {
      if (l.box.bottom <= r.top + 0.002 && r.top - l.box.bottom < within) {
        if (_hOverlap(l.box, r) > 0 || (l.box.left - r.left).abs() < 0.15) {
          return l;
        }
      }
    }
    return null;
  }
}

class _Candidate {
  _Candidate({
    required this.rect,
    required this.line,
    required this.left,
    required this.standalone,
  });
  final Rect rect;
  final LayoutLine? line;
  final String left;

  /// The blank is alone on its line (a signature-style line).
  final bool standalone;
}

class _Field {
  _Field(this.type, this.box, this.label);
  FieldType type;
  BoundingBox box;
  final String label;
  bool autoToday = false;
}
