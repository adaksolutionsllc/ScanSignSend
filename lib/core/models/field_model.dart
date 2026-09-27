import 'dart:convert';

import 'package:flutter/material.dart';

/// Stored in `Fields.type` by [Enum.name]; order here is also the editor
/// toolbar's order.
enum FieldType { text, checkbox, radio, date, initials, signature }

extension FieldTypeX on String {
  FieldType toFieldType() => switch (this) {
    'date' => FieldType.date,
    'checkbox' => FieldType.checkbox,
    'radio' => FieldType.radio,
    'initials' => FieldType.initials,
    'signature' => FieldType.signature,
    _ => FieldType.text,
  };
}

extension FieldTypeTraits on FieldType {
  /// Drawn as a bare outline (square / circle), kept square when resized.
  bool get isToggle => this == FieldType.checkbox || this == FieldType.radio;

  /// Filled with a drawn image rather than typed text.
  bool get isInk => this == FieldType.signature || this == FieldType.initials;
}

// ── Field options (`Fields.optionsJson`) ───────────────────────────────────
//
// App-authored fields keep small internal settings in `optionsJson` as a JSON
// object; fields imported from a PDF form may instead hold a JSON *list* of
// choices there. Always read and write through these helpers so one setting
// never erases another.
//
//   group      — radio buttons: choosing one option clears the others in the
//                same group. An internal id, so the label stays the user's.
//   autoToday  — dates: filled with today's date when the page is signed.

Map<String, Object?> _options(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) return Map<String, Object?>.from(decoded);
  } catch (_) {}
  return {};
}

String? radioGroupOf(String? optionsJson) {
  final g = _options(optionsJson)['group'];
  return g is String ? g : null;
}

bool autoTodayOf(String? optionsJson) =>
    _options(optionsJson)['autoToday'] == true;

/// Builds `optionsJson` for an app field; null when there's nothing to store.
String? fieldOptionsJson({String? group, bool autoToday = false}) {
  final m = <String, Object?>{
    'group': ?group,
    if (autoToday) 'autoToday': true,
  };
  return m.isEmpty ? null : jsonEncode(m);
}

String radioGroupJson(String group) => fieldOptionsJson(group: group)!;

/// Normalised bounding box (values 0..1 relative to page dimensions).
class BoundingBox {
  final double x, y, w, h;
  const BoundingBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    h: (json['h'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  String toJsonString() => jsonEncode(toJson());

  static BoundingBox fromJsonString(String s) =>
      BoundingBox.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// This box after its page is turned 90° clockwise: the page's left edge
  /// becomes its top, so what was `y` from the top is now `1 - y - h` from the
  /// left.
  BoundingBox rotatedClockwise() => BoundingBox(x: 1 - y - h, y: x, w: h, h: w);

  /// The on-screen rect of this box when the page content is drawn into
  /// [pageRect]. Every renderer (editor, fill mode, press, export) must place
  /// fields through the page content's own rect, never the surrounding
  /// container. See PageCanvas.
  Rect inPageRect(Rect pageRect) => Rect.fromLTWH(
    pageRect.left + x * pageRect.width,
    pageRect.top + y * pageRect.height,
    w * pageRect.width,
    h * pageRect.height,
  );

  Rect toRect(Size pageSize) => Rect.fromLTWH(
    x * pageSize.width,
    y * pageSize.height,
    w * pageSize.width,
    h * pageSize.height,
  );
}
