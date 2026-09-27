import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
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

final fillableFormExportServiceProvider = Provider<FillableFormExportService>((
  ref,
) {
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
        sourcePdfPath = PathResolver.resolve(
          pg.imagePath.split('#page=').first,
        );
        break;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'fillable'));
    await outDir.create(recursive: true);
    final outPath = p.join(outDir.path, '${const Uuid().v4()}.pdf');

    // Fonts for Hindi / Tamil / Telugu values, loaded here: the export
    // isolate can't reach the asset bundle.
    final fonts = <String, Uint8List>{};
    for (final f in fields) {
      final script = _scriptOf(f.value);
      if (script == null || fonts.containsKey(script)) continue;
      final data = await rootBundle.load(_scriptFonts[script]!);
      fonts[script] = data.buffer.asUint8List();
    }

    final job = _ExportJob(
      textSize: doc.textSize,
      fonts: fonts,
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
            value: f.type.toFieldType().isInk && f.value.isNotEmpty
                ? PathResolver.resolve(f.value)
                : f.value,
            isChecked: f.isChecked,
            isFilled: f.isFilled,
            pdfFieldName: f.pdfFieldName,
            sourceKind: f.sourceKind,
            optionsJson: f.optionsJson,
          ),
      ],
    );

    await compute(_buildFillablePdf, job);

    // This is a shareable snapshot, not a lock: `status`/`pressedPdfPath` are
    // deliberately untouched so the document stays reachable through fill/
    // sign/press. Only PressService.press() (flatten & sign) locks a document.
    await _docRepo.updateDocument(
      DocumentsCompanion(
        id: Value(docId),
        // Store container-relative so it survives reinstalls (see PathResolver).
        fillablePdfPath: Value(PathResolver.toStorable(outPath)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return outPath;
  }
}

// ── Serializable job ────────────────────────────────────────────────────────

class _ExportJob {
  /// The document's body text size (fraction of page height), or null.
  final double? textSize;

  /// TrueType fonts for non-Latin values, by script (see [_scriptOf]).
  final Map<String, Uint8List> fonts;
  final String outPath;
  final String? sourcePdfPath;
  final List<_PagePlan> pages;
  final List<_FieldPlan> fields;
  const _ExportJob({
    this.textSize,
    this.fonts = const {},
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
  final String? optionsJson;
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
    this.optionsJson,
  });
}

// ── Isolate entry point ─────────────────────────────────────────────────────

Future<void> _buildFillablePdf(_ExportJob job) async {
  final srcPath = job.sourcePdfPath;
  PdfDocument? source;
  if (srcPath != null && File(srcPath).existsSync()) {
    try {
      source = PdfDocument(inputBytes: File(srcPath).readAsBytesSync());
    } catch (_) {
      source = null;
    }
  }
  // Re-use the original PDF (keeping its real AcroForm) only when the
  // document's pages are still exactly that PDF's pages, in order. After a
  // reorder, a deleted page, or when scans are mixed in, "page N" of the
  // document is no longer page N of the file, so the export is rebuilt page by
  // page instead — otherwise fields land on the wrong pages.
  final keepOriginal = source != null && _pagesAreSource(job, source);
  final pdfDoc = keepOriginal ? source : PdfDocument();
  final sources = <String, PdfDocument?>{};
  try {
    // Stamp appearance streams for field values so filled text/checkboxes are
    // visible in viewers that don't honour NeedAppearances (Preview, Chrome).
    pdfDoc.form.setDefaultAppearance(true);
    final names = _UniqueNames();

    if (keepOriginal) {
      for (var i = 0; i < pdfDoc.form.fields.count; i++) {
        final n = pdfDoc.form.fields[i].name;
        if (n != null) names.reserve(n);
      }
      _fillExistingForm(pdfDoc, job.fields);
      for (var i = 0; i < pdfDoc.pages.count; i++) {
        final page = pdfDoc.pages[i];
        _addRadioGroups(
          pdfDoc,
          page,
          [
            for (final f in job.fields)
              if (f.pageIndex == i && f.sourceKind == 'app') f,
          ],
          Offset.zero & page.size,
          names,
        );
      }
      for (final f in job.fields) {
        if (f.pageIndex < 0 || f.pageIndex >= pdfDoc.pages.count) continue;
        final page = pdfDoc.pages[f.pageIndex];
        final content = Offset.zero & page.size;
        if (f.sourceKind == 'app') {
          if (f.type.toFieldType() != FieldType.radio) {
            _addWidget(
              pdfDoc,
              page,
              f,
              content,
              names,
              job.textSize,
              job.fonts,
            );
          }
        } else if (f.type.toFieldType() == FieldType.signature &&
            f.isFilled &&
            f.value.isNotEmpty) {
          // A drawn signature is an image, not an AcroForm value.
          _drawSignature(
            page.graphics,
            f.value,
            BoundingBox.fromJsonString(f.boundingBoxJson).inPageRect(content),
          );
        }
      }
    } else {
      if (source != null && srcPath != null) sources[srcPath] = source;
      _buildPages(pdfDoc, job, sources, names);
    }

    final bytes = await pdfDoc.save();
    await File(job.outPath).writeAsBytes(bytes);
  } finally {
    pdfDoc.dispose();
    for (final d in sources.values) {
      if (!identical(d, pdfDoc)) d?.dispose();
    }
  }
}

bool _pagesAreSource(_ExportJob job, PdfDocument source) {
  if (source.pages.count != job.pages.length) return false;
  for (var i = 0; i < job.pages.length; i++) {
    if (job.pages[i].imagePath != '${job.sourcePdfPath}#page=$i') return false;
  }
  return true;
}

/// AcroForm names must be unique per document, or viewers merge the widgets
/// into one field (typing in one fills the other). Labels are user-chosen, so
/// two fields both labelled "Name" are normal and get `Name`, `Name_2`.
class _UniqueNames {
  final _used = <String>{};
  void reserve(String n) => _used.add(n);
  String claim(String base) {
    var name = base;
    for (var i = 2; _used.contains(name); i++) {
      name = '${base}_$i';
    }
    _used.add(name);
    return name;
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

/// Paints a signature image file into [rect], preserving aspect ratio.
void _drawSignature(PdfGraphics gfx, String path, Rect rect) {
  final file = File(path);
  if (!file.existsSync()) return;
  final bmp = PdfBitmap(file.readAsBytesSync());
  final iw = bmp.width.toDouble();
  final ih = bmp.height.toDouble();
  if (iw <= 0 || ih <= 0) return;
  final scale = (iw / rect.width > ih / rect.height)
      ? rect.width / iw
      : rect.height / ih;
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

/// Builds every page onto A4 — a scanned image or an imported PDF page — and
/// adds every field (app-authored or from the source form) as a live widget
/// placed in the rect the page content actually occupies.
void _buildPages(
  PdfDocument pdfDoc,
  _ExportJob job,
  Map<String, PdfDocument?> sources,
  _UniqueNames names,
) {
  PdfDocument? open(String path) => sources.putIfAbsent(path, () {
    final f = File(path);
    return f.existsSync() ? PdfDocument(inputBytes: f.readAsBytesSync()) : null;
  });

  for (var i = 0; i < job.pages.length; i++) {
    final plan = job.pages[i];
    // An imported page keeps its own size; scans go on A4. No margins.
    final size = outputPageSize(plan.imagePath, open);
    final pw = size.width, ph = size.height;
    final page = addEdgeToEdgePage(pdfDoc, size);
    final content =
        _drawPageContent(page.graphics, plan.imagePath, pw, ph, sources) ??
        Rect.fromLTWH(0, 0, pw, ph);
    final onPage = job.fields.where((f) => f.pageIndex == i).toList();
    for (final f in onPage) {
      if (f.type.toFieldType() != FieldType.radio) {
        _addWidget(pdfDoc, page, f, content, names, job.textSize, job.fonts);
      }
    }
    _addRadioGroups(pdfDoc, page, onPage, content, names);
  }
}

/// Draws [path] fitted (contain, centred) and returns the rect it occupies.
Rect? _drawPageContent(
  PdfGraphics gfx,
  String path,
  double pw,
  double ph,
  Map<String, PdfDocument?> sources,
) {
  Rect fit(double w, double h) {
    final scale = (w / pw > h / ph) ? pw / w : ph / h;
    return Rect.fromLTWH(
      (pw - w * scale) / 2,
      (ph - h * scale) / 2,
      w * scale,
      h * scale,
    );
  }

  try {
    final hash = path.indexOf('#page=');
    if (hash >= 0) {
      final pdfPath = path.substring(0, hash);
      final n = int.tryParse(path.substring(hash + 6)) ?? 0;
      final src = sources.putIfAbsent(pdfPath, () {
        final f = File(pdfPath);
        return f.existsSync()
            ? PdfDocument(inputBytes: f.readAsBytesSync())
            : null;
      });
      if (src == null || n < 0 || n >= src.pages.count) return null;
      final template = src.pages[n].createTemplate();
      if (template.size.width <= 0 || template.size.height <= 0) return null;
      final dest = fit(template.size.width, template.size.height);
      gfx.drawPdfTemplate(template, dest.topLeft, dest.size);
      return dest;
    }
    final file = File(path);
    if (!file.existsSync()) return null;
    final bmp = PdfBitmap(file.readAsBytesSync());
    if (bmp.width <= 0 || bmp.height <= 0) return null;
    final dest = fit(bmp.width.toDouble(), bmp.height.toDouble());
    gfx.drawImage(bmp, dest);
    return dest;
  } catch (_) {
    // An unreadable page exports blank rather than failing the whole export.
    return null;
  }
}

/// Creates a single live AcroForm widget for [f] on [page], inside [content].
void _addWidget(
  PdfDocument pdfDoc,
  PdfPage page,
  _FieldPlan f,
  Rect content,
  _UniqueNames names,
  double? textSize, [
  Map<String, Uint8List> fonts = const {},
]) {
  final rect = BoundingBox.fromJsonString(
    f.boundingBoxJson,
  ).inPageRect(content);
  final type = f.type.toFieldType();
  final label = f.pdfFieldName?.trim() ?? '';
  final name = names.claim(
    label.isNotEmpty ? label : '${type.name}_p${f.pageIndex + 1}',
  );

  switch (type) {
    case FieldType.text:
    case FieldType.date:
      final field = _borderless(PdfTextBoxField(page, name, rect));
      // Typed text at the document's own size, so it matches the form.
      final pt = textSize == null
          ? math.min(rect.height * 0.7, 12.0)
          : (textSize * content.height)
                .clamp(5.0, math.max(5.0, rect.height * 0.9))
                .toDouble();
      // Hindi / Tamil / Telugu need a font that has their letters; the
      // standard PDF fonts are Latin-only and showed nothing. (The PDF
      // library doesn't shape Indic scripts, so a viewer that draws the
      // stamped appearance may misplace some vowel signs; viewers that
      // redraw fields themselves render it correctly.)
      final script = _scriptOf(f.value);
      final fontBytes = script == null ? null : fonts[script];
      field.font = fontBytes != null
          ? PdfTrueTypeFont(fontBytes, pt)
          : PdfStandardFont(PdfFontFamily.helvetica, pt);
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
        pdfDoc.form.fields.add(
          _borderless(PdfSignatureField(page, name, bounds: rect)),
        );
      }
    case FieldType.initials:
      // Drawn initials are painted like a signature; blank ones become a
      // small text box the recipient can type their initials into.
      if (f.isFilled && f.value.isNotEmpty) {
        _drawSignature(page.graphics, f.value, rect);
      } else {
        pdfDoc.form.fields.add(_borderless(PdfTextBoxField(page, name, rect)));
      }
    case FieldType.radio:
      // Radios are exported per group by _addRadioGroups.
      break;
  }
  // NOTE: a field's `isRequired` is persisted in our DB and used for in-app
  // validation, but this Syncfusion version exposes no setter to stamp the
  // AcroForm "required" flag into the PDF, so it isn't reflected in the export.
}

/// Exports each radio group on [page] as one AcroForm radio-button field with
/// an option per button, so PDF viewers let the recipient pick exactly one.
/// Radios without a group id each become their own single-option group.
void _addRadioGroups(
  PdfDocument pdfDoc,
  PdfPage page,
  List<_FieldPlan> fields,
  Rect content,
  _UniqueNames names,
) {
  final groups = <String, List<_FieldPlan>>{};
  var loose = 0;
  for (final f in fields) {
    if (f.type.toFieldType() != FieldType.radio) continue;
    final key = radioGroupOf(f.optionsJson) ?? '__loose_${loose++}';
    groups.putIfAbsent(key, () => []).add(f);
  }
  for (final options in groups.values) {
    final label = options
        .map((f) => f.pdfFieldName?.trim() ?? '')
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    final name = names.claim(
      label.isNotEmpty ? label : 'radio_p${options.first.pageIndex + 1}',
    );
    final chosen = options.indexWhere((f) => f.isChecked);
    final field = PdfRadioButtonListField(
      page,
      name,
      items: [
        // Export values are positions, not words, so nothing is persisted in
        // one language.
        for (var i = 0; i < options.length; i++)
          PdfRadioButtonListItem(
            '${i + 1}',
            BoundingBox.fromJsonString(
              options[i].boundingBoxJson,
            ).inPageRect(content),
          ),
      ],
      selectedIndex: chosen < 0 ? null : chosen,
    );
    pdfDoc.form.fields.add(field);
  }
}

/// No border or background, so a filled value reads as text on the form
/// rather than text in a box. Checkboxes and radios keep their outline: on an
/// unfilled form it's the only visible sign of the control.
T _borderless<T extends PdfField>(T field) {
  if (field is PdfTextBoxField) {
    field
      ..borderWidth = 0
      ..backColor = PdfColor.empty;
  } else if (field is PdfSignatureField) {
    field
      ..borderWidth = 0
      ..backColor = PdfColor.empty;
  }
  return field;
}

/// Bundled fonts for scripts the standard PDF fonts can't show.
const _scriptFonts = {
  'deva': 'assets/fonts/NotoSansDevanagari-Regular.ttf',
  'taml': 'assets/fonts/NotoSansTamil-Regular.ttf',
  'telu': 'assets/fonts/NotoSansTelugu-Regular.ttf',
};

/// The Indic script [text] is written in, if any.
String? _scriptOf(String text) {
  for (final r in text.runes) {
    if (r >= 0x0900 && r <= 0x097F) return 'deva';
    if (r >= 0x0B80 && r <= 0x0BFF) return 'taml';
    if (r >= 0x0C00 && r <= 0x0C7F) return 'telu';
  }
  return null;
}
