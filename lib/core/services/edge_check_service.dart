import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../utils/path_resolver.dart';
import 'document_edges.dart';
import 'document_repository.dart';
import 'import_service.dart';
import 'page_layout_service.dart';
import 'page_raster_service.dart';

final edgeCheckServiceProvider = Provider<EdgeCheckService>(
  (ref) => EdgeCheckService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(pageRasterServiceProvider),
  ),
);

/// A page whose document edges can be improved, with the corners found.
class EdgeCandidate {
  const EdgeCandidate({
    required this.pageId,
    required this.imagePath,
    required this.quad,
  });

  final int pageId;

  /// Absolute path of an image of the page, for showing and cropping.
  final String imagePath;

  final EdgeQuad quad;
}

/// Edge and corner correction for pages that did not come from the camera
/// scanner (which crops by itself): picked or opened photos, and PDFs that
/// are only photos of paper.
///
/// It stays out of the way when nothing needs fixing. A page is offered only
/// when a document was found in it and it doesn't already fill the image. A
/// PDF is looked at only when every page is a bare image (no text layer, no
/// form fields): a typed or exported PDF is already clean, and turning it
/// into images would lose its text.
///
/// Corners come from Apple's Vision framework on iOS
/// (`com.scansignsend/edges`, EdgeDetectionPlugin.swift) and from
/// [detectDocumentEdges] everywhere else, or when Vision fails.
class EdgeCheckService {
  EdgeCheckService(this._docRepo, this._pageRepo, this._raster);

  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;

  /// The app's one renderer: sorting renders the same new page at the same
  /// moment, and only a shared instance renders it once.
  final PageRasterService _raster;

  static const _channel = MethodChannel('com.scansignsend/edges');

  /// PDF pages turned into images are rendered at this resolution: sharper
  /// than the on-screen preview, since the result is the page itself.
  static const pdfPageDpi = 200.0;

  /// The pages of document [docId] worth offering a corner fix, in order.
  /// Empty when none are. Never throws: the check is a convenience.
  Future<List<EdgeCandidate>> candidatesFor(int docId) async {
    try {
      final doc = await _docRepo.getById(docId);
      final pages = await _pageRepo.pagesOf(docId);
      if (doc == null || pages.isEmpty) return const [];

      final pdf = _sourcePdf(pages);
      if (pdf != null) {
        if (doc.ocrText == ImportService.formFieldsSentinel) return const [];
        if (!await compute(isImageOnlyPdf, pdf)) return const [];
      }

      final out = <EdgeCandidate>[];
      for (final page in pages) {
        final image = await _raster.imageFor(page.imagePath);
        final quad = await detect(image);
        if (quad != null && quad.worthCropping) {
          out.add(EdgeCandidate(pageId: page.id, imagePath: image, quad: quad));
        }
      }
      return out;
    } catch (e) {
      debugPrint('EdgeCheckService: $e');
      return const [];
    }
  }

