import '../db/app_database.dart';
import '../models/field_model.dart';

/// The order a person reads a form in, for "Next field" filling: page by
/// page, then row by row from the top, then left to right within a row.
///
/// Fields whose boxes overlap vertically by at least half the shorter one
/// share a row, so "First name" and "Last name" side by side are one row
/// even when one box sits a little higher.
class FieldOrder {
  const FieldOrder._();

  static List<Field> of(List<Field> fields) {
    final byPage = <int, List<Field>>{};
    for (final f in fields) {
      (byPage[f.pageIndex] ??= []).add(f);
    }
    final out = <Field>[];
    for (final page in byPage.keys.toList()..sort()) {
      final boxes = {
        for (final f in byPage[page]!)
          f.id: BoundingBox.fromJsonString(f.boundingBoxJson),
      };
      final byTop = byPage[page]!.toList()
        ..sort((a, b) => boxes[a.id]!.y.compareTo(boxes[b.id]!.y));
      final rows = <List<Field>>[];
      for (final f in byTop) {
        final box = boxes[f.id]!;
        final row = rows.isEmpty ? null : rows.last;
        if (row != null && row.any((o) => _sameRow(boxes[o.id]!, box))) {
          row.add(f);
        } else {
          rows.add([f]);
        }
      }
      for (final row in rows) {
        row.sort((a, b) => boxes[a.id]!.x.compareTo(boxes[b.id]!.x));
        out.addAll(row);
      }
    }
    return out;
  }

  static bool _sameRow(BoundingBox a, BoundingBox b) {
    final overlap =
        (a.y + a.h < b.y + b.h ? a.y + a.h : b.y + b.h) -
        (a.y > b.y ? a.y : b.y);
    final shorter = a.h < b.h ? a.h : b.h;
    return shorter > 0 && overlap >= shorter / 2;
  }

  /// Fields "Next" stops at while they are empty: the ones a person must
  /// write in. Checkboxes and radios are left alone — an unticked box is a
  /// valid answer, and stepping through every one would only slow filling.
  static bool isStop(Field f) => !f.type.toFieldType().isToggle;

  static bool isEmpty(Field f) => !f.isFilled;

  /// The next empty stop after [currentId] in reading order (from the start
  /// when [currentId] is null), or null when every stop is filled.
  static Field? nextEmpty(List<Field> fields, {int? currentId}) {
    final order = of(fields);
    final start = currentId == null
        ? 0
        : order.indexWhere((f) => f.id == currentId) + 1;
    for (final f in order.skip(start)) {
      if (isStop(f) && isEmpty(f) && f.id != currentId) return f;
    }
    return null;
  }

  /// How many stops are still empty.
  static int emptyCount(List<Field> fields) =>
      fields.where((f) => isStop(f) && isEmpty(f)).length;
}
