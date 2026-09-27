import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/services/document_repository.dart';
import '../../../core/services/page_raster_service.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';

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
  late final Stream<List<db.Page>> _pagesStream = ref
      .read(pageRepositoryProvider)
      .watchPages(widget.docId);

  @override
  Widget build(BuildContext context) {
    final pagesStream = _pagesStream;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reviewTitle),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _saveOrder,
              child: Text(context.l10n.reviewSaveOrder),
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
          if (_pages.isEmpty || !_dirty) {
            _pages = List.from(pages);
          } else {
            // Keep the unsaved order, but pick up row changes (a rotate writes
            // a new imagePath) and drop pages deleted meanwhile.
            final byId = {for (final pg in pages) pg.id: pg};
            _pages = [
              for (final pg in _pages)
                if (byId[pg.id] != null) byId[pg.id]!,
            ];
          }

          if (pages.isEmpty) {
            return Center(child: Text(context.l10n.reviewNoPagesFound));
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
              final filter =
                  _filters[page.id] ?? _filterFromString(page.activeFilter);
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
              label: Text(context.l10n.reviewDetectFields),
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
    ref
        .read(pageRepositoryProvider)
        .updatePage(
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
    // Also turns the page's fields, so they stay on the content they cover.
    try {
      await ref.read(pageRepositoryProvider).rotatePageClockwise(page.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.reviewRotateFailed('$e'))),
        );
      }
    }
  }

  Future<void> _deletePage(db.Page page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.reviewDeletePageTitle),
        content: Text(
          context.l10n.reviewDeletePageBody(_pages.indexOf(page) + 1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Deletes the page's fields and renumbers later pages (and their fields)
    // in one transaction, and updates the page count.
    await ref.read(pageRepositoryProvider).deletePage(page.id);
    if (mounted) setState(() => _pages.removeWhere((p) => p.id == page.id));
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

  /// A page of an imported PDF: its content is vector, drawn as-is into the
  /// output, so rotation and the image filters don't apply and aren't shown
  /// (they used to be offered and silently do nothing).
  bool get _isPdfPage => page.imagePath.contains('#page=');

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
                Text(
                  context.l10n.reviewPageOf(pageNumber, totalPages),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                if (!_isPdfPage)
                  IconButton(
                    icon: const Icon(Icons.rotate_right),
                    tooltip: context.l10n.reviewRotateTooltip,
                    onPressed: onRotate,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.reviewDeletePageTooltip,
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
          if (_isPdfPage)
            const SizedBox(height: 12)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 8,
                children: PageFilter.values.map((f) {
                  return ChoiceChip(
                    label: Text(_filterLabel(context, f)),
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

  String _filterLabel(BuildContext context, PageFilter f) => switch (f) {
    PageFilter.original => context.l10n.filterOriginal,
    PageFilter.enhanced => context.l10n.filterEnhanced,
    PageFilter.bw => context.l10n.filterBw,
  };
}

class _RasterThumb extends ConsumerWidget {
  const _RasterThumb({required this.storedPath});
  final String storedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.read(pageRasterServiceProvider).imageFor(storedPath),
      builder: (context, snap) {
        if (snap.hasError) {
          return Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 48,
                color: Colors.grey,
              ),
            ),
          );
        }
        final path = snap.data;
        if (path == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.file(File(path), fit: BoxFit.contain, cacheWidth: 800);
      },
    );
  }
}

class _FilteredImage extends StatelessWidget {
  const _FilteredImage({required this.path, required this.filter});
  final String path;
  final PageFilter filter;

  @override
  Widget build(BuildContext context) {
    final resolved = PathResolver.resolve(path);
    // PDF-backed page: show the cached render instead of a live viewer per
    // card, which was slow and memory-hungry on long imports.
    if (resolved.contains('#page=')) {
      return _RasterThumb(storedPath: path);
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
          1.2,
          0,
          0,
          0,
          -15,
          0,
          1.2,
          0,
          0,
          -15,
          0,
          0,
          1.2,
          0,
          -15,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      ),
      PageFilter.bw => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.299,
          0.587,
          0.114,
          0,
          0,
          0.299,
          0.587,
          0.114,
          0,
          0,
          0.299,
          0.587,
          0.114,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      ),
    };
  }
}