  /// The document's corners in the image at [path], or null if none found.
  Future<EdgeQuad?> detect(String path) async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        final v = await _channel.invokeListMethod<dynamic>('detect', {
          'path': path,
        });
        // Vision answered: trust it, including "no document".
        return EdgeQuad.fromList(v);
      } on MissingPluginException {
        // Tests: fall through to the Dart detector.
      } catch (e) {
        debugPrint('EdgeCheckService: Vision failed: $e');
      }
    }
    return compute(_detectFile, path);
  }

  /// Applies the user's choices: page id → corners to crop to. Pages left
  /// out (or "use whole image") stay as they are.
  ///
  /// A PDF-backed document is first turned into one image per page, so that
  /// every page is the same kind and the exports never mix the two.
  /// Returns the ids of pages that could not be cropped.
  Future<List<int>> apply(int docId, Map<int, EdgeQuad> crops) async {
    if (crops.isEmpty) return const [];
    var pages = await _pageRepo.pagesOf(docId);
    final pdf = _sourcePdf(pages);
    if (pdf != null) {
      await _pdfToImages(pdf, pages);
      pages = await _pageRepo.pagesOf(docId);
    }

    final failed = <int>[];
    for (final page in pages) {
      final quad = crops[page.id];
      if (quad == null) continue;
      try {
        final src = PathResolver.resolve(page.imagePath);
        // A new name each time, so an image cached under the old path is
        // never shown for the cropped page.
        final dest = p.join(
          p.dirname(src),
          'page_${page.pageIndex}_${const Uuid().v4().substring(0, 8)}.jpg',
        );
        await compute(_cropFile, (src, dest, quad.toList()));
        await _pageRepo.updatePage(
          PagesCompanion(
            id: Value(page.id),
            imagePath: Value(PathResolver.toStorable(dest)),
          ),
        );
        await _deleteQuietly(src);
      } catch (e) {
        debugPrint('EdgeCheckService: crop failed: $e');
        failed.add(page.id);
      }
    }
    return failed;
  }

  /// The imported PDF behind [pages], or null for image pages.
  static String? _sourcePdf(List<Page> pages) {
    for (final pg in pages) {
      if (pg.imagePath.contains('#page=')) {
        return PathResolver.resolve(pg.imagePath.split('#page=').first);
      }
    }
    return null;
  }

  Future<void> _pdfToImages(String pdfPath, List<Page> pages) async {
    final bytes = await File(pdfPath).readAsBytes();
    final dir = p.dirname(pdfPath);
    final written = <int, String>{};
    var i = 0;
    await for (final raster in Printing.raster(bytes, dpi: pdfPageDpi)) {
      final png = await raster.toPng();
      final dest = p.join(dir, 'page_$i.jpg');
      await compute(_pngToJpeg, (png, dest));
      written[i] = dest;
      i++;
    }
    // All pages or none: a half-converted document would mix both kinds.
    if (pages.any((pg) => written[_pdfPageIndex(pg.imagePath)] == null)) {
      for (final f in written.values) {
        await _deleteQuietly(f);
      }
      throw StateError('PDF rendered ${written.length} of ${pages.length}');
    }
    await _docRepo.transaction(() async {
      for (final pg in pages) {
        await _pageRepo.updatePage(
          PagesCompanion(
            id: Value(pg.id),
            imagePath: Value(
              PathResolver.toStorable(written[_pdfPageIndex(pg.imagePath)]!),
            ),
          ),
        );
      }
    });
    await _raster.evict(PathResolver.toStorable(pdfPath));
    await _deleteQuietly(pdfPath);
  }

  static int _pdfPageIndex(String stored) =>
      int.tryParse(stored.split('#page=').last) ?? 0;

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

/// compute() entry: true when the PDF at [path] is only pictures — no page
/// has a text layer and there are no form fields. Unreadable → false.
bool isImageOnlyPdf(String path) {
  try {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    try {
      if (doc.form.fields.count > 0) return false;
      for (var i = 0; i < doc.pages.count; i++) {
        final layout = pdfTextLayoutOf(doc, i);
        if (layout != null && layout.$1.isNotEmpty) return false;
      }
      return true;
    } finally {
      doc.dispose();
    }
  } catch (_) {
    return false;
  }
}

EdgeQuad? _detectFile(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) return null;
  return detectDocumentEdges(image);
}

void _cropFile((String, String, List<double>) args) {
  final (src, dest, quad) = args;
  final image = img.decodeImage(File(src).readAsBytesSync());
  if (image == null) throw FileSystemException('Unreadable image', src);
  final out = cropToQuad(image, EdgeQuad.fromList(quad)!);
  File(dest).writeAsBytesSync(img.encodeJpg(out, quality: 90), flush: true);
}

void _pngToJpeg((Uint8List, String) args) {
  final (png, dest) = args;
  final image = img.decodePng(png);
  if (image == null) throw FileSystemException('Unreadable render', dest);
  File(dest).writeAsBytesSync(img.encodeJpg(image, quality: 90), flush: true);
}
