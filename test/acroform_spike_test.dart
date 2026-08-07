// Phase A0 — LIBRARY SPIKE (the gate for the whole PDF Workbench plan).
//
// This authors a PDF with a live text field, checkbox, and signature field via
// syncfusion_flutter_pdf and writes it to disk. The code compiling and running
// only proves the API *exists* — it does NOT prove the output renders correctly.
//
// >>> MANUAL STEP (a human must do this): open the generated file in
//     1) Adobe Acrobat, 2) Apple Preview, 3) Chrome
//     and confirm all three fields are visible, correctly placed, and fillable.
//
// PASS  → proceed with Phase A (see docs/WORKBENCH_PLAN.md).
// FAIL  → do NOT proceed; open docs/PDF_ENGINE_EVAL.md and evaluate alternatives.
//
// Run:  flutter test test/acroform_spike_test.dart
// The file path is printed at the end of the test output.

import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('authors a live AcroForm PDF (open the output in Acrobat/Preview/Chrome)',
      () async {
    final doc = PdfDocument();
    final page = doc.pages.add();
    final gfx = page.graphics;
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final black = PdfSolidBrush(PdfColor(0, 0, 0));

    // Labels so a human can see where each field should sit.
    gfx.drawString('Full name:', font,
        brush: black, bounds: const Rect.fromLTWH(40, 60, 120, 18));
    gfx.drawString('Agree to terms:', font,
        brush: black, bounds: const Rect.fromLTWH(40, 110, 120, 18));
    gfx.drawString('Signature:', font,
        brush: black, bounds: const Rect.fromLTWH(40, 170, 120, 18));

    // 1) Text field (with a default value so we can confirm values round-trip).
    final nameField = PdfTextBoxField(page, 'full_name',
        const Rect.fromLTWH(160, 56, 300, 24));
    nameField.text = 'Type here';
    doc.form.fields.add(nameField);

    // 2) Checkbox.
    final agreeField = PdfCheckBoxField(page, 'agree_terms',
        const Rect.fromLTWH(160, 108, 20, 20));
    doc.form.fields.add(agreeField);

    // 3) Signature field.
    final sigField = PdfSignatureField(page, 'signature',
        bounds: const Rect.fromLTWH(160, 166, 300, 60));
    doc.form.fields.add(sigField);

    final bytes = await doc.save();
    doc.dispose();

    final outPath = '${Directory.systemTemp.path}/acroform_spike.pdf';
    await File(outPath).writeAsBytes(bytes);

    // Programmatic sanity check: re-open and confirm 3 fields survived the save.
    final reopened = PdfDocument(inputBytes: bytes);
    final count = reopened.form.fields.count;
    reopened.dispose();

    // ignore: avoid_print
    print('\n=== ACROFORM SPIKE OUTPUT ===');
    // ignore: avoid_print
    print('Wrote: $outPath  (fields re-read: $count)');
    // ignore: avoid_print
    print('MANUAL: open it in Adobe Acrobat, Apple Preview, and Chrome.');
    // ignore: avoid_print
    print('Confirm all 3 fields are placed correctly and fillable.\n');

    expect(count, 3, reason: 'Saved AcroForm should contain 3 fields');
    expect(File(outPath).existsSync(), isTrue);
  });
}
