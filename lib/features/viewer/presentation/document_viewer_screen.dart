import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';

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
    return FutureBuilder<Document?>(
      future: ref.read(documentRepositoryProvider).getById(widget.docId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final doc = snapshot.data;
        final path = _resolvePath(doc);

        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? _SearchField(
                    controller: _searchController,
                    onSubmit: _runSearch,
                  )
                : Text(doc?.title ?? 'Document'),
            actions: _searching
                ? _searchActions()
                : [
                    IconButton(
                      tooltip: 'Search',
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

  /// Prefer the exported PDF (pressed or fillable); otherwise the imported
  /// source PDF. Scanned-only docs with no export yet have no single PDF to
  /// show here (they live in the fill/review flows).
  String? _resolvePath(Document? doc) {
    if (doc == null) return null;
    final exported = doc.pressedPdfPath;
    if (exported != null && File(exported).existsSync()) return exported;
    return null;
  }
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
      decoration: const InputDecoration(
        hintText: 'Search in document…',
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
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: onPrev),
            Text('Page $current of $total'),
            IconButton(
                icon: const Icon(Icons.chevron_right), onPressed: onNext),
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
            const Icon(Icons.picture_as_pdf_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No exported PDF to view yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Fill and export this document (fillable or flattened) to view it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
