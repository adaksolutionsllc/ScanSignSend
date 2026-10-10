import 'dart:math';

/// The code the sender sends outside the app (SMS, WhatsApp, email) and the
/// recipient types before signing.
///
/// Nine random Crockford base32 symbols (45 bits) plus a Luhn mod 32 check
/// symbol, shown as `K7QM-4XD2-9P`. The length is what keeps the verifier in
/// the PDF safe to publish — never shorten it.
abstract final class AccessCode {
  /// Crockford base32: no I, L, O or U.
  static const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const randomLength = 9;
  static const length = randomLength + 1;

  /// A new code in canonical form (no separators), from the OS CSPRNG.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final payload = String.fromCharCodes(
      List.generate(
        randomLength,
        (_) => alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
      ),
    );
    return payload + _checkSymbol(payload);
  }

  /// `K7QM4XD29P` → `K7QM-4XD2-9P`.
  static String format(String canonical) {
    assert(canonical.length == length);
    return '${canonical.substring(0, 4)}-${canonical.substring(4, 8)}-'
        '${canonical.substring(8)}';
  }

  /// What the recipient typed, in canonical form; null if it can't be a code
  /// (wrong length or a symbol outside the alphabet). Accepts lower case,
  /// spaces and dashes, and reads I/L as 1 and O as 0, as Crockford intends.
  static String? normalize(String input) {
    final buf = StringBuffer();
    for (final ch in input.toUpperCase().split('')) {
      if (ch == '-' || ch.trim().isEmpty) continue;
      final mapped = switch (ch) {
        'I' || 'L' => '1',
        'O' => '0',
        _ => ch,
      };
      if (!alphabet.contains(mapped)) return null;
      buf.write(mapped);
    }
    final s = buf.toString();
    return s.length == length ? s : null;
  }

  /// True when the check symbol matches, so a typo is caught before the slow
  /// verifier runs. Catches every single-symbol error and most swaps of
  /// neighbouring symbols.
  static bool hasValidCheck(String canonical) {
    if (canonical.length != length) return false;
    var factor = 1;
    var sum = 0;
    for (var i = canonical.length - 1; i >= 0; i--) {
      final cp = alphabet.indexOf(canonical[i]);
      if (cp < 0) return false;
      var addend = factor * cp;
      factor = factor == 2 ? 1 : 2;
      addend = addend ~/ alphabet.length + addend % alphabet.length;
      sum += addend;
    }
    return sum % alphabet.length == 0;
  }

  // Luhn mod N (N = 32).
  static String _checkSymbol(String payload) {
    const n = 32;
    var factor = 2;
    var sum = 0;
    for (var i = payload.length - 1; i >= 0; i--) {
      var addend = factor * alphabet.indexOf(payload[i]);
      factor = factor == 2 ? 1 : 2;
      addend = addend ~/ n + addend % n;
      sum += addend;
    }
    return alphabet[(n - sum % n) % n];
  }
}
