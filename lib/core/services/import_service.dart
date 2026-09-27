import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/field_model.dart';
import 'document_repository.dart';
import 'pdf_geometry.dart';

/// Why an import failed. The service has no BuildContext, so it reports a
/// cause and the calling screen renders the localized message.
enum ImportFailure { unreadablePdf, emptyPdf, unreadableImage }

class ImportException implements Exception {
  ImportException(this.failure);
  final ImportFailure failure;
  @override
  String toString() => 'ImportException(${failure.name})';
}

/// Serializable intermediate for one parsed AcroForm widget.
class _ParsedField {
  final String pdfFieldName;
  final int pageIndex;
  final FieldType type;
  final BoundingBox bbox;
  final String label;
  final String value;
  final bool isChecked;
  final String? optionsJson;
  const _ParsedField({
    required this.pdfFieldName,
    required this.pageIndex,
    required this.type,
    required this.bbox,
    required this.label,
    required this.value,
    required this.isChecked,
    required this.optionsJson,
  });
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
  );
});

class ImportService {
  ImportService(this._docRepo, this._pageRepo, this._fieldRepo);

  /// Stored in `Documents.ocrText` when an imported PDF has its own AcroForm
  /// fields: they were imported as rows, so detection is skipped.
  static const formFieldsSentinel = '__has_form_fields__';

  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;
  final _uuid = const Uuid();

  /// Opens the system file picker and imports the selected file.
  /// Returns the created Document, or null if the user cancelled.
  Future<Document?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return null;

