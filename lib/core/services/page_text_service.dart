import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'document_repository.dart';
import 'page_layout_service.dart';

final pageTextServiceProvider = Provider<PageTextService>(
  (ref) => PageTextService(
    ref.watch(pageRepositoryProvider),
    ref.watch(pageLayoutServiceProvider),
  ),
);

/// The text on a page, for copying and sharing (Review / Viewer → Text).
///
/// Read once and kept in `Pages.ocrText`: from the PDF's own text layer when
/// it has one, else by on-device OCR, which reads Latin script only. Rotate
/// and Crop clear it, so it is read again from the new image.
class PageTextService {
  PageTextService(this._pages, this._layouts);

  final PageRepository _pages;
  final PageLayoutService _layouts;

  /// One page at a time: OCR is heavy, and a long document opened in the
  /// sheet would otherwise start every page at once.
  Future<void> _queue = Future.value();

  /// The page's text; empty when none was found. Never throws.
  Future<String> textOf(Page page) {
    if (page.ocrText.isNotEmpty) return Future.value(page.ocrText);
    final done = _queue.then((_) => _read(page));
    _queue = done.then((_) {});
    return done;
  }

  Future<String> _read(Page page) async {
    try {
      final text = (await _layouts.textOnly(page.imagePath)).$2.trim();
      if (text.isNotEmpty) await _pages.setPageText(page.id, text);
      return text;
    } catch (e) {
      debugPrint('PageTextService: $e');
      return '';
    }
  }

  /// Every page's text in order, pages apart by a blank line, for "Copy all"
  /// and the .txt file. Pages with no text are left out.
  static String joined(Iterable<String> pages) =>
      pages.where((t) => t.isNotEmpty).join('\n\n');
}
