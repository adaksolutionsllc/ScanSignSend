import 'dart:io';
import 'dart:ui' show Rect, Offset;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/field_model.dart';
import 'document_repository.dart';

final pressServiceProvider = Provider<PressService>((ref) {
  return PressService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
  );
});

class PressService {
  PressService(this._docRepo, this._pageRepo, this._fieldRepo);
  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;

  /// Flattens all pages + filled fields into a signed PDF.
  /// Returns the path to the pressed PDF.
  Future<String> press(int docId) async {
    final doc = await _docRepo.getById(docId);
    if (doc == null) throw StateError('Document $docId not found');

    final pages = await _pageRepo.watchPages(docId).first;
    final fields = await _fieldRepo.watchFields(docId).first;

    final pdfDoc = PdfDocument();
    final pw = PdfPageSize.a4.width;
    final ph = PdfPageSize.a4.height;

    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final srcPage = pages[pageIdx];
      final pageFields =
          fields.where((f) => f.pageIndex == pageIdx).toList();

      final pdfPage = pdfDoc.pages.add();
      final gfx = pdfPage.graphics;

      // Background: scan image
      if (!srcPage.imagePath.contains('#page=')) {
        final imgBytes = await File(srcPage.imagePath).readAsBytes();
        final bgImage = PdfBitmap(imgBytes);
        final iw = bgImage.width.toDouble();
        final ih = bgImage.height.toDouble();
        final scale = (iw / pw > ih / ph) ? pw / iw : ph / ih;
        final dw = iw * scale;
        final dh = ih * scale;
        gfx.drawImage(
          bgImage,
          Rect.fromLTWH((pw - dw) / 2, (ph - dh) / 2, dw, dh),
        );
      }

      // Overlay fields
      for (final field in pageFields) {
        if (!field.isFilled) continue;
        final bbox = BoundingBox.fromJsonString(field.boundingBoxJson);
        final rect = Rect.fromLTWH(
            bbox.x * pw, bbox.y * ph, bbox.w * pw, bbox.h * ph);
        final type = field.type.toFieldType();

        switch (type) {
          case FieldType.text:
          case FieldType.date:
            _drawText(gfx, field.value, rect);
          case FieldType.checkbox:
            if (field.isChecked) _drawCheckmark(gfx, rect);
          case FieldType.signature:
            if (field.value.isNotEmpty) {
              final f = File(field.value);
              if (f.existsSync()) {
                final img = PdfBitmap(await f.readAsBytes());
                gfx.drawImage(img, _fitRect(img, rect));
              }
            }
        }
      }
    }

    _appendCertPage(pdfDoc, doc.title);

    // Save pressed PDF
    final dir = await getApplicationDocumentsDirectory();
    final pressDir = Directory(p.join(dir.path, 'pressed'));
    await pressDir.create(recursive: true);
    final outPath = p.join(pressDir.path, '${const Uuid().v4()}.pdf');
    await File(outPath).writeAsBytes(await pdfDoc.save());
    pdfDoc.dispose();

    // Mark document as pressed
    await _docRepo.updateDocument(DocumentsCompanion(
      id: Value(docId),
      status: const Value('pressed'),
      pressedPdfPath: Value(outPath),
      updatedAt: Value(DateTime.now()),
    ));

    // Preserve blank original as template
    await _preserveTemplate(doc, pages, fields);

    return outPath;
  }

  // ── Drawing helpers ────────────────────────────────────────────────────────

  void _drawText(PdfGraphics gfx, String text, Rect rect) {
    gfx.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 11),
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: rect,
      format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
    );
  }

  void _drawCheckmark(PdfGraphics gfx, Rect rect) {
    gfx.drawString(
      '4', // Zapf Dingbats checkmark glyph
      PdfStandardFont(
          PdfFontFamily.zapfDingbats, rect.height * 0.8),
      brush: PdfSolidBrush(PdfColor(0, 120, 0)),
      bounds: rect,
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  Rect _fitRect(PdfBitmap img, Rect dest) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale =
        (iw / dest.width > ih / dest.height) ? dest.width / iw : dest.height / ih;
    final dw = iw * scale;
    final dh = ih * scale;
    return Rect.fromLTWH(
      dest.left + (dest.width - dw) / 2,
      dest.top + (dest.height - dh) / 2,
      dw,
      dh,
    );
  }

  void _appendCertPage(PdfDocument pdfDoc, String docTitle) {
    final page = pdfDoc.pages.add();
    final gfx = page.graphics;
    final pw = page.size.width;
    var y = 60.0;

    final bold = PdfStandardFont(PdfFontFamily.helvetica, 16,
        style: PdfFontStyle.bold);
    final body = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final black = PdfSolidBrush(PdfColor(0, 0, 0));
    final grey = PdfSolidBrush(PdfColor(120, 120, 120));

    gfx.drawString('Signing Certificate', bold,
        brush: black, bounds: Rect.fromLTWH(40, y, pw - 80, 30));
    y += 40;

    gfx.drawLine(PdfPen(PdfColor(200, 200, 200)),
        Offset(40, y), Offset(pw - 40, y));
    y += 16;

    final now = DateTime.now();
    for (final row in [
      ['Document', docTitle],
      ['Signed on', DateFormat('MMMM d, yyyy — h:mm a').format(now)],
      ['Method', 'On-device (Scan Sign Send)'],
      ['Note', 'Signatures captured locally. No cloud processing.'],
    ]) {
      gfx.drawString(row[0], body,
          brush: grey, bounds: Rect.fromLTWH(40, y, 120, 18));
      gfx.drawString(row[1], body,
          brush: black, bounds: Rect.fromLTWH(170, y, pw - 210, 18));
      y += 22;
    }
  }

  // ── Template preservation ──────────────────────────────────────────────────

  Future<void> _preserveTemplate(
    Document doc,
    List<Page> pages,
    List<Field> fields,
  ) async {
    final all = await _docRepo.watchAll().first;
    final templateTitle = '${doc.title} (Template)';
    if (all.any((d) => d.isTemplate && d.title == templateTitle)) return;

    final tmpl = await _docRepo.createDocument(templateTitle);
    await _docRepo.updateDocument(DocumentsCompanion(
      id: Value(tmpl.id),
      status: const Value('template'),
      isTemplate: const Value(true),
      pageCount: Value(doc.pageCount),
      updatedAt: Value(DateTime.now()),
    ));
    for (final pg in pages) {
      await _pageRepo.addPage(
          documentId: tmpl.id,
          pageIndex: pg.pageIndex,
          imagePath: pg.imagePath);
    }
    for (final f in fields) {
      await _fieldRepo.addField(FieldsCompanion.insert(
        documentId: tmpl.id,
        pageIndex: f.pageIndex,
        type: f.type,
        boundingBoxJson: f.boundingBoxJson,
        label: Value(f.label),
      ));
    }
  }
}
