import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The PDF an envelope describes: the first [length] bytes of the file, which
/// later steps append to (PDF incremental update) but never rewrite. Any
/// re-save in another editor changes those bytes and shows up here.
class ContentDigest {
  const ContentDigest({required this.length, required this.hash});

  factory ContentDigest.of(List<int> bytes) =>
      ContentDigest(length: bytes.length, hash: sha256Hex(bytes));

  final int length;
  /// SHA-256 of those bytes, lowercase hex.
  final String hash;

  /// True when [file] still starts with exactly the bytes this describes.
  bool matchesPrefixOf(Uint8List file) =>
      file.length >= length &&
      hash == sha256Hex(Uint8List.sublistView(file, 0, length));

  Map<String, Object?> toJson() => {'length': length, 'sha256': hash};

  @override
  bool operator ==(Object other) =>
      other is ContentDigest &&
      other.length == length &&
      other.hash == hash;

  @override
  int get hashCode => Object.hash(length, hash);
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Recorded by the recipient's app when they sign; recomputed by the sender's
/// app from the code it kept. Shows the signer's app really had the code even
/// if it was modified to skip the verifier. Fields are length-prefixed so no
/// two inputs share an encoding.
String accessCodeProof({
  required String canonicalCode,
  required String envelopeId,
  required String signerName,
  required String contentSha256Hex,
}) {
  final msg = BytesBuilder();
  for (final part in [envelopeId, signerName, contentSha256Hex]) {
    final bytes = utf8.encode(part);
    msg
      ..add((ByteData(4)..setUint32(0, bytes.length)).buffer.asUint8List())
      ..add(bytes);
  }
  return Hmac(
    sha256,
    utf8.encode(canonicalCode),
  ).convert(msg.toBytes()).toString();
}
