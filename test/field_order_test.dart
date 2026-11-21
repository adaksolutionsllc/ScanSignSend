// "Next field" filling walks a form in reading order: page, row, then left
// to right; it stops only at empty fields a person must write in.

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/field_order.dart';

int _id = 0;

Field field(
  String label, {
  int page = 0,
  required double x,
  required double y,
  double w = 0.3,
  double h = 0.04,
  String type = 'text',
  bool filled = false,
}) => Field(
  id: ++_id,
  documentId: 1,
  pageIndex: page,
  type: type,
  boundingBoxJson: '{"x":$x,"y":$y,"w":$w,"h":$h}',
  label: label,
  value: filled ? 'x' : '',
  isChecked: false,
  isFilled: filled,
  isRequired: false,
  sourceKind: 'app',
);

List<String> labels(List<Field> fs) => [for (final f in fs) f.label];

void main() {
  test('rows top to bottom, left to right; slightly uneven rows stay rows', () {
    final fs = [
      field('Signature', x: 0.1, y: 0.8),
      field('Last name', x: 0.55, y: 0.105), // a touch lower than First name
      field('First name', x: 0.1, y: 0.1),
      field('Address', x: 0.1, y: 0.2, w: 0.8),
    ];
    expect(labels(FieldOrder.of(fs)), [
      'First name',
      'Last name',
      'Address',
      'Signature',
    ]);
  });

  test('page 1 before page 2, whatever the position', () {
    final fs = [
      field('P2 top', page: 1, x: 0.1, y: 0.05),
      field('P1 bottom', x: 0.1, y: 0.9),
    ];
    expect(labels(FieldOrder.of(fs)), ['P1 bottom', 'P2 top']);
  });

  test('next skips filled fields and checkboxes, and ends at null', () {
    final a = field('Name', x: 0.1, y: 0.1, filled: true);
    final b = field('Agree', x: 0.1, y: 0.2, type: 'checkbox');
    final c = field('Email', x: 0.1, y: 0.3);
    final d = field('Sign', x: 0.1, y: 0.4, type: 'signature');
    final fs = [d, c, b, a];
    expect(FieldOrder.nextEmpty(fs)?.label, 'Email');
    expect(FieldOrder.nextEmpty(fs, currentId: c.id)?.label, 'Sign');
    expect(FieldOrder.nextEmpty(fs, currentId: d.id), isNull);
    expect(FieldOrder.emptyCount(fs), 2);
  });
}
