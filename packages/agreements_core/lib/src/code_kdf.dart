import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Stretches an access code into a verifier. The app passes an OS-backed
/// implementation (CommonCrypto / javax.crypto) so 600,000 iterations take
/// about half a second; [DartPbkdf2Sha256] is the reference used in tests.
abstract interface class CodeKdf {
  Future<Uint8List> pbkdf2Sha256(
    String code,
    Uint8List salt,
    int iterations,
    int length,
  );
}

/// PBKDF2-HMAC-SHA256 (RFC 8018) in Dart. Correct but too slow for the
/// production iteration count on a phone.
class DartPbkdf2Sha256 implements CodeKdf {
  const DartPbkdf2Sha256();

  @override
  Future<Uint8List> pbkdf2Sha256(
    String code,
    Uint8List salt,
    int iterations,
    int length,
  ) async {
    final hmac = Hmac(sha256, utf8.encode(code));
    final out = BytesBuilder(copy: false);
    for (var block = 1; out.length < length; block++) {
      final first = Uint8List(salt.length + 4)
        ..setAll(0, salt)
        ..buffer.asByteData().setUint32(salt.length, block);
      var u = hmac.convert(first).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.toBytes(), 0, length);
  }
}

/// The slow check the recipient's app runs before signing, stored in the
/// envelope. Safe to publish only because codes carry 45 random bits.
class AccessVerifier {
  const AccessVerifier({
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  static const kdfName = 'pbkdf2-sha256';
  static const defaultIterations = 600000;
  static const _saltLength = 16;
  static const _hashLength = 32;

  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  static Future<AccessVerifier> create(
    String canonicalCode,
    CodeKdf kdf, {
    int iterations = defaultIterations,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => rng.nextInt(256)),
    );
    final hash = await kdf.pbkdf2Sha256(
      canonicalCode,
      salt,
      iterations,
      _hashLength,
    );
    return AccessVerifier(iterations: iterations, salt: salt, hash: hash);
  }

  Future<bool> matches(String canonicalCode, CodeKdf kdf) async {
    final candidate = await kdf.pbkdf2Sha256(
      canonicalCode,
      salt,
      iterations,
      hash.length,
    );
    return constantTimeEquals(candidate, hash);
  }

  Map<String, Object?> toJson() => {
    'kdf': kdfName,
    'iterations': iterations,
    'salt': base64.encode(salt),
    'hash': base64.encode(hash),
  };
}

bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