    final ext = p.extension(path).toLowerCase();
    try {
      if (ext == '.pdf') {
        return await _importPdf(path, file.name);
      } else {
        return await _importImage(path, file.name);
      }
    } finally {
      // The picker hands us a private copy in the app's temp folder; ours is
      // now under Documents, so don't leave a second copy of the user's
      // document lying around.
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}
    }
  }

  Future<Document> _importImage(String imagePath, String name) async {
    final id = _uuid.v4();
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pages', id));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, 'page_0.jpg');
    try {
      await _writeUprightJpeg(imagePath, dest);
    } catch (_) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      throw ImportException(ImportFailure.unreadableImage);
    }

    final title = p.basenameWithoutExtension(name);
    final docId = await _docRepo.transaction(() async {
      final doc = await _docRepo.createDocument(title);
      await _pageRepo.addPage(
        documentId: doc.id,
        pageIndex: 0,
        imagePath: dest,
      );
      await _docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(doc.id),
          pageCount: const Value(1),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return doc.id;
    });
    return (await _docRepo.getById(docId))!;
  }

  /// Re-encodes a picked photo as an upright JPEG.
  ///
  /// Phone photos are usually stored sideways with an EXIF "rotate me" tag.
  /// The screen honours that tag but the PDF engine and OCR do not, so the
  /// page used to press sideways and detected fields landed in the wrong
  /// place. HEIC, which iPhones shoot by default, can't be embedded in a PDF at
  /// all. Decoding through the platform codec fixes both: it understands HEIC
  /// and applies the EXIF rotation, so what gets stored is exactly what the
  /// user saw.
  Future<void> _writeUprightJpeg(String src, String dest) async {
    final bytes = await File(src).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    // Cap the long edge: a 48 MP photo decodes to ~190 MB of pixels, and
    // nothing downstream benefits from more than a sharp A4 scan.
    const maxEdge = 3000;
    final wide = descriptor.width >= descriptor.height;
    final tooBig = math.max(descriptor.width, descriptor.height) > maxEdge;
    final codec = await descriptor.instantiateCodec(
      targetWidth: tooBig && wide ? maxEdge : null,
      targetHeight: tooBig && !wide ? maxEdge : null,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw const FormatException('Undecodable image');
      final jpeg = await compute(_encodeRgbaJpeg, (
        rgba.buffer.asUint8List(),
        image.width,
        image.height,
      ));
      await File(dest).writeAsBytes(jpeg, flush: true);
    } finally {
      image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }

  /// Imports a PDF by copying it to app storage. Each page gets a DB row
  /// whose imagePath points to the PDF with a `#page=N` fragment so the
  /// viewer knows which page to display (0-indexed).
  Future<Document> _importPdf(String pdfPath, String name) async {
    final id = _uuid.v4();
    final dest = await _copyToAppDir(pdfPath, id);
    final title = p.basenameWithoutExtension(name);

    int pageCount;
    // Parsed AcroForm widgets, if any, captured while the doc is open.
    List<_ParsedField> parsedFields;
    try {
      // Parsed in a background isolate: a long PDF parsed on the UI thread
      // froze the app behind the "Importing…" spinner.
      (pageCount, parsedFields) = await compute(_parsePdf, dest);
    } catch (e) {
      // Corrupt / encrypted / password-protected PDF — clean up the copy so we
      // don't leave an unreadable file behind, then surface a clear message.
      try {
        await Directory(p.dirname(dest)).delete(recursive: true);
      } catch (_) {}
      throw ImportException(ImportFailure.unreadablePdf);
    }
    if (pageCount == 0) {
      try {
        await Directory(p.dirname(dest)).delete(recursive: true);
      } catch (_) {}
      throw ImportException(ImportFailure.emptyPdf);
    }

    final docId = await _docRepo.transaction(() async {
      final doc = await _docRepo.createDocument(title);
      for (var i = 0; i < pageCount; i++) {
        await _pageRepo.addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: '$dest#page=$i',
        );
      }

      // Persist any real AcroForm fields as rows the editor can fill directly.
      for (final f in parsedFields) {
        await _fieldRepo.addField(
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: f.pageIndex,
            type: f.type.name,
            boundingBoxJson: f.bbox.toJsonString(),
            label: Value(f.label),
            value: Value(f.value),
            isChecked: Value(f.isChecked),
            isFilled: Value(f.value.isNotEmpty || f.isChecked),
            pdfFieldName: Value(f.pdfFieldName),
            sourceKind: const Value('acroform'),
            optionsJson: Value(f.optionsJson),
          ),
        );
      }

      await _docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(doc.id),
          pageCount: Value(pageCount),
          updatedAt: Value(DateTime.now()),
          // Sentinel: skip the OCR auto-scan when the PDF already carries real form
          // fields — we imported those as rows above.
          ocrText: parsedFields.isNotEmpty
              ? const Value(formFieldsSentinel)
              : const Value(''),
        ),
      );
      return doc.id;
    });
    return (await _docRepo.getById(docId))!;
  }

  /// Reads supported AcroForm widgets from an open [pdfDoc] into a serializable
  /// intermediate, mapping each field's PDF-point bounds to our normalised box
  /// using that page's own point size. Unsupported field types are skipped
  /// (they still render in the background PDF view, just aren't editable yet).
  static List<_ParsedField> _parseFormFields(PdfDocument pdfDoc) {
    final out = <_ParsedField>[];
    final form = pdfDoc.form;
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      final page = field.page;
      if (page == null) continue;
      final pageIndex = pdfDoc.pages.indexOf(page);
      if (pageIndex < 0) continue;
      final pw = page.size.width;
      final ph = page.size.height;
      final bbox = PdfGeometry.pdfToNorm(field.bounds, pw, ph);

      FieldType type;
      var value = '';
      var isChecked = false;
      String? optionsJson;

      if (field is PdfTextBoxField) {
        type = FieldType.text;
        value = field.text;
      } else if (field is PdfCheckBoxField) {
        type = FieldType.checkbox;
        isChecked = field.isChecked;
      } else if (field is PdfSignatureField) {
        type = FieldType.signature;
      } else if (field is PdfComboBoxField) {
        type = FieldType.text; // fill as text; choices captured for later UI
        value = field.selectedValue;
        final items = <String>[];
        for (var j = 0; j < field.items.count; j++) {
          items.add(field.items[j].text);
        }
        if (items.isNotEmpty) optionsJson = jsonEncode(items);
      } else {
        // Unsupported (radio/list/button) for v1 fill — skip.
        continue;
      }

      out.add(
        _ParsedField(
          pdfFieldName: field.name ?? 'field_$i',
          pageIndex: pageIndex,
          type: type,
          bbox: bbox,
          label: field.name ?? '',
          value: value,
          isChecked: isChecked,
          optionsJson: optionsJson,
        ),
      );
    }
    return out;
  }

  Future<String> _copyToAppDir(String src, String id) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pages', id));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, p.basename(src));
    await File(src).copy(dest);
    return dest;
  }
}

/// compute() entry: raw RGBA pixels → JPEG bytes.
Uint8List _encodeRgbaJpeg((Uint8List, int, int) args) {
  final (rgba, w, h) = args;
  final image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 90);
}

/// compute() entry: page count and AcroForm fields of the PDF at [path].
/// Throws for an unreadable (corrupt / encrypted) file.
(int, List<_ParsedField>) _parsePdf(String path) {
  final pdfDoc = PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return (pdfDoc.pages.count, ImportService._parseFormFields(pdfDoc));
  } finally {
    pdfDoc.dispose();
  }
}
