import 'dart:convert';
import 'dart:typed_data';

import 'digest.dart';
import 'errors.dart';

// Typed readers for envelope JSON. Anything missing or mistyped is
// [EnvelopeError.malformed] naming the key, never a TypeError.

Never _bad(String key) => throw EnvelopeException(EnvelopeError.malformed, key);

T _read<T>(Map<String, Object?> j, String key) {
  final v = j[key];
  return v is T ? v : _bad(key);
}

String readString(Map<String, Object?> j, String key) => _read<String>(j, key);

String? readOptionalString(Map<String, Object?> j, String key) =>
    j[key] == null ? null : readString(j, key);

int readInt(Map<String, Object?> j, String key) => _read<int>(j, key);

double readDouble(Map<String, Object?> j, String key) =>
    _read<num>(j, key).toDouble();

bool readBool(Map<String, Object?> j, String key) => _read<bool>(j, key);

bool? readOptionalBool(Map<String, Object?> j, String key) =>
    j[key] == null ? null : readBool(j, key);

Map<String, Object?> readMap(Map<String, Object?> j, String key) =>
    Map<String, Object?>.from(_read<Map>(j, key));

List<Map<String, Object?>> readMapList(Map<String, Object?> j, String key) => [
  for (final e in _read<List>(j, key))
    e is Map ? Map<String, Object?>.from(e) : _bad(key),
];

DateTime readTime(Map<String, Object?> j, String key) =>
    DateTime.tryParse(readString(j, key))?.toUtc() ?? _bad(key);

T readEnum<T extends Enum>(
  Map<String, Object?> j,
  String key,
  List<T> values,
) {
  final name = readString(j, key);
  for (final v in values) {
    if (v.name == name) return v;
  }
  _bad(key);
}

T? readOptionalEnum<T extends Enum>(
  Map<String, Object?> j,
  String key,
  List<T> values,
) => j[key] == null ? null : readEnum(j, key, values);

Uint8List readBase64(Map<String, Object?> j, String key) {
  try {
    return base64.decode(readString(j, key));
  } on FormatException {
    _bad(key);
  }
}

ContentDigest readDigest(Map<String, Object?> j, String key) {
  final m = readMap(j, key);
  final hash = readString(m, 'sha256');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) _bad(key);
  return ContentDigest(length: readInt(m, 'length'), hash: hash);
}

ContentDigest? readOptionalDigest(Map<String, Object?> j, String key) =>
    j[key] == null ? null : readDigest(j, key);
