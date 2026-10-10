// A PDF's own form fields are labelled the way a person reads the form —
// from the tooltip, or the caption printed beside the field — never with the
// internal name ("topmostSubform[0].Page1[0].Step1a[0].f1_01[0]").
//
// fixtures/irs_fw4_2026.pdf is the IRS Form W-4 (2026) from irs.gov, a US
// government work in the public domain: it has no tooltips, so every label
// must come from the page.

import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/import_service.dart';
import 'package:scan_sign_send/core/services/pdf_geometry.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _w4 = 'test/fixtures/irs_fw4_2026.pdf';

Map<String, String> _labels(String path) => {
  for (final (name, label) in ImportService.formFieldLabels(path))
    name.split('.').last: label,
};

void main() {
  group('IRS W-4 (no tooltips)', () {
    late Map<String, String> labels;
    setUpAll(() => labels = _labels(_w4));

    test('Step 1: captions printed above each box', () {
      expect(labels['f1_01[0]'], 'First name and middle initial');
      expect(labels['f1_02[0]'], 'Last name');
      expect(labels['f1_03[0]'], 'Address');
      expect(labels['f1_04[0]'], 'City or town, state, and ZIP code');
      expect(labels['f1_05[0]'], 'Social security number');
    });

    test('filing status: the text right of each checkbox, minus asides', () {
      expect(labels['c1_1[0]'], 'Single or Married filing separately');
      expect(
        labels['c1_1[1]'],
        'Married filing jointly or Qualifying surviving spouse',
      );
      expect(labels['c1_1[2]'], 'Head of household');
    });

    test('amount lines: the line number and its description', () {
      expect(
        labels['f1_06[0]'],
        '3(a) Multiply the number of qualifying children',
      );
      expect(labels['f1_11[0]'], '4(c) Extra withholding');
      expect(labels['f4_02[0]'], '1b Qualified overtime compensation');
      expect(labels['f4_19[0]'], '11 Standard deduction');
    });

    test('employer section and two-line captions', () {
      expect(labels['f1_12[0]'], 'Employer’s name and address');
      expect(labels['f1_13[0]'], 'First date of employment');
      expect(labels['f1_14[0]'], 'Employer identification number (EIN)');
    });

    test('no label is an internal name or a sentence fragment', () {
      for (final MapEntry(key: name, value: label) in labels.entries) {
        expect(label, isNot(contains('[0]')), reason: name);
        expect(label, isNot(contains('Subform')), reason: name);
        expect(
          label,
          isNot(matches(RegExp(r'^[a-z(]'))),
          reason: '$name: $label',
        );
      }
    });
  });

  group('generated form', () {
    late String path;
    setUpAll(() {
      final doc = PdfDocument();
      doc.pageSettings.size = const Size(612, 792);
      doc.pageSettings.margins.all = 0;
      final page = doc.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      void text(String s, double x, double y) => page.graphics.drawString(
        s,
        font,
        bounds: Rect.fromLTWH(x, y, 300, 14),
      );

      text('Full Name:', 72, 100);
      doc.form.fields.add(
        PdfTextBoxField(page, 'f1_01', const Rect.fromLTWH(130, 98, 200, 16)),
      );
      text('Date of birth', 72, 140);
      doc.form.fields.add(
        PdfTextBoxField(page, 'f1_02', const Rect.fromLTWH(72, 154, 150, 16)),
      );
      doc.form.fields.add(
        PdfCheckBoxField(page, 'c1_01', const Rect.fromLTWH(72, 200, 10, 10)),
      );
      text('I agree to the terms', 86, 198);
      final tipped = PdfTextBoxField(
        page,
        'Text7',
        const Rect.fromLTWH(72, 300, 200, 16),
      )..tooltip = 'Applicant email';
      doc.form.fields.add(tipped);
      doc.form.fields.add(
        PdfTextBoxField(
          page,
          'EmployerName',
          const Rect.fromLTWH(72, 400, 200, 16),
        ),
      );
      doc.form.fields.add(
        PdfTextBoxField(page, 'f9_99', const Rect.fromLTWH(72, 500, 200, 16)),
      );
      path =
          '${Directory.systemTemp.path}/sss_acro_${DateTime.now().microsecondsSinceEpoch}.pdf';
      File(path).writeAsBytesSync(doc.saveSync());
      doc.dispose();
    });
    tearDownAll(() => File(path).deleteSync());

    test('each source of a label, in order', () {
      final labels = _labels(path);
      expect(labels['f1_01'], 'Full Name', reason: 'label right before it');
      expect(labels['f1_02'], 'Date of birth', reason: 'caption above it');
      expect(labels['c1_01'], 'I agree to the terms', reason: 'right of box');
      expect(labels['Text7'], 'Applicant email', reason: 'tooltip wins');
      expect(labels['EmployerName'], 'Employer name', reason: 'readable name');
      expect(
        labels['f9_99'],
        '',
        reason: 'generated name: the UI shows the type',
      );
    });
  });

  test('forms imported before readable labels are relabelled once', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final docs = DocumentRepository(db);
    final pages = PageRepository(db);
    final fieldRepo = FieldRepository(db);

    // The W-4's first field as 1.0 stored it: label = internal name.
    final w4 = PdfDocument(inputBytes: File(_w4).readAsBytesSync());
    final field = w4.form.fields[0];
    final box = PdfGeometry.pdfToNorm(
      field.bounds,
      field.page!.size.width,
      field.page!.size.height,
    );
    final rawName = field.name!;
    w4.dispose();

    final doc = await docs.createDocument('fw4');
    await pages.addPage(
      documentId: doc.id,
      pageIndex: 0,
      imagePath: '${File(_w4).absolute.path}#page=0',
    );
    Future<int> add(String label) => fieldRepo.addField(
      FieldsCompanion.insert(
        documentId: doc.id,
        pageIndex: 0,
        type: FieldType.text.name,
        boundingBoxJson: box.toJsonString(),
        label: Value(label),
        pdfFieldName: Value(rawName),
        sourceKind: const Value('acroform'),
      ),
    );
    final stale = await add(rawName);
    final renamed = await add('My own name for it'); // the user's: kept

    final service = ImportService(docs, pages, fieldRepo);
    await service.relabelLegacyAcroforms();

    final after = {
      for (final f in await fieldRepo.watchFields(doc.id).first) f.id: f,
    };
    expect(after[stale]!.label, 'First name and middle initial');
    expect(after[stale]!.pdfFieldName, rawName, reason: 'export still matches');
    expect(after[renamed]!.label, 'My own name for it');
    expect(await fieldRepo.acroformFieldsWithRawLabels(), isEmpty);
  });
}
