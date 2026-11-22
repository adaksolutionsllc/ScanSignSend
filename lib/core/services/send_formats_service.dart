import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../db/app_database.dart';
import '../models/field_model.dart';
import 'document_repository.dart';
import 'page_text_service.dart';
import 'text_export.dart';

/// What Send shares: the PDF (default), or the same document in another
/// form for people who need it that way.
enum SendFormat { pdf, images, text, word }

final sendFormatsServiceProvider = Provider<SendFormatsService>(
  (ref) => SendFormatsService(
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
    ref.watch(pageTextServiceProvider),
  ),
);

/// Makes the files for Send → Images, Text and Word.
class SendFormatsService {
  SendFormatsService(this._pages, this._fields, this._text);

  final PageRepository _pages;
  final FieldRepository _fields;
  final PageTextService _text;

  /// Images are rendered at this resolution: sharp to read on a screen and
  /// to print, about 1240 × 1754 px for an A4 page.
  static const imageDpi = 150.0;

  /// Each page of the finished PDF at [pdfPath] as a JPEG in [dir], named
  /// "[name] (1).jpg" and on. The finished PDF, so fill-ins and signatures
  /// show.
  Future<List<String>> pageImages(
    String pdfPath,
    Directory dir,
    String name,
  ) async {
    final bytes = await File(pdfPath).readAsBytes();
    final out = <String>[];
    await for (final page in Printing.raster(bytes, dpi: imageDpi)) {
      final dest = p.join(dir.path, '$name (${out.length + 1}).jpg');
      await compute(_pngToJpeg, (await page.toPng(), dest));
      out.add(dest);
    }
    return out;
  }

  /// Each page's text and what was filled in on it, for Text and Word.
  Future<List<TextExportPage>> textPages(int docId) async {
    final pages = await _pages.pagesOf(docId);
    final fields = await _fields.watchFields(docId).first;
    return [
      for (final (i, page) in pages.indexed)
        TextExportPage(
          text: await _text.textOf(page),
          filled: filledLines([
            for (final f in fields)
              if (f.pageIndex == i) f,
          ]),
        ),
    ];
  }
}

/// The filled-in values of one page's fields, top to bottom, as text lines:
/// "Label: value", or "[x] Label" for a ticked box or chosen option.
/// Signatures and initials are pictures and are left out.
List<String> filledLines(List<Field> fields) {
  final sorted = [...fields]
    ..sort((a, b) {
      final ba = BoundingBox.fromJsonString(a.boundingBoxJson);
      final bb = BoundingBox.fromJsonString(b.boundingBoxJson);
      final dy = ba.y.compareTo(bb.y);
      return dy != 0 ? dy : ba.x.compareTo(bb.x);
    });
  return [for (final f in sorted) ?_line(f)];
}

String? _line(Field f) {
  final label = f.label.trim();
  switch (f.type.toFieldType()) {
    case FieldType.text || FieldType.date:
      final value = f.value.trim();
      if (value.isEmpty) return null;
      return label.isEmpty ? value : '$label: $value';
    case FieldType.checkbox || FieldType.radio:
      if (!f.isChecked) return null;
      return label.isEmpty ? '[x]' : '[x] $label';
    case FieldType.signature || FieldType.initials:
      return null;
  }
}

void _pngToJpeg((Uint8List, String) args) {
  final (png, dest) = args;
  final image = img.decodePng(png);
  if (image == null) throw FileSystemException('Unreadable render', dest);
  File(dest).writeAsBytesSync(img.encodeJpg(image, quality: 85), flush: true);
}
