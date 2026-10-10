import 'dart:math';

import 'package:agreements_core/agreements_core.dart';
import 'package:test/test.dart';

void main() {
  test('generated codes are canonical and pass their check', () {
    final rng = Random(1);
    for (var i = 0; i < 500; i++) {
      final c = AccessCode.generate(rng);
      expect(c.length, AccessCode.length);
      expect(AccessCode.hasValidCheck(c), isTrue, reason: c);
      expect(AccessCode.normalize(AccessCode.format(c)), c);
    }
  });

  test('format groups 4-4-2', () {
    expect(AccessCode.format('K7QM4XD29P'), 'K7QM-4XD2-9P');
  });

  test('normalize accepts typing variations', () {
    final c = AccessCode.generate(Random(2));
    final typed = AccessCode.format(c).toLowerCase().replaceAll('-', ' ');
    expect(AccessCode.normalize(typed), c);
    expect(AccessCode.normalize('o1l1-iiii-oo'), '0111111100');
    expect(AccessCode.normalize('UUUU-UUUU-UU'), isNull); // U not in alphabet
    expect(AccessCode.normalize('ABC'), isNull);
  });

  test('check symbol catches every single-symbol error', () {
    final c = AccessCode.generate(Random(3));
    for (var i = 0; i < c.length; i++) {
      for (final s in AccessCode.alphabet.split('')) {
        if (s == c[i]) continue;
        final typo = c.replaceRange(i, i + 1, s);
        expect(AccessCode.hasValidCheck(typo), isFalse, reason: typo);
      }
    }
  });

  test('check symbol catches most neighbour swaps', () {
    final rng = Random(4);
    var swaps = 0, caught = 0;
    for (var n = 0; n < 300; n++) {
      final c = AccessCode.generate(rng);
      for (var i = 0; i + 1 < c.length; i++) {
        if (c[i] == c[i + 1]) continue;
        final t = c.substring(0, i) + c[i + 1] + c[i] + c.substring(i + 2);
        swaps++;
        if (!AccessCode.hasValidCheck(t)) caught++;
      }
    }
    expect(caught / swaps, greaterThan(0.95));
  });
}
