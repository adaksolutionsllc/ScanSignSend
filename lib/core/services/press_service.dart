import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Rect, Offset;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/field_model.dart';
import '../utils/path_resolver.dart';
import 'pdf_geometry.dart';
import 'document_repository.dart';

/// Thrown when a press is attempted on a document with no pages. Typed so the
/// UI can show a translated message (this service has no BuildContext).
class PressEmptyDocumentException implements Exception {
  const PressEmptyDocumentException();
  @override
  String toString() => 'PressEmptyDocumentException';
}

final pressServiceProvider = Provider<PressService>((ref) {
  return PressService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
  );
});

/// Serializable description of one page to flatten. Passed into the background
/// isolate so no drift/Flutter types cross the isolate boundary.
class _PagePlan {
  final String imagePath; // may contain a '#page=N' fragment for PDF pages
  final String activeFilter; // 'original' | 'enhanced' | 'bw'
  final List<_FieldPlan> fields;
  const _PagePlan(this.imagePath, this.activeFilter, this.fields);
}

class _FieldPlan {
  final String type;
  final String boundingBoxJson;
  final String value;
  final bool isChecked;
  final bool isFilled;
  const _FieldPlan({
    required this.type,
    required this.boundingBoxJson,
    required this.value,
    required this.isChecked,
    required this.isFilled,
  });
}

class _PressJob {
  final List<_PagePlan> pages;
  final String docTitle;
  final String outPath;

  /// The signing time, already formatted for the user's locale. Formatted on
  /// the main isolate: a compute() isolate starts without intl's locale date
  /// data, so DateFormat there threw LocaleDataException for every locale
  /// but the built-in en_US.
  final String signedAt;

  /// Certificate-page copy, already translated. The isolate can't reach
  /// AppLocalizations, so the strings are resolved on the caller's side and
  /// travel with the job.
  final _CertStrings cert;

  /// The document's body text size (fraction of page height), or null.
  final double? textSize;
  const _PressJob(
    this.pages,
    this.docTitle,
    this.outPath,
    this.signedAt,
    this.cert,
    this.textSize,
  );
}

/// Translated labels for the signing certificate appended to every press.
class PressCertificateStrings {
  const PressCertificateStrings({
    required this.title,
    required this.documentLabel,
    required this.signedOnLabel,
    required this.methodLabel,
    required this.methodValue,
    required this.noteLabel,
    required this.noteValue,
    required this.dateFormat,
    required this.localeName,
  });
  final String title;
  final String documentLabel;
  final String signedOnLabel;
  final String methodLabel;
  final String methodValue;
  final String noteLabel;
  final String noteValue;
  final String dateFormat;
  final String localeName;
}

typedef _CertStrings = PressCertificateStrings;

class PressService {
  PressService(this._docRepo, this._pageRepo, this._fieldRepo);
  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;

