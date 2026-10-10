import 'dart:convert';
import 'dart:typed_data';

import 'package:agreements_core/agreements_core.dart';
import 'package:test/test.dart';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  const kdf = DartPbkdf2Sha256();

  test('PBKDF2-HMAC-SHA256 matches RFC 7914 §11 vector', () async {
    final out = await kdf.pbkdf2Sha256(
      'passwd',
      Uint8List.fromList(utf8.encode('salt')),
      1,
      64,
    );
    expect(
      hex(out),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
      '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
  });

  test('PBKDF2 multi-iteration matches Python hashlib', () async {
    final out = await kdf.pbkdf2Sha256(
      'K7QM4XD29P',
      Uint8List.fromList(utf8.encode('0123456789abcdef')),
      1000,
      32,
    );
    expect(
      hex(out),
      '9468a51dd28ba260e0f2e8437f97cb9b5d72c4b981b899574efc920350cf44a7',
    );
  });

  test('verifier accepts the code and rejects others', () async {
    final code = AccessCode.generate();
    final v = await AccessVerifier.create(code, kdf, iterations: 1000);
    expect(await v.matches(code, kdf), isTrue);
    expect(await v.matches(AccessCode.generate(), kdf), isFalse);
  });

  test('code proof binds every input', () {
    String p({
      String code = 'K7QM4XD29P',
      String id = 'env-1',
      String name = 'Priya Raman',
      String hash = 'ab',
    }) => accessCodeProof(
      canonicalCode: code,
      envelopeId: id,
      signerName: name,
      contentSha256Hex: hash,
    );
    final base = p();
    expect(p(code: 'K7QM4XD29Q'), isNot(base));
    expect(p(id: 'env-2'), isNot(base));
    expect(p(name: 'Priya  Raman'), isNot(base));
    expect(p(hash: 'ac'), isNot(base));
    // Length prefixes: moving a boundary changes the proof.
    expect(p(id: 'env-1P', name: 'riya Raman'), isNot(base));
  });

  test('content digest matches only an unchanged prefix', () {
    final content = Uint8List.fromList(List.generate(100, (i) => i));
    final d = ContentDigest.of(content);
    final appended = Uint8List.fromList([...content, 1, 2, 3]);
    expect(d.matchesPrefixOf(appended), isTrue);
    final edited = Uint8List.fromList(appended)..[50] ^= 1;
    expect(d.matchesPrefixOf(edited), isFalse);
    expect(d.matchesPrefixOf(Uint8List.sublistView(content, 0, 99)), isFalse);
  });

  test('masking', () {
    expect(maskEmail('priya.raman@gmail.com'), 'p•••@gmail.com');
    expect(maskPhone('+91 98765 54821'), '+91 ••••• •4821');
    expect(maskPhone('(555) 123-4567'), '(•••) •••-4567');
    expect(maskPhone('4567'), '4567');
  });
}
