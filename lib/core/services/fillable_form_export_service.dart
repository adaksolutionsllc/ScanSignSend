import 'dart:io';
import 'dart:ui' show Rect;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/field_model.dart';
import '../utils/path_resolver.dart';
import 'document_repository.dart';
import 'pdf_geometry.dart';

/// Thrown when an export is attempted on a document with no pages. Typed so
/// the UI can show a translated message.
class ExportEmptyDocumentException implements Exception {
  const ExportEmptyDocumentException();
  @override
  String toString() => 'ExportEmptyDocumentException';
}

final fillableFormExportServiceProvider =
    Provider<FillableFormExportService>((ref) {
  return FillableFormExportService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
  );
});

/// Exports a document as a **live AcroForm PDF** — fields stay interactive and
/// re-fillable in Adobe/Preview/Chrome. This is the "Save as Fillable Form"
/// exit, the counterpart to [PressService] (the "Flatten & Sign" exit).
///
/// Two source shapes are handled:
///   - **Imported PDF** whose pages are `"$path#page=N"` refs: we re-open the
///     original PDF and set values on its existing AcroForm widgets (matched by
///     `pdfFieldName`), preserving the real form.
///   - **Scanned pages** (image files): we build image-backed pages and add new
///     AcroForm widgets at each field's transformed bounds.
class FillableFormExportService {
  FillableFormExportService(this._docRepo, this._pageRepo, this._fieldRepo);
  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;

  /// Builds the fillable PDF and returns its path.
  Future<String> export(int docId) async {
    final doc = await _docRepo.getById(docId);
    if (doc == null) throw StateError('Document $docId not found');

    final pages = await _pageRepo.watchPages(docId).first;
    if (pages.isEmpty) {
      throw const ExportEmptyDocumentException();
    }
    final fields = await _fieldRepo.watchFields(docId).first;

    // Determine the source PDF (if this is an imported PDF, every page shares
    // the same underlying file via the `#page=` convention). Resolve to a
    // currently-valid absolute path here on the main isolate — the compute()
    // isolate has no initialised PathResolver.
    String? sourcePdfPath;
    for (final pg in pages) {
      if (pg.imagePath.contains('#page=')) {
        sourcePdfPath =
            PathResolver.resolve(pg.imagePath.split('#page=').first);
        break;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'fillable'));
    await outDir.create(recursive: true);
    final outPath = p.join(outDir.path, '${const Uuid().v4()}.pdf');

    final job = _ExportJob(
      outPath: outPath,
      sourcePdfPath: sourcePdfPath,
      pages: [
        for (final pg in pages)
          _PagePlan(imagePath: PathResolver.resolve(pg.imagePath)),
      ],
      fields: [
        for (final f in fields)
          _FieldPlan(
            pageIndex: f.pageIndex,
            type: f.type,
            boundingBoxJson: f.boundingBoxJson,
            // Signature values are file paths — resolve to the current
            // container here (the compute() isolate can't). See PressService.
            value: f.type == FieldType.signature.name && f.value.isNotEmpty
                ? PathResolver.resolve(f.value)
                : f.value,
            isChecked: f.isChecked,
            isFilled: f.isFilled,
            pdfFieldName: f.pdfFieldName,
            sourceKind: f.sourceKind,
          ),
      ],
    );

    await compute(_buildFillablePdf, job);

    await _docRepo.updateDocument(DocumentsCompanion(
      id: Value(docId),
      // Distinct status so the Library can show "Fillable" vs "Completed".
      status: const Value('fillable'),
      // Store container-relative so it survives reinstalls (see PathResolver).
      pressedPdfPath: Value(PathResolver.toStorable(outPath)),
      updatedAt: Value(DateTime.now()),
    ));

    return outPath;
  }
}

// ── Serializable job ────────────────────────────────────────────────────────

class _ExportJob {
  final String outPath;
  final String? sourcePdfPath;
  final List<_PagePlan> pages;
  final List<_FieldPlan> fields;
  const _ExportJob({
    required this.outPath,
    required this.sourcePdfPath,
    required this.pages,
    required this.fields,
  });
}