  /// Flattens all pages + filled fields into a signed PDF.
  /// Returns the path to the pressed PDF.
  ///
  /// The PDF assembly (image decode, page import, save) is CPU-heavy, so it
  /// runs in a background isolate via [compute] to keep the UI responsive.
  Future<String> press(int docId, PressCertificateStrings cert) async {
    final doc = await _docRepo.getById(docId);
    if (doc == null) throw StateError('Document $docId not found');

    final pages = await _pageRepo.watchPages(docId).first;
    if (pages.isEmpty) {
      throw const PressEmptyDocumentException();
    }
    final fields = await _fieldRepo.watchFields(docId).first;

    // Build a fully-serializable job so the heavy work can run off the UI
    // isolate. Drift row objects are not sendable, so we flatten them here.
    final pagePlans = <_PagePlan>[];
    for (var pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      final srcPage = pages[pageIdx];
      final pageFields = fields
          .where((f) => f.pageIndex == pageIdx && f.isFilled)
          .map(
            (f) => _FieldPlan(
              type: f.type,
              boundingBoxJson: f.boundingBoxJson,
              // Signature values are file paths — resolve to the current
              // container here (the compute() isolate can't).
              value: f.type.toFieldType().isInk && f.value.isNotEmpty
                  ? PathResolver.resolve(f.value)
                  : f.value,
              isChecked: f.isChecked,
              isFilled: f.isFilled,
            ),
          )
          .toList();
      pagePlans.add(
        _PagePlan(
          PathResolver.resolve(srcPage.imagePath),
          srcPage.activeFilter,
          pageFields,
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final pressDir = Directory(p.join(dir.path, 'pressed'));
    await pressDir.create(recursive: true);
    final outPath = p.join(pressDir.path, '${const Uuid().v4()}.pdf');

    final signedAt = DateFormat(
      cert.dateFormat,
      cert.localeName,
    ).format(DateTime.now());
    final job = _PressJob(
      pagePlans,
      doc.title,
      outPath,
      signedAt,
      cert,
      doc.textSize,
    );

    // Run the flatten in a background isolate. compute() re-throws any error
    // on the caller side, so failures surface to the UI as normal.
    await compute(_buildPressedPdf, job);

    // Mark document as pressed
    await _docRepo.updateDocument(
      DocumentsCompanion(
        id: Value(docId),
        status: const Value('pressed'),
        pressedPdfPath: Value(PathResolver.toStorable(outPath)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // NOTE: Flatten & Press no longer auto-saves a blank template copy — that
    // was creating unwanted duplicate entries. Users who want a reusable blank
    // should use "Save as Fillable Form" or an explicit template action.

    return outPath;
  }
}

// ── Isolate entry point ────────────────────────────────────────────────────────
//
// Everything below runs inside the compute() isolate. It must not touch drift,
// Riverpod, or any Flutter binding — only pure Dart + the pdf/image packages.

Future<void> _buildPressedPdf(_PressJob job) async {
  final pdfDoc = PdfDocument();
  // Every page of an imported PDF points at the *same* file via `#page=N`.
  // Opening it once per page re-read and re-parsed the whole document N times
  // — quadratic work and N peak-sized allocations on a 20-page import. Keep
  // each source open for the run instead, and dispose them together.
  final sourceCache = <String, PdfDocument?>{};
  try {
    for (final plan in job.pages) {
      // An imported page keeps its own size (a US Letter form stays Letter);
      // scans go on A4.
      final size = outputPageSize(
        plan.imagePath,
        (path) => _openSource(path, sourceCache),
      );
      final pw = size.width, ph = size.height;
      final pdfPage = addEdgeToEdgePage(pdfDoc, size);
      final gfx = pdfPage.graphics;

      // Fields are normalised to the page *content*; place them in the rect
      // the content landed in (the whole page for an imported page, the
      // letterboxed image for a scan).
      final content =
          await _drawBackground(gfx, plan, pw, ph, sourceCache) ??
          Rect.fromLTWH(0, 0, pw, ph);
      _drawFields(gfx, plan.fields, content, job.textSize);
    }

    _appendCertPage(pdfDoc, job.docTitle, job.signedAt, job.cert);

    final bytes = await pdfDoc.save();
    await File(job.outPath).writeAsBytes(bytes);
  } finally {
    // Always release native buffers even if save/draw throws.
    for (final src in sourceCache.values) {
      src?.dispose();
    }
    pdfDoc.dispose();
  }
}

/// Opens [pdfPath] once and memoises the result (including a null for an
/// unreadable file, so a broken source isn't retried on every page).
PdfDocument? _openSource(String pdfPath, Map<String, PdfDocument?> cache) {
  if (cache.containsKey(pdfPath)) return cache[pdfPath];
  PdfDocument? doc;
  try {
    final file = File(pdfPath);
    if (file.existsSync()) {
      doc = PdfDocument(inputBytes: file.readAsBytesSync());
    }
  } catch (_) {
    doc = null;
  }
  cache[pdfPath] = doc;
  return doc;
}

/// Draws the page content fitted (contain, centred) onto the A4 sheet and
/// returns the rect it occupies, or null when there was nothing to draw.
Future<Rect?> _drawBackground(
  PdfGraphics gfx,
  _PagePlan plan,
  double pw,
  double ph,
  Map<String, PdfDocument?> sourceCache,
) async {
  final path = plan.imagePath;

  // Imported-PDF page: import the source page as a vector template so its
  // real content is preserved (previously these pressed to a blank page).
  if (path.contains('#page=')) {
    final parts = path.split('#page=');
    final pdfPath = parts[0];
    final pageNum = int.tryParse(parts[1]) ?? 0; // 0-indexed in our model
    try {
      final src = _openSource(pdfPath, sourceCache);
      if (src == null) return null;
      if (pageNum < 0 || pageNum >= src.pages.count) return null;
      final template = src.pages[pageNum].createTemplate();
      // Scale the source page to fit the A4 output while preserving aspect.
      final tw = template.size.width;
      final th = template.size.height;
      if (tw <= 0 || th <= 0) return null;
      final scale = (tw / pw > th / ph) ? pw / tw : ph / th;
      final dw = tw * scale;
      final dh = th * scale;
      final dest = Rect.fromLTWH((pw - dw) / 2, (ph - dh) / 2, dw, dh);
      gfx.drawPdfTemplate(template, dest.topLeft, dest.size);
      return dest;
    } catch (_) {
      // Unreadable source page — leave the background blank rather than crash
      // the whole press. Overlays still render on top.
      return null;
    }
  }

  // Scanned image page: apply the user's chosen filter, then draw.
  final imgFile = File(path);
  if (!imgFile.existsSync()) return null;
  final rawBytes = await imgFile.readAsBytes();
  final processed = _applyFilter(rawBytes, plan.activeFilter);
  final bgImage = PdfBitmap(processed);
  final iw = bgImage.width.toDouble();
  final ih = bgImage.height.toDouble();
  if (iw <= 0 || ih <= 0) return null;
  final scale = (iw / pw > ih / ph) ? pw / iw : ph / ih;
  final dw = iw * scale;
  final dh = ih * scale;
  final dest = Rect.fromLTWH((pw - dw) / 2, (ph - dh) / 2, dw, dh);
  gfx.drawImage(bgImage, dest);
  return dest;
}

/// Applies the Review-screen filter to the raw image bytes so the pressed PDF
/// matches what the user previewed. Returns JPEG bytes. On any decode failure
/// it returns the original bytes unchanged.
Uint8List _applyFilter(Uint8List rawBytes, String filter) {
  if (filter == 'original') return rawBytes;
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    final img.Image out;
    switch (filter) {
      case 'bw':
        out = img.grayscale(decoded);
      case 'enhanced':
        // Mild contrast/brightness lift — mirrors the on-screen ColorFilter.
        out = img.adjustColor(decoded, contrast: 1.2, brightness: 1.02);
      default:
        return rawBytes;
    }
    return img.encodeJpg(out, quality: 90);
  } catch (_) {
    return rawBytes;
  }
}

void _drawFields(
  PdfGraphics gfx,
  List<_FieldPlan> fields,
  Rect content,
  double? textSize,
) {
  for (final field in fields) {
    if (!field.isFilled) continue;
    final rect = BoundingBox.fromJsonString(
      field.boundingBoxJson,
    ).inPageRect(content);
    final type = field.type.toFieldType();

    switch (type) {
      case FieldType.text:
      case FieldType.date:
        _drawText(
          gfx,
          field.value,
          rect,
          textSize == null ? null : textSize * content.height,
        );
      case FieldType.checkbox:
        if (field.isChecked) _drawCheckmark(gfx, rect);
      case FieldType.radio:
        // Only the chosen option is marked; the rest of the group stays blank,
        // just as on a paper form.
        if (field.isChecked) _drawRadioDot(gfx, rect);
      case FieldType.signature:
      case FieldType.initials:
        if (field.value.isNotEmpty) {
          final f = File(field.value);
          if (f.existsSync()) {
            final img = PdfBitmap(f.readAsBytesSync());
            gfx.drawImage(img, _fitRect(img, rect));
          }
        }
    }
  }
}

void _drawText(PdfGraphics gfx, String text, Rect rect, double? preferredPt) {
  gfx.drawString(
    text,
    fittedFont(text, rect, preferredPt: preferredPt),
    brush: PdfSolidBrush(PdfColor(0, 0, 0)),
    bounds: rect,
    format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
  );
}

void _drawRadioDot(PdfGraphics gfx, Rect rect) {
  final d = math.min(rect.width, rect.height) * 0.55;
  gfx.drawEllipse(
    Rect.fromCenter(center: rect.center, width: d, height: d),
    brush: PdfSolidBrush(PdfColor(0, 0, 0)),
  );
}

void _drawCheckmark(PdfGraphics gfx, Rect rect) {
  gfx.drawString(
    '4', // Zapf Dingbats checkmark glyph
    PdfStandardFont(PdfFontFamily.zapfDingbats, rect.height * 0.8),
    brush: PdfSolidBrush(PdfColor(0, 120, 0)),
    bounds: rect,
    format: PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    ),
  );
}

Rect _fitRect(PdfBitmap image, Rect dest) {
  final iw = image.width.toDouble();
  final ih = image.height.toDouble();
  final scale = (iw / dest.width > ih / dest.height)
      ? dest.width / iw
      : dest.height / ih;
  final dw = iw * scale;
  final dh = ih * scale;
  return Rect.fromLTWH(
    dest.left + (dest.width - dw) / 2,
    dest.top + (dest.height - dh) / 2,
    dw,
    dh,
  );
}

void _appendCertPage(
  PdfDocument pdfDoc,
  String docTitle,
  String signedAt,
  _CertStrings cert,
) {
  final page = addEdgeToEdgePage(pdfDoc, PdfPageSize.a4);
  final gfx = page.graphics;
  final pw = page.size.width;
  var y = 60.0;

  final bold = PdfStandardFont(
    PdfFontFamily.helvetica,
    16,
    style: PdfFontStyle.bold,
  );
  final body = PdfStandardFont(PdfFontFamily.helvetica, 11);
  final black = PdfSolidBrush(PdfColor(0, 0, 0));
  final grey = PdfSolidBrush(PdfColor(120, 120, 120));

  gfx.drawString(
    cert.title,
    bold,
    brush: black,
    bounds: Rect.fromLTWH(40, y, pw - 80, 30),
  );
  y += 40;

  gfx.drawLine(
    PdfPen(PdfColor(200, 200, 200)),
    Offset(40, y),
    Offset(pw - 40, y),
  );
  y += 16;

  for (final row in [
    [cert.documentLabel, docTitle],
    [cert.signedOnLabel, signedAt],
    [cert.methodLabel, cert.methodValue],
    [cert.noteLabel, cert.noteValue],
  ]) {
    gfx.drawString(
      row[0],
      body,
      brush: grey,
      bounds: Rect.fromLTWH(40, y, 120, 18),
    );
    gfx.drawString(
      row[1],
      body,
      brush: black,
      bounds: Rect.fromLTWH(170, y, pw - 210, 18),
    );
    y += 22;
  }
}

/// Helvetica for a field value: the document's own text size when known
/// ([preferredPt], so filled text matches the printed form), otherwise ~70% of
/// the field's height; never taller than the field, shrunk until the text
/// fits its width, and never below 5pt.
PdfFont fittedFont(String text, Rect rect, {double? preferredPt}) {
  // Without a measured text size, size to the field but no bigger than
  // ordinary form text: a user-drawn tall box shouldn't produce 60pt digits.
  var size = (preferredPt ?? math.min(rect.height * 0.7, 12.0))
      .clamp(5.0, math.max(5.0, rect.height * 0.9))
      .toDouble();
  var font = PdfStandardFont(PdfFontFamily.helvetica, size);
  while (size > 5 && font.measureString(text).width > rect.width - 2) {
    size -= 0.5;
    font = PdfStandardFont(PdfFontFamily.helvetica, size);
  }
  return font;
}
