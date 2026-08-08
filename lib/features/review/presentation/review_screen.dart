import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/services/document_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';

enum PageFilter { original, enhanced, bw }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final Map<int, PageFilter> _filters = {};
  List<db.Page> _pages = [];
  bool _dirty = false;

  // Created once — a fresh drift stream per build() re-subscribes each frame.
  late final Stream<List<db.Page>> _pagesStream =
      ref.read(pageRepositoryProvider).watchPages(widget.docId);

  @override
  Widget build(BuildContext context) {
    final pagesStream = _pagesStream;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Pages'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _saveOrder,
              child: const Text('Save Order'),
            ),
        ],
      ),
      body: StreamBuilder<List<db.Page>>(
        stream: pagesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final pages = snapshot.data ?? [];
          if (_pages.isEmpty || !_dirty) _pages = List.from(pages);

          if (pages.isEmpty) {
            return const Center(child: Text('No pages found.'));
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _pages.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final page = _pages.removeAt(oldIndex);
                _pages.insert(newIndex, page);
                _dirty = true;
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              // Seed from the persisted per-page filter so the choice survives
              // reopening and flows into the pressed PDF.
              final filter = _filters[page.id] ?? _filterFromString(page.activeFilter);
              return _PageCard(
                key: ValueKey(page.id),
                page: page,
                filter: filter,
                pageNumber: index + 1,
                totalPages: _pages.length,
                onFilterChanged: (f) => _setFilter(page, f),
                onRotate: () => _rotatePage(page),
                onDelete: () => _deletePage(page),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _proceed,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Detect Fields →'),
            ),
          ),
        ),
      ),
    );
  }

  static PageFilter _filterFromString(String s) => switch (s) {
        'original' => PageFilter.original,
        'bw' => PageFilter.bw,
        _ => PageFilter.enhanced,
      };

  static String _filterToString(PageFilter f) => switch (f) {
        PageFilter.original => 'original',
        PageFilter.enhanced => 'enhanced',
        PageFilter.bw => 'bw',
      };

  void _setFilter(db.Page page, PageFilter f) {
    setState(() => _filters[page.id] = f);
    // Persist so the pressed PDF uses the same filter the user previewed.
    ref.read(pageRepositoryProvider).updatePage(
          db.PagesCompanion(
            id: Value(page.id),
            activeFilter: Value(_filterToString(f)),
          ),
        );
  }

  Future<void> _saveOrder() async {
    final repo = ref.read(pageRepositoryProvider);
    await repo.reorderPages(widget.docId, _pages.map((p) => p.id).toList());
    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _rotatePage(db.Page page) async {
    // Skip rotation for PDF-backed pages
    if (page.imagePath.contains('#page=')) return;
    try {
      final file = File(PathResolver.resolve(page.imagePath));
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final rotated = img.copyRotate(decoded, angle: 90);
      final encoded = img.encodeJpg(rotated, quality: 92);
      await file.writeAsBytes(encoded);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotate failed: $e')),
        );
      }
    }
  }

  Future<void> _deletePage(db.Page page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text('Remove page ${_pages.indexOf(page) + 1}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(pageRepositoryProvider).deletePage(page.id);
    setState(() => _pages.removeWhere((p) => p.id == page.id));
    await ref.read(documentRepositoryProvider).updateDocument(
          db.DocumentsCompanion(
            id: Value(widget.docId),
            pageCount: Value(_pages.length),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  void _proceed() {
    if (_dirty) {
      _saveOrder().then((_) {
        if (mounted) {
          context.push(
            AppRoutes.fieldDetection.replaceAll(':docId', '${widget.docId}'),
          );
        }
      });
    } else {
      context.push(
        AppRoutes.fieldDetection.replaceAll(':docId', '${widget.docId}'),
      );
    }
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.page,
    required this.filter,
    required this.pageNumber,
    required this.totalPages,
    required this.onFilterChanged,
    required this.onRotate,
    required this.onDelete,
  });

  final db.Page page;
  final PageFilter filter;
  final int pageNumber;
  final int totalPages;
  final ValueChanged<PageFilter> onFilterChanged;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text('Page $pageNumber of $totalPages',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.rotate_right),
                  tooltip: 'Rotate 90°',
                  onPressed: onRotate,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete page',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: onDelete,
                ),
                const Icon(Icons.drag_handle, color: Colors.grey),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 0.707,
            child: _FilteredImage(path: page.imagePath, filter: filter),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              children: PageFilter.values.map((f) {
                return ChoiceChip(
                  label: Text(_filterLabel(f)),
                  selected: filter == f,
                  onSelected: (_) => onFilterChanged(f),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(PageFilter f) => switch (f) {
        PageFilter.original => 'Original',
        PageFilter.enhanced => 'Enhanced',
        PageFilter.bw => 'B&W',
      };
}

class _FilteredImage extends StatelessWidget {
  const _FilteredImage({required this.path, required this.filter});
  final String path;
  final PageFilter filter;

  @override
  Widget build(BuildContext context) {
    final resolved = PathResolver.resolve(path);
    // PDF-backed page — render with SfPdfViewer
    if (resolved.contains('#page=')) {
      final parts = resolved.split('#page=');
      final pdfPath = parts[0];
      final pageNum = (int.tryParse(parts[1]) ?? 0) + 1; // SfPdfViewer is 1-indexed
      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) {
        return Container(
          color: Colors.grey.shade100,
          child: const Center(child: Icon(Icons.picture_as_pdf_outlined, size: 48, color: Colors.grey)),
        );
      }
      return IgnorePointer(
        child: SfPdfViewer.file(
          pdfFile,
          initialPageNumber: pageNum,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          enableDoubleTapZooming: false,
          pageLayoutMode: PdfPageLayoutMode.single,
        ),
      );
    }

    final file = File(resolved);
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    Widget image = Image.file(file, fit: BoxFit.cover);

    return switch (filter) {
      PageFilter.original => image,
      PageFilter.enhanced => ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.2, 0,   0,   0, -15,
            0,   1.2, 0,   0, -15,
            0,   0,   1.2, 0, -15,
            0,   0,   0,   1, 0,
          ]),
          child: image,
        ),
      PageFilter.bw => ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.299, 0.587, 0.114, 0, 0,
            0.299, 0.587, 0.114, 0, 0,
            0.299, 0.587, 0.114, 0, 0,
            0,     0,     0,     1, 0,
          ]),
          child: image,
        ),
    };
  }
}
