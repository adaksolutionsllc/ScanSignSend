import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/models/document_category.dart';
import 'package:scan_sign_send/core/services/document_titler.dart';
import 'package:scan_sign_send/core/services/keyword_categoriser.dart';
import 'package:scan_sign_send/core/services/page_layout.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';

PageLayout _pdfPage(String path, int page) {
  final (lines, aspect) = pdfTextLayout((path, page))!;
  return PageLayout(lines: lines, rules: const [], aspect: aspect);
}

String _text(PageLayout l) => l.lines.map((e) => e.text).join('\n');

void main() {
  group('titles from page 1', () {
    for (final (file, title) in [
      ('Rental_Application.pdf', 'Rental application'),
      ('Demande_de_location.pdf', 'Demande de location'),
      ('Solicitud_de_alquiler.pdf', 'Solicitud de alquiler'),
      ('Ficha_de_locacao.pdf', 'Ficha de locação'),
    ]) {
      test(file, () {
        final layout = _pdfPage('tool/store_capture/forms/$file', 0);
        expect(DocumentTitler.titleFrom(layout), title);
      });
    }

    test('the W-4 gets a title, not a label or a number', () {
      final t = DocumentTitler.titleFrom(
        _pdfPage('test/fixtures/irs_fw4_2026.pdf', 0),
      );
      expect(t, isNotNull);
      expect(t!.length, lessThanOrEqualTo(DocumentTitler.maxLength + 1));
    });

    test('a page where nothing stands out has no title', () {
      final line = LayoutLine(
        text: 'Plain body text only',
        box: Rect.fromLTRB(0.1, 0.1, 0.9, 0.12),
        words: [],
        fontSize: 0.012,
      );
      expect(
        DocumentTitler.titleFrom(
          PageLayout(lines: [line, line], rules: const [], aspect: 0.7),
        ),
        isNull,
      );
    });

    test('cleaning: caps, punctuation, length', () {
      expect(DocumentTitler.clean('RENTAL APPLICATION:'), 'Rental application');
      expect(DocumentTitler.clean('FORM W-9'), 'Form W-9');
      expect(
        DocumentTitler.clean('  — Patient Intake Form —  '),
        'Patient Intake Form',
      );
      final long = DocumentTitler.clean(
        'Request for Taxpayer Identification Number and Certification',
      );
      expect(long, 'Request for Taxpayer Identification…');
    });
  });

  group('keyword categories', () {
    for (final file in [
      'Rental_Application.pdf',
      'Demande_de_location.pdf',
      'Solicitud_de_alquiler.pdf',
      'Ficha_de_locacao.pdf',
    ]) {
      test('$file is Home & rental', () {
        final layout = _pdfPage('tool/store_capture/forms/$file', 0);
        final title = DocumentTitler.titleFrom(layout) ?? '';
        expect(
          KeywordCategoriser.classify(title, _text(layout)),
          BuiltInCategory.home,
          reason: '${KeywordCategoriser.scores(title, _text(layout))}',
        );
      });
    }

    test('the W-4 is Tax', () {
      final layout = _pdfPage('test/fixtures/irs_fw4_2026.pdf', 0);
      expect(
        KeywordCategoriser.classify('', _text(layout)),
        BuiltInCategory.tax,
        reason: '${KeywordCategoriser.scores('', _text(layout))}',
      );
    });

    for (final (title, text, want) in [
      (
        'Patient Intake Form',
        'Allergies. Current medications. Physician.',
        BuiltInCategory.medical,
      ),
      (
        'Fiche patient',
        'Médecin traitant. Allergies. Ordonnance.',
        BuiltInCategory.medical,
      ),
      (
        'Invoice #1043',
        'Subtotal 120.00 Tax 9.60 Amount due 129.60',
        BuiltInCategory.bills,
      ),
      (
        'Claim Form',
        'Policy number. Insured person. Date of loss.',
        BuiltInCategory.insurance,
      ),
      (
        'Field Trip Permission Slip',
        'Student name. Parent/guardian signature.',
        BuiltInCategory.school,
      ),
      (
        'Passport Application',
        'Place of birth. Nationality.',
        BuiltInCategory.idTravel,
      ),
      (
        'Employment Application',
        'Position applied for. Previous employer.',
        BuiltInCategory.work,
      ),
      (
        'Affidavit',
        'I hereby declare before the notary.',
        BuiltInCategory.legal,
      ),
      (
        'Account Opening Form',
        'KYC details. IFSC code. Account number.',
        BuiltInCategory.money,
      ),
      (
        'Form 16',
        'Certificate under section 203 of the Income-tax Act.',
        BuiltInCategory.tax,
      ),
    ]) {
      test('$title → ${want.name}', () {
        expect(
          KeywordCategoriser.classify(title, text),
          want,
          reason: '${KeywordCategoriser.scores(title, text)}',
        );
      });
    }

    test('weak or mixed evidence stays Uncategorised', () {
      expect(KeywordCategoriser.classify('', 'Total balance'), isNull);
      expect(
        KeywordCategoriser.classify('Notes', 'Meeting at the school bank'),
        isNull,
      );
      expect(KeywordCategoriser.classify('', ''), isNull);
      // A prose letter with no form vocabulary.
      expect(
        KeywordCategoriser.classify(
          'Dear friend',
          'Thank you for your help last week. See you soon.',
        ),
        isNull,
      );
    });

    test('accents and punctuation are ignored', () {
      expect(KeywordCategoriser.normalise('Impôt — W-9!'), 'impot w 9');
    });
  });
}
