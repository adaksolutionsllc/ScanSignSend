import 'dart:math' as math;
import 'dart:ui' show Rect;

import '../models/field_model.dart';
import 'page_layout.dart';

/// Human labels for a PDF's own form fields (AcroForm).
///
/// A field's internal name is for software ("topmostSubform[0].Page1[0]
/// .Step1a[0].f1_01[0]" on the IRS W-4), not for people. In order, the label
/// is the field's tooltip (/TU), the caption printed beside it on the page,
/// its name when that is made of real words, or empty — the UI then shows
/// the field's type ("Text", "Checkbox").
///
/// No user-facing text lives here: everything returned comes from the PDF.
class AcroformLabels {
  AcroformLabels._();

  static const _maxLength = 60;
  static const _maxWords = 6;

  /// The label for a field of [type] at [box] (normalised to the page) on a
  /// page whose text layer is [lines].
  static String label({
    required FieldType type,
    required BoundingBox box,
    required List<LayoutLine> lines,
    String? tooltip,
    String? name,
  }) {
    final fromTip = _tidy(tooltip ?? '');
    if (fromTip.isNotEmpty) return fromTip;

    final r = Rect.fromLTWH(box.x, box.y, box.w, box.h);
    final fromPage = type == FieldType.checkbox || type == FieldType.radio
        ? _forCheckbox(r, lines)
        : _forTextField(r, lines);
    if (fromPage.isNotEmpty) return fromPage;

    return _fromName(name ?? '');
  }

  // ── From the page ─────────────────────────────────────────────────────────

  /// A box to type in. A label right before it wins ("Name: [____]", or a
  /// line number such as "3(a) $ [____]"); then the caption printed just
  /// above it in its column (tax and government forms); then whatever
  /// phrase precedes it on its line.
  static String _forTextField(Rect r, List<LayoutLine> lines) {
    final left = _leftOf(r, lines);
    final leftLabel = _leftLabel(left.words, r, lines);
    if (left.adjacent && leftLabel.isNotEmpty) return leftLabel;
    final above = _above(r, lines);
    if (above.isNotEmpty) return above;
    return leftLabel;
  }

  /// A checkbox's text is to its right ("☐ Single or Married filing
  /// separately"); a short label right before it also works ("Yes ☐").
  static String _forCheckbox(Rect r, List<LayoutLine> lines) {
    final right = _rightOf(r, lines);
    if (right.isNotEmpty) return right;
    final left = _leftOf(r, lines);
    if (!left.adjacent || left.words.length > 4) return '';
    final t = _tidy(left.words.map((w) => w.text).join(' '));
    return _isFragment(t) ? '' : t;
  }

  /// The caption over the field: words on the nearest line above whose
  /// middle lies within the field's width, plus the line above that when the
  /// caption wraps ("First date of" / "employment").
  static String _above(Rect r, List<LayoutLine> lines) {
    bool inColumn(LayoutWord w) {
      final mid = w.box.center.dx;
      return mid >= r.left - 0.005 && mid <= r.right;
    }

    List<LayoutWord> columnWords(LayoutLine l) =>
        l.words.where((w) => inColumn(w) && !_isLeader(w.text)).toList()
          ..sort((a, b) => a.box.left.compareTo(b.box.left));

    LayoutLine? nearestAbove(double top, {LayoutLine? except}) {
      LayoutLine? best;
      for (final l in lines) {
        if (identical(l, except)) continue;
        final h = math.max(l.box.height, 0.006);
        // Just above, or overlapping the top edge (captions printed inside
        // the field's cell).
        if (l.box.center.dy > top + r.height * 0.3) continue;
        if (top - l.box.bottom > h * 1.2) continue;
        if (columnWords(l).isEmpty) continue;
        if (best == null || l.box.bottom > best.box.bottom) best = l;
      }
      return best;
    }

    final first = nearestAbove(r.top);
    if (first == null) return '';
    final parts = [columnWords(first)];
    final second = nearestAbove(first.box.top, except: first);
    if (second != null &&
        first.box.top - second.box.bottom < first.box.height * 0.5) {
      // Only a wrapped caption: the line above starts in the same place.
      final w = columnWords(second);
      if ((w.first.box.left - parts.first.first.box.left).abs() < 0.02) {
        parts.insert(0, w);
      }
    }
    final t = _tidy(parts.expand((p) => p).map((w) => w.text).join(' '));
    return _isFragment(t) ? '' : t;
  }