class _PagePlan {
  final String imagePath;
  const _PagePlan({required this.imagePath});
}

class _FieldPlan {
  final int pageIndex;
  final String type;
  final String boundingBoxJson;
  final String value;
  final bool isChecked;
  final bool isFilled;
  final String? pdfFieldName;
  final String sourceKind;
  const _FieldPlan({
    required this.pageIndex,
    required this.type,
    required this.boundingBoxJson,
    required this.value,
    required this.isChecked,
    required this.isFilled,
    required this.pdfFieldName,
    required this.sourceKind,
  });
}

// ── Isolate entry point ─────────────────────────────────────────────────────

Future<void> _buildFillablePdf(_ExportJob job) async {
  final PdfDocument pdfDoc;
  final bool imported = job.sourcePdfPath != null &&
      File(job.sourcePdfPath!).existsSync();

  if (imported) {
    // Re-open the original PDF so its real AcroForm is preserved.
    pdfDoc = PdfDocument(inputBytes: File(job.sourcePdfPath!).readAsBytesSync());
  } else {
    pdfDoc = PdfDocument();
  }

  try {
    // Stamp appearance streams for field values so filled text/checkboxes are
    // visible in viewers that don't honour NeedAppearances (Preview, Chrome).
    pdfDoc.form.setDefaultAppearance(true);

    if (imported) {
      _fillExistingForm(pdfDoc, job.fields);
      _addAppFieldsToLoadedPages(pdfDoc, job.fields);
      _drawSignaturesOnLoadedPages(pdfDoc, job.fields);
    } else {
      _buildImagePagesWithFields(pdfDoc, job);
    }

    final bytes = await pdfDoc.save();
    await File(job.outPath).writeAsBytes(bytes);
  } finally {
    pdfDoc.dispose();
  }
}

/// Sets values on the imported PDF's existing widgets, matched by name.
void _fillExistingForm(PdfDocument pdfDoc, List<_FieldPlan> fields) {
  final byName = <String, _FieldPlan>{
    for (final f in fields)
      if (f.sourceKind == 'acroform' && f.pdfFieldName != null)
        f.pdfFieldName!: f,
  };
  final form = pdfDoc.form;
  for (var i = 0; i < form.fields.count; i++) {
    final field = form.fields[i];
    final plan = byName[field.name];
    if (plan == null) continue;
    if (field is PdfTextBoxField) {
      field.text = plan.value;
    } else if (field is PdfCheckBoxField) {
      field.isChecked = plan.isChecked;
    } else if (field is PdfComboBoxField && plan.value.isNotEmpty) {
      field.selectedValue = plan.value;
    }
    // Signatures aren't AcroForm values — they're painted onto the page by
    // _drawSignaturesOnLoadedPages after this pass.
  }
}

/// Adds user-authored fields (sourceKind='app') as new widgets onto the already
/// loaded pages of an imported PDF.
void _addAppFieldsToLoadedPages(PdfDocument pdfDoc, List<_FieldPlan> fields) {
  for (final f in fields) {
    if (f.sourceKind != 'app') continue;
    if (f.pageIndex < 0 || f.pageIndex >= pdfDoc.pages.count) continue;
    final page = pdfDoc.pages[f.pageIndex];
    _addWidget(pdfDoc, page, f);
  }
}

/// Draws captured signatures onto imported-PDF pages. A drawn signature is an
/// image overlay, not an AcroForm value, so it's painted onto page graphics for
/// every signature field (app- and acroform-sourced alike).
void _drawSignaturesOnLoadedPages(PdfDocument pdfDoc, List<_FieldPlan> fields) {
  for (final f in fields) {
    if (f.type.toFieldType() != FieldType.signature) continue;
    if (!f.isFilled || f.value.isEmpty) continue;
    if (f.pageIndex < 0 || f.pageIndex >= pdfDoc.pages.count) continue;
    final page = pdfDoc.pages[f.pageIndex];
    final bbox = BoundingBox.fromJsonString(f.boundingBoxJson);
    final rect = PdfGeometry.normToPdf(bbox, page.size.width, page.size.height);
    _drawSignature(page.graphics, f.value, rect);
  }
}

