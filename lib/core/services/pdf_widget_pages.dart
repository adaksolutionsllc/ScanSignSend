// Syncfusion's internals are pinned with the package version (28.2.x); the
// public API has no way to read a page's annotation list.
// ignore_for_file: implementation_imports

import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/io/pdf_constants.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/io/pdf_cross_table.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/pages/pdf_page.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_dictionary.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_string.dart';

/// Which page each form field's widget sits on, by field name, read from
/// the pages' annotation lists.
///
/// For forms whose widgets don't name their page (/P). PDFKit writes them
/// that way — any form saved in Preview or iOS Files, and every PDF the app
/// password-protects on iOS — and Syncfusion then reports no page for the
/// field, so the import skipped every field.
Map<String, int> widgetPagesByName(PdfDocument doc) {
  final pages = <String, int>{};
  for (var j = 0; j < doc.pages.count; j++) {
    final annots = PdfPageHelper.getHelper(doc.pages[j]).obtainAnnotations();
    if (annots == null) continue;
    for (var k = 0; k < annots.count; k++) {
      // A widget carries its field's name, or its parent field does.
      var node = PdfCrossTable.dereference(annots[k]);
      String? name;
      var depth = 0;
      while (node is PdfDictionary && name == null && depth++ < 8) {
        final t = PdfCrossTable.dereference(node[PdfDictionaryProperties.t]);
        if (t is PdfString) name = t.value;
        node = PdfCrossTable.dereference(node[PdfDictionaryProperties.parent]);
      }
      if (name != null) pages.putIfAbsent(name, () => j);
    }
  }
  return pages;
}

/// A page-less field's bounds as Syncfusion reports them (PDF space: left,
/// the top edge's height from the bottom, width, height) turned into page
/// space from the top-left, like a field whose page is known.
Rect pageBoundsOfOrphan(Rect raw, double pageHeight) =>
    Rect.fromLTWH(raw.left, pageHeight - raw.top, raw.width, raw.height);