  /// The words before the field on its row — gathered from every text line
  /// level with it, since a line number is often a text line of its own
  /// ("…more information . . . ." then "5 $") — from the last wide gap on.
  /// [adjacent] when they end right at the field.
  static ({List<LayoutWord> words, bool adjacent}) _leftOf(
    Rect r,
    List<LayoutLine> lines,
  ) {
    final row = _row(r, lines);
    if (row.isEmpty) return (words: const [], adjacent: false);
    final words = [
      for (final l in row)
        ...l.words.where(
          (w) => w.box.right <= r.left + 0.005 && !_currency.hasMatch(w.text),
        ),
    ]..sort((a, b) => a.box.left.compareTo(b.box.left));
    final run = _lastRun(words, _gap(row.first));
    if (run.isEmpty) return (words: const [], adjacent: false);
    final gapToField = r.left - run.last.box.right;
    final isItem = _itemCode.hasMatch(run.map((w) => w.text).join(' '));
    // Words stacked on several lines are a block of text beside the field
    // (a section heading in a side column), not a label written before it.
    final mids = run.map((w) => w.box.center.dy);
    final stacked =
        mids.reduce(math.max) - mids.reduce(math.min) >
        row.first.box.height * 0.5;
    return (
      words: run,
      // A "$" between a line number and its box widens the gap.
      adjacent: !stacked && gapToField < (isItem ? 0.04 : 0.012),
    );
  }

