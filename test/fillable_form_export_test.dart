// End-to-end verification of the fill round-trip that
// FillableFormExportService depends on: author a form → set values on its
// widgets exactly as _fillExistingForm does → save → re-open → assert the
// values survived and the form is still live (field count preserved).
//
// This is the strongest check possible without a human opening the PDF in
// Acrobat/Preview/Chrome (the remaining manual gate).

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('filling existing AcroForm widgets round-trips through save/reload',
      () async {
    // ── Author a form (stands in for an imported fillable PDF) ────────────────
    final authored = PdfDocument();
    final page = authored.pages.add();
    authored.form.fields.add(
        PdfTextBoxField(page, 'full_name', const Rect.fromLTWH(40, 40, 200, 24)));
    authored.form.fields.add(
        PdfCheckBoxField(page, 'agree', const Rect.fromLTWH(40, 80, 20, 20)));
    authored.form.fields.add(
        PdfSignatureField(page, 'sig', bounds: const Rect.fromLTWH(40, 120, 200, 60)));
    final authoredBytes = await authored.save();
    authored.dispose();

    // ── Fill it exactly as _fillExistingForm() does (match by name, set value) ─
    final doc = PdfDocument(inputBytes: authoredBytes);
    final values = <String, dynamic>{
      'full_name': 'Ada Lovelace',
      'agree': true,
    };
    for (var i = 0; i < doc.form.fields.count; i++) {
      final field = doc.form.fields[i];
      if (field is PdfTextBoxField && values.containsKey(field.name)) {
        field.text = values[field.name] as String;
      } else if (field is PdfCheckBoxField && values.containsKey(field.name)) {
        field.isChecked = values[field.name] as bool;
      }
    }
    final filledBytes = await doc.save();
    doc.dispose();

    // ── Re-open the filled output and assert the values stuck ─────────────────
    final reopened = PdfDocument(inputBytes: filledBytes);
    expect(reopened.form.fields.count, 3,
        reason: 'form must stay live (3 fields) after filling');

    String? nameValue;
    bool? agreeValue;
    for (var i = 0; i < reopened.form.fields.count; i++) {
      final field = reopened.form.fields[i];
      if (field is PdfTextBoxField && field.name == 'full_name') {
        nameValue = field.text;
      } else if (field is PdfCheckBoxField && field.name == 'agree') {
        agreeValue = field.isChecked;
      }
    }
    reopened.dispose();

    expect(nameValue, 'Ada Lovelace');
    expect(agreeValue, isTrue);
  });

  test('authoring new widgets on an image-less page produces a live form',
      () async {
    // Mirrors _addWidget for the scanned-page path: create fields from scratch.
    final doc = PdfDocument();
    final page = doc.pages.add();
    final tb = PdfTextBoxField(page, 'field_text', const Rect.fromLTWH(50, 50, 150, 22));
    tb.text = 'seeded';
    doc.form.fields.add(tb);
    final cb = PdfCheckBoxField(page, 'field_check', const Rect.fromLTWH(50, 90, 18, 18));
    cb.isChecked = true;
    doc.form.fields.add(cb);
    final bytes = await doc.save();
    doc.dispose();

    final reopened = PdfDocument(inputBytes: bytes);
    expect(reopened.form.fields.count, 2);
    reopened.dispose();
  });
}
