import 'dart:convert';

import 'package:flutter/material.dart';

enum FieldType { text, date, checkbox, signature }

extension FieldTypeX on String {
  FieldType toFieldType() => switch (this) {
        'date' => FieldType.date,
        'checkbox' => FieldType.checkbox,
        'signature' => FieldType.signature,
        _ => FieldType.text,
      };
}

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

  Rect toRect(Size pageSize) => Rect.fromLTWH(
        x * pageSize.width,
        y * pageSize.height,
        w * pageSize.width,
        h * pageSize.height,
      );
}