  /// Text before a field, as a label. A bare line number ("3(a) $") is
  /// named with the start of its line's description ("3(a) Multiply the
  /// number of qualifying children"); sentence fragments are rejected.
  static String _leftLabel(
    List<LayoutWord> run,
    Rect r,
    List<LayoutLine> lines,
  ) {
    if (run.isEmpty) return '';
    final t = run
        .map((w) => w.text)
        .join(' ')
        .replaceAll(RegExp(r'[$€£₹]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (_itemCode.hasMatch(t)) {
      return _describe(t.replaceAll('.', ''), r, lines);
    }
    final tidy = _tidy(t);
    if (_isFragment(tidy)) return '';
    final words = tidy.split(' ');
    return words.length > _maxWords
        ? words.sublist(words.length - _maxWords).join(' ')
        : tidy;
  }

  static final _itemCode = RegExp(
    r'^(\d{1,2}[a-z]?|\d{1,2}\([a-z0-9]\)|\([a-z]\))\.?$',
    caseSensitive: false,
  );

  /// "[code] [first words of its description]": the description is the line
  /// at the left margin, at or above the field, that starts with the code
  /// (or its letter: "b" / "(b)" for "1b" / "3(b)").
  static String _describe(String code, Rect r, List<LayoutLine> lines) {
    final keys = <String>{code.toLowerCase()};
    final sub = RegExp(
      r'^\d+\(?([a-z])\)?$',
      caseSensitive: false,
    ).firstMatch(code);
    if (sub != null) {
      final letter = sub[1]!.toLowerCase();
      keys.addAll([letter, '($letter)']);
    }
    LayoutLine? best;
    for (final l in lines) {
      if (l.box.center.dy > r.bottom || l.box.center.dy < r.top - 0.08) {
        continue;
      }
      final words = [...l.words]
        ..sort((a, b) => a.box.left.compareTo(b.box.left));
      if (words.isEmpty || words.first.box.left > r.left - 0.2) continue;
      final head = words.first.text.toLowerCase().replaceAll(
        RegExp(r'\.$'),
        '',
      );
      if (!keys.contains(head)) continue;
      if (best == null || l.box.center.dy > best.box.center.dy) {
        best = l;
      }
    }
    if (best == null) return code;
    var phrase = best.text.trim().replaceFirst(RegExp(r'^\S+\s*'), '');
    // Letter-spaced type ("Q u a l i f i e d") has no word breaks to keep.
    final tokens = phrase.split(' ');
    if (tokens.where((t) => t.length == 1).length > tokens.length * 0.6) {
      return code;
    }
    // Its first sentence or clause: "Qualified overtime compensation."
    final end = RegExp(r'[.:;](\s|$)').firstMatch(phrase);
    if (end != null) phrase = phrase.substring(0, end.start);
    final words = _tidy(phrase).split(' ').where((w) => w.isNotEmpty).toList();
    // A one-word lead-in ("9 Enter: • $768,700 if…") says nothing.
    final leadIn =
        end != null && words.length == 1 && end.group(0)!.startsWith(':');
    if (words.isEmpty || leadIn) return code;
    return '$code ${words.take(_maxWords).join(' ')}';
  }

  /// The text right of a checkbox, up to the next wide gap; a parenthetical
  /// aside is dropped ("Head of household (Check only if…" → "Head of
  /// household").
  static String _rightOf(Rect r, List<LayoutLine> lines) {
    final row = _row(r, lines);
    if (row.isEmpty) return '';
    final words = [
      for (final l in row)
        ...l.words.where(
          (w) => w.box.left >= r.right - 0.005 && !_isLeader(w.text),
        ),
    ]..sort((a, b) => a.box.left.compareTo(b.box.left));
    if (words.isEmpty || words.first.box.left - r.right > 0.05) return '';
    final run = <LayoutWord>[words.first];
    final gap = _gap(row.first);
    for (final w in words.skip(1)) {
      if (w.box.left - run.last.box.right > gap) break;
      run.add(w);
    }
    var t = run.map((w) => w.text).join(' ');
    final paren = t.indexOf(' (');
    if (paren > 0) t = t.substring(0, paren);
    t = _tidy(t);
    return _isFragment(t) ? '' : t;
  }

  /// Text lines level with [r] (their middles within its height or theirs).
  static List<LayoutLine> _row(Rect r, List<LayoutLine> lines) {
    final cy = r.center.dy;
    return [
      for (final l in lines)
        if ((l.box.center.dy - cy).abs() <=
            math.max(l.box.height * 0.6, r.height * 0.5))
          l,
    ];
  }

  /// A gap wider than about two spaces separates phrases on a line.
  static double _gap(LayoutLine l) => math.max(l.box.height, 0.008) * 1.2;

  static List<LayoutWord> _lastRun(List<LayoutWord> words, double gap) {
    final run = <LayoutWord>[];
    for (final w in words.reversed) {
      if (run.isNotEmpty && run.first.box.left - w.box.right > gap) break;
      if (_isLeader(w.text)) {
        if (run.isNotEmpty) break; // dot leaders end the phrase
        continue;
      }
      run.insert(0, w);
    }
    return run;
  }

  static final _currency = RegExp(r'^[$€£₹]$');

  static bool _isLeader(String t) => RegExp(r'^[.…_•\s]+$').hasMatch(t);

  /// Mid-sentence text — starts in lower case or with a bracket or a
  /// number, or has unbalanced brackets — isn't a label.
  static bool _isFragment(String t) {
    if (t.isEmpty) return true;
    if (RegExp(r'^[a-z(\[{)\d$€£₹,]').hasMatch(t)) return true;
    return '('.allMatches(t).length != ')'.allMatches(t).length;
  }

  // ── From the name ─────────────────────────────────────────────────────────

  /// "FirstName" → "First name"; generated names ("f1_01", "Text3",
  /// "topmostSubform…") → empty.
  static String _fromName(String name) {
    var t = name.split('.').last.replaceAll(RegExp(r'\[\d+\]'), '');
    t = t
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.any((w) => !RegExp(r'^[A-Za-z]{2,}$').hasMatch(w))) return '';
    if (_generic.hasMatch(t)) return '';
    final s = words.map((w) => w.toLowerCase()).join(' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  static final _generic = RegExp(
    r'^(text|field|check ?box|button|radio|signature|form|topmost ?subform|subform|page|untitled|fill|tx|cb)( (box|field|button))?$',
    caseSensitive: false,
  );

  // ── Cleaning ──────────────────────────────────────────────────────────────

  /// Leading item markers ("(a)", "1.", "Step 1:"), trailing punctuation,
  /// spare spaces; capped in length at a word boundary.
  static String _tidy(String s) {
    var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    final marker = RegExp(
      r'^(step\s+\d+[a-z]?(\([a-z]\))?[.:]?|\(?[a-z0-9]{1,2}\)|\d+[.)])\s+',
      caseSensitive: false,
    );
    while (marker.hasMatch(t)) {
      t = t.replaceFirst(marker, '');
    }
    t = t.replaceAll(RegExp(r'[\s:;.,_…\-–—]+$'), '');
    if (t.length > _maxLength) {
      final cut = t.lastIndexOf(' ', _maxLength);
      t = t.substring(0, cut > 20 ? cut : _maxLength);
    }
    return t;
  }
}
