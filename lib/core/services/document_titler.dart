import 'page_layout.dart';

/// Picks a document's title from the text of its first page: the line set
/// clearly larger than the body text, near the top. Forms put their title
/// there ("Rental Application", "Demande de location").
///
/// Returns null rather than guess: no line stands out, the page has no text,
/// or the candidate looks like a label, a date or a reference number. The
/// caller then keeps "Document {date}".
class DocumentTitler {
  const DocumentTitler._();

  static const maxLength = 40;

  /// How much larger than the body text a line must be to count as a title.
  static const _minScale = 1.25;

  static String? titleFrom(PageLayout layout) {
    final body = layout.bodyTextSize;
    if (body == null) return null;

    LayoutLine? best;
    for (final line in layout.lines) {
      // Top 40% of the page: titles sit above the form, not in it.
      if (line.box.top > 0.4) continue;
      if (line.fontSize < body * _minScale) continue;
      if (!_looksLikeTitle(line.textWithoutBlanks)) continue;
      if (best == null ||
          line.fontSize > best.fontSize * 1.05 ||
          (line.fontSize >= best.fontSize * 0.95 &&
              line.box.top < best.box.top)) {
        best = line;
      }
    }
    if (best == null) return null;
    return clean(best.textWithoutBlanks);
  }

  static bool _looksLikeTitle(String text) {
    final t = text.trim();
    if (t.length < 3) return false;
    // A label waiting for a value ("Name:") isn't a title.
    if (t.endsWith(':')) return false;
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
    // Mostly letters: not a date, amount, phone number or reference code.
    if (letters < 3 || letters < t.replaceAll(' ', '').length * 0.6) {
      return false;
    }
    final lower = t.toLowerCase();
    if (lower.startsWith('page ') || lower.startsWith('http')) return false;
    if (lower.contains('@') || lower.contains('www.')) return false;
    return true;
  }

  /// Trims punctuation, turns an ALL-CAPS title into sentence case, and cuts it
  /// to [maxLength] at a word boundary.
  static String clean(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'^[\s\-–—:.,;•*#]+|[\s\-–—:.,;•*#]+$'), '');
    final letters = t.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    if (letters.length > 3 &&
        letters == letters.toUpperCase() &&
        letters != letters.toLowerCase()) {
      // Sentence case reads right in every shipped language ("Demande de
      // location", not "Demande De Location"). Words with digits are codes
      // ("W-9"), kept as printed.
      final words = t.split(' ');
      t = [
        for (var i = 0; i < words.length; i++)
          RegExp(r'\d').hasMatch(words[i])
              ? words[i]
              : i == 0
              ? words[i][0] + words[i].substring(1).toLowerCase()
              : words[i].toLowerCase(),
      ].join(' ');
    }
    if (t.length <= maxLength) return t;
    final cut = t.substring(0, maxLength);
    final space = cut.lastIndexOf(' ');
    return '${(space > maxLength ~/ 2 ? cut.substring(0, space) : cut).trimRight()}…';
  }
}
