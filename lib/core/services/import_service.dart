import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show compute, debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/field_model.dart';
import '../utils/path_resolver.dart';
import 'acroform_labels.dart';
import 'document_repository.dart';
import 'opened_file_service.dart';
import 'page_layout.dart';
import 'page_layout_service.dart';
import 'pdf_geometry.dart';

/// Why an import failed. The service has no BuildContext, so it reports a
/// cause and the calling screen renders the localized message.
enum ImportFailure {
  unreadablePdf,
  emptyPdf,
  unreadableImage,

  /// A PDF chosen together with other files: one PDF, or photos only.
  mixedSelection,
}

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
  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;
  final _uuid = const Uuid();

  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.heif'};

  static bool isImageFile(String path) =>
      _imageExtensions.contains(p.extension(path).toLowerCase());

  /// Opens the system file picker and imports the selection: one PDF, or one
  /// or more photos (which become the pages of one document, in the order
  /// picked). Returns the created Document, or null if the user cancelled.
  Future<Document?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final files = [
      for (final f in result.files)
        if (f.path != null) OpenedFile(path: f.path!, name: f.name),
    ];
    if (files.isEmpty) return null;
    try {
      return await _importSelection(files);
    } finally {
      // The picker hands us a private copy in the app's temp folder; ours is
      // now under Documents, so don't leave a second copy of the user's
      // document lying around.
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}
    }
  }

  /// Imports files opened with the app from another app (see
  /// OpenedFileService) — one PDF, or a group of photos as one document —
  /// then deletes the temporary copies they arrived as.
  Future<Document> importOpened(List<OpenedFile> files) async {
    try {
      return await _importSelection(files);
    } finally {
      for (final f in files) {
        try {
          await Directory(p.dirname(f.path)).delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<Document> _importSelection(List<OpenedFile> files) async {
    if (files.length == 1 && !isImageFile(files.single.path)) {
      return _importPdf(files.single.path, files.single.name);
    }
    if (!files.every((f) => isImageFile(f.path))) {
      throw ImportException(ImportFailure.mixedSelection);
    }
    return _importImages(files);
  }

  Future<Document> _importImages(List<OpenedFile> files) async {
    final id = _uuid.v4();
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pages', id));
    await dir.create(recursive: true);
    final dests = <String>[];
    try {
      for (var i = 0; i < files.length; i++) {
        final dest = p.join(dir.path, 'page_$i.jpg');
        await _writeUprightJpeg(files[i].path, dest);
        dests.add(dest);
      }
    } catch (_) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      throw ImportException(ImportFailure.unreadableImage);
    }

    final title = p.basenameWithoutExtension(files.first.name);
    final docId = await _docRepo.transaction(() async {
      final doc = await _docRepo.createDocument(title);
      for (var i = 0; i < dests.length; i++) {
        await _pageRepo.addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: dests[i],
        );
      }
      await _docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(doc.id),
          pageCount: Value(dests.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return doc.id;
    });
    return (await _docRepo.getById(docId))!;
  }

  /// Lets the user pick photos to add to a document. Returns them in the
  /// order picked; empty when cancelled.
  Future<List<OpenedFile>> pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    return [
      for (final f in result?.files ?? const <PlatformFile>[])
        if (f.path != null) OpenedFile(path: f.path!, name: f.name),
    ];
  }

  /// Appends photos to document [docId] as new last pages, upright and as
  /// JPEG like an imported photo. Returns the new pages' ids, in order.
  Future<List<int>> appendPhotos(int docId, List<OpenedFile> files) async {
    try {
      return await _append(docId, files.length, (i, dest) async {
        await _writeUprightJpeg(files[i].path, dest);
      });
    } on ImportException {
      rethrow;
    } catch (_) {
      throw ImportException(ImportFailure.unreadableImage);
    } finally {
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}
    }
  }

  /// Appends pages from the document scanner (temporary files, removed once
  /// copied) to document [docId]. Returns the new pages' ids, in order.
  Future<List<int>> appendScans(int docId, List<String> tempPaths) =>
      _append(docId, tempPaths.length, (i, dest) async {
        final src = File(tempPaths[i]);
        await src.copy(dest);
        try {
          await src.delete();
        } catch (_) {}
      });

  /// Writes [count] page files into a new `pages/<uuid>/` folder with
  /// [write], then adds their rows after the document's last page and
  /// updates its page count, in one transaction. Fields stay where they are:
  /// the existing pages keep their positions.
  Future<List<int>> _append(
    int docId,
    int count,
    Future<void> Function(int i, String dest) write,
  ) async {
    if (count == 0) return const [];
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pages', _uuid.v4()));
    await dir.create(recursive: true);
    final dests = <String>[];
    try {
      for (var i = 0; i < count; i++) {
        final dest = p.join(dir.path, 'page_$i.jpg');
        await write(i, dest);
        dests.add(dest);
      }
    } catch (_) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
    return _docRepo.transaction(() async {
      final first = (await _pageRepo.pagesOf(docId)).length;
      final ids = <int>[];
      for (var i = 0; i < dests.length; i++) {
        ids.add(
          await _pageRepo.addPage(
            documentId: docId,
            pageIndex: first + i,
            imagePath: dests[i],
          ),
        );
      }
      await _docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(docId),
          pageCount: Value(first + dests.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return ids;
    });
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
          // Skip the OCR auto-scan when the PDF already carries real form
          // fields — we imported those as rows above.
          hasFormFields: Value(parsedFields.isNotEmpty),
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
    // Each page's text layer, read once and only for pages with fields: the
    // printed captions are what the fields are labelled by.
    final text = <int, List<LayoutLine>>{};
    List<LayoutLine> textOf(int page) =>
        text[page] ??= pdfTextLayoutOf(pdfDoc, page)?.$1 ?? const [];
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
          label: AcroformLabels.label(
            type: type,
            box: bbox,
            lines: textOf(pageIndex),
            tooltip: _tooltipOf(field),
            name: field.name,
          ),
          value: value,
          isChecked: isChecked,
          optionsJson: optionsJson,
        ),
      );
    }
    return out;
  }

  /// Relabels form fields imported before labels came from the page: they
  /// show internal names like "topmostSubform[0].Page1[0].f1_01[0]". Runs
  /// once per such document (a relabelled field no longer matches), in the
  /// background; a document that can't be read keeps its labels.
  Future<void> relabelLegacyAcroforms() async {
    try {
      final stale = await _fieldRepo.acroformFieldsWithRawLabels();
      final byDoc = <int, List<Field>>{};
      for (final f in stale) {
        (byDoc[f.documentId] ??= []).add(f);
      }
      for (final MapEntry(key: docId, value: fields) in byDoc.entries) {
        final pages = await _pageRepo.watchPages(docId).first;
        if (pages.isEmpty || !pages.first.imagePath.contains('#page=')) {
          continue;
        }
        final pdf = PathResolver.resolve(
          pages.first.imagePath.split('#page=').first,
        );
        final labels = await compute(_relabel, (
          pdf,
          [
            for (final f in fields)
              (
                f.id,
                f.pdfFieldName ?? '',
                f.pageIndex,
                f.type,
                f.boundingBoxJson,
              ),
          ],
        ));
        for (final MapEntry(key: id, value: label) in labels.entries) {
          await _fieldRepo.updateField(
            FieldsCompanion(id: Value(id), label: Value(label)),
          );
        }
      }
    } catch (e) {
      debugPrint('Form field labels not refreshed: $e');
    }
  }

  /// The form fields of the PDF at [path] as import labels them:
  /// (internal name, label). For tests.
  @visibleForTesting
  static List<(String, String)> formFieldLabels(String path) => [
    for (final f in _parsePdf(path).$2) (f.pdfFieldName, f.label),
  ];

  static String? _tooltipOf(PdfField field) {
    try {
      return field.tooltip;
    } catch (_) {
      return null; // a malformed /TU must not fail the import
    }
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
/// compute() entry for [ImportService.relabelLegacyAcroforms]: field id →
/// new label, for the fields of the PDF at `args.$1`.
Map<int, String> _relabel(
  (String, List<(int, String, int, String, String)>) args,
) {
  final (path, fields) = args;
  final pdfDoc = PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    final byName = <String, PdfField>{};
    for (var i = 0; i < pdfDoc.form.fields.count; i++) {
      final f = pdfDoc.form.fields[i];
      if (f.name != null) byName[f.name!] = f;
    }
    final text = <int, List<LayoutLine>>{};
    return {
      for (final (id, name, page, type, box) in fields)
        id: AcroformLabels.label(
          type: type.toFieldType(),
          box: BoundingBox.fromJsonString(box),
          lines: text[page] ??= pdfTextLayoutOf(pdfDoc, page)?.$1 ?? const [],
          tooltip: byName[name] == null
              ? null
              : ImportService._tooltipOf(byName[name]!),
          name: name,
        ),
    };
  } finally {
    pdfDoc.dispose();
  }
}

(int, List<_ParsedField>) _parsePdf(String path) {
  final pdfDoc = PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return (pdfDoc.pages.count, ImportService._parseFormFields(pdfDoc));
  } finally {
    pdfDoc.dispose();
  }
}