/// Paints a signature image file into [rect], preserving aspect ratio.
void _drawSignature(PdfGraphics gfx, String path, Rect rect) {
  final file = File(path);
  if (!file.existsSync()) return;
  final bmp = PdfBitmap(file.readAsBytesSync());
  final iw = bmp.width.toDouble();
  final ih = bmp.height.toDouble();
  if (iw <= 0 || ih <= 0) return;
  final scale =
      (iw / rect.width > ih / rect.height) ? rect.width / iw : rect.height / ih;
  final dw = iw * scale;
  final dh = ih * scale;
  gfx.drawImage(
    bmp,
    Rect.fromLTWH(
      rect.left + (rect.width - dw) / 2,
      rect.top + (rect.height - dh) / 2,
      dw,
      dh,
    ),
  );
}

/// Builds image-backed pages (scanned docs) and adds every field as a widget.
void _buildImagePagesWithFields(PdfDocument pdfDoc, _ExportJob job) {
  final pw = PdfPageSize.a4.width;
  final ph = PdfPageSize.a4.height;

  for (var i = 0; i < job.pages.length; i++) {
    final plan = job.pages[i];
    final page = pdfDoc.pages.add();

    // Background image (scanned page).
    final file = File(plan.imagePath);
    if (!plan.imagePath.contains('#page=') && file.existsSync()) {
      final bmp = PdfBitmap(file.readAsBytesSync());
      final iw = bmp.width.toDouble();
      final ih = bmp.height.toDouble();
      if (iw > 0 && ih > 0) {
        final scale = (iw / pw > ih / ph) ? pw / iw : ph / ih;
        final dw = iw * scale;
        final dh = ih * scale;
        page.graphics
            .drawImage(bmp, Rect.fromLTWH((pw - dw) / 2, (ph - dh) / 2, dw, dh));
      }
    }

    for (final f in job.fields.where((f) => f.pageIndex == i)) {
      _addWidget(pdfDoc, page, f);
    }
  }
}

/// Creates a single live AcroForm widget for [f] on [page].
void _addWidget(PdfDocument pdfDoc, PdfPage page, _FieldPlan f) {
  final bbox = BoundingBox.fromJsonString(f.boundingBoxJson);
  final rect = PdfGeometry.normToPdf(bbox, page.size.width, page.size.height);
  final type = f.type.toFieldType();
  // Unique-ish name so multiple widgets don't collide in the AcroForm.
  final name = (f.pdfFieldName != null && f.pdfFieldName!.isNotEmpty)
      ? f.pdfFieldName!
      : '${type.name}_${page.hashCode}_${rect.left.toInt()}_${rect.top.toInt()}';

  switch (type) {
    case FieldType.text:
    case FieldType.date:
      final field = PdfTextBoxField(page, name, rect);
      if (f.value.isNotEmpty) field.text = f.value;
      pdfDoc.form.fields.add(field);
    case FieldType.checkbox:
      final field = PdfCheckBoxField(page, name, rect);
      field.isChecked = f.isChecked;
      pdfDoc.form.fields.add(field);
    case FieldType.signature:
      // A drawn signature is an image overlay, not an AcroForm value — paint it
      // onto the page rather than adding an empty signature widget.
      if (f.isFilled && f.value.isNotEmpty) {
        _drawSignature(page.graphics, f.value, rect);
      } else {
        pdfDoc.form.fields.add(PdfSignatureField(page, name, bounds: rect));
      }
  }
  // NOTE: a field's `isRequired` is persisted in our DB and used for in-app
  // validation, but this Syncfusion version exposes no setter to stamp the
  // AcroForm "required" flag into the PDF, so it isn't reflected in the export.
}
