import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/services/app_lock_provider.dart';
import '../../../shared/utils/share_pdf.dart';

/// First-class PDF viewer: pinch-zoom, page navigation, and in-document text
/// search. Opens the document's exported PDF (pressed/fillable) when present,
/// otherwise falls back to the source PDF of an imported document.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  final _controller = PdfViewerController();
  final _searchController = TextEditingController();

  PdfTextSearchResult? _searchResult;
  bool _searching = false;
  int _currentPage = 1;
  int _pageCount = 0;

  // Resolve the document + source path ONCE. Calling _load() directly in build()
  // creates a new Future each frame; the viewer's onDocumentLoaded/onPageChanged
  // setState calls then rebuild → new Future → reload → setState → flicker loop.
  late final Future<_ViewerData> _dataFuture = _load();

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    _searchResult?.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _runSearch(String term) async {
    _searchResult?.removeListener(_onSearchChanged);
    if (term.trim().isEmpty) {
      _controller.clearSelection();
      setState(() => _searchResult = null);
      return;
    }
    final result = _controller.searchText(term);
    result.addListener(_onSearchChanged);
    setState(() => _searchResult = result);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ViewerData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final doc = snapshot.data?.doc;
        _importedSourcePdf = snapshot.data?.sourcePdf;
        final path = _resolvePath(doc);

        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? _SearchField(
                    controller: _searchController,
                    onSubmit: _runSearch,
                  )
                : Text(doc?.title ?? context.l10n.documentFallbackTitle),
            actions: _searching
                ? _searchActions()
                : [
                    IconButton(
                      tooltip: context.l10n.actionShare,
                      icon: const Icon(Icons.share),
                      onPressed: (path != null)
                          ? () => _share(
                              context,
                              path,
                              doc?.title ?? context.l10n.documentFallbackTitle,
                            )
                          : null,
                    ),
                    IconButton(
                      tooltip: context.l10n.viewerSearchTooltip,
                      icon: const Icon(Icons.search),
                      onPressed: (path != null)
                          ? () => setState(() => _searching = true)
                          : null,
                    ),
                  ],
          ),
          body: path == null
              ? const _NoPdf()
              : SfPdfViewer.file(
                  File(path),
                  controller: _controller,
                  canShowScrollHead: true,
                  onDocumentLoaded: (details) {
                    if (mounted) {
                      setState(() => _pageCount = _controller.pageCount);
                    }
                  },
                  onPageChanged: (details) {
                    if (mounted) {
                      setState(() => _currentPage = details.newPageNumber);
                    }
                  },
                ),
          bottomNavigationBar: (path == null || _searching)
              ? null
              : _PageBar(
                  current: _currentPage,
                  total: _pageCount,
                  onPrev: _currentPage > 1
                      ? () => _controller.jumpToPage(_currentPage - 1)
                      : null,
                  onNext: _currentPage < _pageCount
                      ? () => _controller.jumpToPage(_currentPage + 1)
                      : null,
                ),
        );
      },
    );
  }

  List<Widget> _searchActions() {
    final r = _searchResult;
    return [
      if (r != null && r.hasResult) ...[
        Center(
          child: Text('${r.currentInstanceIndex}/${r.totalInstanceCount}'),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: r.previousInstance,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: r.nextInstance,
        ),
      ],
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          _searchController.clear();
          _controller.clearSelection();
          _searchResult?.removeListener(_onSearchChanged);
          setState(() {
            _searching = false;
            _searchResult = null;
          });
        },
      ),
    ];
  }

  Future<void> _share(
    BuildContext context,
    String pdfPath,
    String title,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!File(pdfPath).existsSync()) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.viewerPdfNotFound)),
      );
      return;
    }
    // iOS needs a non-zero source rect to anchor the share popover.
    // Resolve strings before the await — `context` is unsafe past the gap.
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await shareDocumentPdf(
        lock: ref.read(appLockProvider.notifier),
        pdfPath: pdfPath,
        title: title,
        message: l10n.sendShareMessage,
        origin: origin,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sendShareFailed('$e'))),
      );
    }
  }

  Future<_ViewerData> _load() async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getById(widget.docId);
    String? sourcePdf;
    final pages = await ref
        .read(pageRepositoryProvider)
        .watchPages(widget.docId)
        .first;
    for (final pg in pages) {
      if (pg.imagePath.contains('#page=')) {
        sourcePdf = pg.imagePath.split('#page=').first;
        break;
      }
    }
    return _ViewerData(doc, sourcePdf);
  }

  /// Prefer the exported PDF (pressed, then fillable); otherwise fall back to
  /// the imported source PDF so an imported-but-not-yet-exported document
  /// still renders instead of showing a blank page. Scanned-only (image) docs
  /// with no export have no single PDF here (they live in the fill/review
  /// flows).
  String? _resolvePath(Document? doc) {
    if (doc == null) return null;
    for (final exported in [doc.pressedPdfPath, doc.fillablePdfPath]) {
      if (exported == null) continue;
      final abs = PathResolver.resolve(exported);
      if (File(abs).existsSync()) return abs;
    }

    // Fallback: the original imported PDF. Pages of an imported PDF store their
    // path as "<file>.pdf#page=N" — strip the fragment to get the real file.
    final src = _importedSourcePdf;
    if (src != null) {
      final abs = PathResolver.resolve(src);
      if (File(abs).existsSync()) return abs;
    }
    return null;
  }

  String? _importedSourcePdf;
}

class _ViewerData {
  const _ViewerData(this.doc, this.sourcePdf);
  final Document? doc;
  final String? sourcePdf;
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: context.l10n.viewerSearchHint,
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
      onSubmitted: onSubmit,
    );
  }
}

class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
  });
  final int current;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return SafeArea(
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
            Text(context.l10n.reviewPageOf(current, total)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPdf extends StatelessWidget {
  const _NoPdf();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.viewerNoExportedPdf,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.viewerNoExportedPdfBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
