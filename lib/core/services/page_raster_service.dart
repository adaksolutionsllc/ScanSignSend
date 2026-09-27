import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../utils/path_resolver.dart';

final pageRasterServiceProvider = Provider<PageRasterService>(
  (ref) => PageRasterService(),
);

/// Turns any stored page path into an image file that can be drawn and OCR'd.
///
/// Scanned pages already are images. Imported-PDF pages (`<file>#page=N`) are
/// rendered once through the OS's own PDF renderer (PDFKit / PdfRenderer, via
/// `printing`) and cached as PNG. Showing every page as a plain image, rather
/// than inside a PDF viewer widget, is what lets the field editor, fill mode
/// and the exports agree on exactly where the page sits: a viewer applies its
/// own fit, padding and zoom, which a field overlay can only guess at.
///
/// The cache lives in the OS cache directory, which is never included in
/// device backups and which the OS may purge; a purged page is simply
/// re-rendered on next use.
class PageRasterService {
  /// Enough resolution for OCR and a sharp full-screen page without holding a
  /// huge bitmap: an A4 page renders at ~1240×1754.
  static const _dpi = 150.0;

  final _inFlight = <String, Future<File>>{};

  /// Absolute path of an image file showing the page stored as [storedPath].
  Future<String> imageFor(String storedPath) async {
    final resolved = PathResolver.resolve(storedPath);
    final hash = resolved.indexOf('#page=');
    if (hash < 0) return resolved;
    final pdfPath = resolved.substring(0, hash);
    final pageIndex = int.tryParse(resolved.substring(hash + 6)) ?? 0;
    final file = await _rasterize(pdfPath, pageIndex);
    return file.path;
  }

  Future<File> _rasterize(String pdfPath, int pageIndex) async {
    final src = File(pdfPath);
    if (!src.existsSync()) {
      throw FileSystemException('Source PDF missing', pdfPath);
    }
    final stat = src.statSync();
    final dir = await _cacheDir();
    // The source's folder is its import UUID, so [evict] can find every page
    // of one PDF by prefix. Size + mtime invalidate the cache if the file is
    // ever replaced in place.
    final key =
        '${_folderOf(pdfPath)}_${pageIndex}_'
        '${_fnv1a('${p.basename(pdfPath)}|${stat.size}|${stat.modified.millisecondsSinceEpoch}')}';
    final out = File(p.join(dir.path, '$key.png'));
    if (out.existsSync() && out.lengthSync() > 0) return out;

    return _inFlight[key] ??= () async {
      try {
        final bytes = await src.readAsBytes();
        await for (final raster in Printing.raster(
          bytes,
          pages: [pageIndex],
          dpi: _dpi,
        )) {
          final png = await raster.toPng();
          // Write-then-rename so a crash mid-write never leaves a truncated
          // PNG that later reads as a valid cache hit.
          final tmp = File('${out.path}.part');
          await tmp.writeAsBytes(png, flush: true);
          await tmp.rename(out.path);
          return out;
        }
        throw RangeError.index(pageIndex, null, 'pageIndex');
      } finally {
        _inFlight.remove(key);
      }
    }();
  }

  /// Drops every cached render of the PDF at [storedPdfPath]. Called when its
  /// document is deleted, so page images don't outlive the document.
  Future<void> evict(String storedPdfPath) async {
    // Best effort and never throws: it runs inside document deletion, which
    // must not fail over a cache the OS purges anyway.
    try {
      final folder = _folderOf(PathResolver.resolve(storedPdfPath));
      final dir = await _cacheDir();
      for (final f in dir.listSync()) {
        if (p.basename(f.path).startsWith('${folder}_')) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'page_raster'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static String _folderOf(String path) => p.basename(p.dirname(path));

  /// Stable across runs, unlike String.hashCode.
  static String _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }
}
