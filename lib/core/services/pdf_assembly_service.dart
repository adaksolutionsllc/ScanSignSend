import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

final pdfAssemblyServiceProvider =
    Provider<PdfAssemblyService>((ref) => PdfAssemblyService());

class PdfAssemblyService {
  /// Assembles [imagePaths] into a single PDF and returns its file path.
  /// Each image is scaled to A4 (595 × 842 pt) preserving aspect ratio.
  Future<String> assemblePages(
    List<String> imagePaths, {
    required String documentUuid,
  }) async {
    final doc = PdfDocument();
    final a4 = PdfPageSize.a4;

    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final pdfImage = PdfBitmap(bytes);

      final imgW = pdfImage.width.toDouble();
      final imgH = pdfImage.height.toDouble();
      final pageW = a4.width;
      final pageH = a4.height;

      // Fit image to page preserving aspect ratio
      final scale = (imgW / pageW > imgH / pageH)
          ? pageW / imgW
          : pageH / imgH;
      final drawW = imgW * scale;
      final drawH = imgH * scale;
      final offsetX = (pageW - drawW) / 2;
      final offsetY = (pageH - drawH) / 2;

      final page = doc.pages.add();
      page.graphics.drawImage(
        pdfImage,
        Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final outPath = p.join(dir.path, 'docs', '$documentUuid.pdf');
    await Directory(p.dirname(outPath)).create(recursive: true);
    await File(outPath).writeAsBytes(await doc.save());
    doc.dispose();
    return outPath;
  }

  /// Builds a single-page PDF from one image (used by import).
  Future<String> singlePagePdf(String imagePath, String uuid) =>
      assemblePages([imagePath], documentUuid: uuid);
}
