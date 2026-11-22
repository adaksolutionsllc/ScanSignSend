import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../../../core/db/app_database.dart' as db;
import '../../../core/services/clean_filter.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/edge_check_service.dart';
import '../../../core/services/page_raster_service.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/category_ui.dart';
import '../../press/presentation/finish_flow.dart';
import '../../../core/services/document_sorter.dart';
import '../../../core/services/merge_service.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../../library/presentation/merge_flow.dart';
import 'add_pages.dart';

enum PageFilter { original, enhanced, clean, bw }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.docId, this.organise = false});
  final int docId;

  /// Opened from Fill mode to manage pages: the bottom bar is just Done
  /// (back to filling), not the after-scan choices.
  final bool organise;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final Map<int, PageFilter> _filters = {};
  List<db.Page> _pages = [];
  bool _dirty = false;

  /// Pages picked to copy or move to a new document; null when not picking.
  Set<int>? _picked;

  // Created once — a fresh drift stream per build() re-subscribes each frame.
  late final Stream<List<db.Page>> _pagesStream = ref
      .read(pageRepositoryProvider)
      .watchPages(widget.docId);
  late final Stream<db.Document?> _docStream = ref
      .read(documentRepositoryProvider)
      .watchById(widget.docId);

  @override
  Widget build(BuildContext context) {
    final pagesStream = _pagesStream;

    final picked = _picked;
    return PopScope(
      canPop: picked == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _picked = null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: picked == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => setState(() => _picked = null),
                ),
          title: Text(
            picked == null
                ? context.l10n.reviewTitle
                : context.l10n.reviewSelectedPages(picked.length),
          ),
          actions: [
            if (picked != null)
              const SizedBox.shrink()
            else if (_dirty)
              TextButton(
                onPressed: _saveOrder,
                child: Text(context.l10n.reviewSaveOrder),
              )
            else
              // Hidden while a new order is unsaved: added pages would land
              // outside it.
              StreamBuilder<db.Document?>(
                stream: _docStream,
                builder: (context, snap) {
                  final doc = snap.data;
                  if (doc == null || !canSplitPages(doc)) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('select-pages'),
                        icon: const Icon(Icons.checklist),
                        tooltip: context.l10n.reviewSelectPages,
                        onPressed: _saving
                            ? null
                            : () => setState(() => _picked = {}),
                      ),
                      if (canAddPages(doc))
                        IconButton(
                          key: const ValueKey('add-pages'),
                          icon: const Icon(Icons.note_add_outlined),
                          tooltip: context.l10n.addPages,
                          onPressed: _saving
                              ? null
                              : () => addPages(context, ref, widget.docId),
                        ),
                    ],
                  );
                },
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

            final list = ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              buildDefaultDragHandles: picked == null,
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
                  onApplyToAll: () => _setFilterForAll(filter),
                  onRotate: () => _rotatePage(page),
                  onCrop: _cropping == null ? () => _cropPage(page) : null,
                  onDelete: () => _deletePage(page),
                  picked: picked?.contains(page.id),
                  onTogglePick: () => setState(() {
                    if (!picked!.remove(page.id)) picked.add(page.id);
                  }),
                );
              },
            );
            // The category sorting chose lands a moment after the scan; show it
            // here so a wrong one is corrected straight away.
            return Column(
              children: [
                SortedIntoBar(docId: widget.docId),
                Expanded(child: list),
              ],
            );
          },
        ),
        // Detect Fields is the main path; skipping fields saves the scan as a
        // finished PDF (the organiser use) and goes to Send.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _saving
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : picked != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('copy-pages'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: picked.isEmpty
                            ? null
                            : () => _toNewDocument(move: false),
                        icon: const Icon(Icons.file_copy_outlined),
                        label: Text(context.l10n.reviewCopyToNew),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('move-pages'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        // A document keeps at least one page.
                        onPressed:
                            picked.isEmpty || picked.length >= _pages.length
                            ? null
                            : () => _toNewDocument(move: true),
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: Text(context.l10n.reviewMoveToNew),
                      ),
                    ],
                  )
                : widget.organise
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () async {
                      if (_dirty) await _saveOrder();
                      if (context.mounted) context.pop();
                    },
                    child: Text(context.l10n.actionDone),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: _proceed,
                        icon: const Icon(Icons.auto_awesome),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(context.l10n.reviewDetectFields),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _savePdf,
                        icon: const Icon(Icons.ios_share),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(context.l10n.reviewSkipFieldsSave),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Copies (or moves) the picked pages, with their fields, to a new
  /// document named after this one and the pages taken.
  Future<void> _toNewDocument({required bool move}) async {
    final picked = _picked;
    if (picked == null || picked.isEmpty) return;
    if (_dirty) await _saveOrder();
    if (!mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final doc = await ref
        .read(documentRepositoryProvider)
        .getById(widget.docId);
    final numbers = [
      for (final (i, pg) in _pages.indexed)
        if (picked.contains(pg.id)) i + 1,
    ];
    if (doc == null || !mounted) return;
    final merger = ref.read(mergeServiceProvider);
    final sorter = ref.read(documentSorterProvider);
    final int id;
    try {
      id = await withProgress(
        context,
        l10n.captureSavingPages,
        () => merger.extract(
          widget.docId,
          picked.toList(),
          title: l10n.extractedName(doc.title, numbers.join(', ')),
          move: move,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.newDocumentFailed)));
      return;
    }
    unawaited(sorter.storeAddedPagesText(id, fromPage: 0));
    if (!mounted) return;
    setState(() => _picked = null);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.newDocumentMade),
        // With an action a snackbar stays until dismissed, following the
        // user to other screens; this one is a passing note.
        persist: false,
        action: SnackBarAction(
          label: l10n.actionOpen,
          onPressed: () {
            if (mounted) openNewDocument(context, ref, id);
          },
        ),
      ),
    );
  }

  static PageFilter _filterFromString(String s) => switch (s) {
    'original' => PageFilter.original,
    'bw' => PageFilter.bw,
    'clean' => PageFilter.clean,
    _ => PageFilter.enhanced,
  };

  static String _filterToString(PageFilter f) => switch (f) {
    PageFilter.original => 'original',
    PageFilter.enhanced => 'enhanced',
    PageFilter.clean => 'clean',
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

  /// Review → "Apply to all pages": every image page gets [f].
  void _setFilterForAll(PageFilter f) {
    setState(() {
      for (final pg in _pages) {
        _filters[pg.id] = f;
      }
    });
    ref
        .read(pageRepositoryProvider)
        .setFilterForAll(widget.docId, _filterToString(f));
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

  /// The page whose Crop is open; one at a time.
  int? _cropping;

  /// Opens the corner editor on one page, starting from the whole image,
  /// and comes back here.
  Future<void> _cropPage(db.Page page) async {
    final router = GoRouter.of(context);
    setState(() => _cropping = page.id);
    try {
      final candidate = await ref
          .read(edgeCheckServiceProvider)
          .manualCandidate(page);
      if (!mounted) return;
      await router.push(
        '${AppRoutes.crop.replaceAll(':docId', '${widget.docId}')}?back=1',
        extra: [candidate],
      );
    } catch (e) {
      debugPrint('Review: crop failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.cropFailed)));
      }
    } finally {
      if (mounted) setState(() => _cropping = null);
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

  bool _saving = false;

  /// Saves the scan as a plain PDF. A document that already has fields (the
  /// user came back here) goes to Review & Finish instead, which keeps them.
  Future<void> _savePdf() async {
    if (_dirty) await _saveOrder();
    if (!mounted) return;
    final fields = await ref
        .read(fieldRepositoryProvider)
        .watchFields(widget.docId)
        .first;
    if (!mounted) return;
    if (fields.isNotEmpty) {
      context.push(AppRoutes.press.replaceAll(':docId', '${widget.docId}'));
      return;
    }
    await saveWithoutFields(
      context,
      ref,
      widget.docId,
      onBusy: (b) {
        if (mounted) setState(() => _saving = b);
      },
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
    required this.onApplyToAll,
    required this.onRotate,
    required this.onCrop,
    required this.onDelete,
    this.picked,
    this.onTogglePick,
  });

  final db.Page page;
  final PageFilter filter;
  final int pageNumber;
  final int totalPages;
  final ValueChanged<PageFilter> onFilterChanged;
  final VoidCallback onApplyToAll;
  final VoidCallback onRotate;

  /// Null while a crop is opening.
  final VoidCallback? onCrop;
  final VoidCallback onDelete;

  /// Whether the page is picked, while picking pages; null otherwise.
  final bool? picked;
  final VoidCallback? onTogglePick;

  /// A page of an imported PDF: its content is vector, drawn as-is into the
  /// output, so rotation and the image filters don't apply and aren't shown
  /// (they used to be offered and silently do nothing).
  bool get _isPdfPage => page.imagePath.contains('#page=');

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    final card = Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: picked == true
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            )
          : null,
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
                if (picked != null)
                  Checkbox(
                    value: picked,
                    onChanged: (_) => onTogglePick?.call(),
                  )
                else ...[
                  if (!_isPdfPage) ...[
                    IconButton(
                      key: ValueKey('crop-page-${page.id}'),
                      icon: const Icon(Icons.crop),
                      tooltip: context.l10n.cropApply,
                      onPressed: onCrop,
                    ),
                    IconButton(
                      icon: const Icon(Icons.rotate_right),
                      tooltip: context.l10n.reviewRotateTooltip,
                      onPressed: onRotate,
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: context.l10n.reviewDeletePageTooltip,
                    color: Theme.of(context).colorScheme.error,
                    onPressed: onDelete,
                  ),
                  const Icon(Icons.drag_handle, color: Colors.grey),
                ],
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 0.707,
            child: _FilteredImage(path: page.imagePath, filter: filter),
          ),
          if (_isPdfPage || picked != null)
            const SizedBox(height: 12)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final f in PageFilter.values)
                    ChoiceChip(
                      label: Text(_filterLabel(context, f)),
                      selected: filter == f,
                      onSelected: (_) => onFilterChanged(f),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (totalPages > 1)
                    TextButton.icon(
                      key: ValueKey('filter-all-${page.id}'),
                      onPressed: onApplyToAll,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: Text(context.l10n.filterApplyAll),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTogglePick,
      child: card,
    );
  }

  String _filterLabel(BuildContext context, PageFilter f) => switch (f) {
    PageFilter.original => context.l10n.filterOriginal,
    PageFilter.enhanced => context.l10n.filterEnhanced,
    PageFilter.clean => context.l10n.filterClean,
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
      // Shadows can't be removed by a colour matrix: the page is worked
      // out, at preview size, by the same code the exports use.
      PageFilter.clean => _CleanPreview(path: resolved, fallback: image),
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

/// A page with the Clean filter, made in an isolate at preview size and kept
/// for the pages seen most recently. The plain photo shows meanwhile.
class _CleanPreview extends StatefulWidget {
  const _CleanPreview({required this.path, required this.fallback});
  final String path;
  final Widget fallback;

  /// Wide enough for a page card; the exports work at full size.
  static const _width = 1000;

  static final _cache = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> _load(String path) {
    // Most recent last; a new image path (rotate, crop) is a new entry.
    final f = _cache.remove(path) ?? _make(path);
    _cache[path] = f;
    while (_cache.length > 24) {
      _cache.remove(_cache.keys.first);
    }
    return f;
  }

  static Future<Uint8List?> _make(String path) async {
    try {
      // The platform decoder shrinks while decoding, much faster than
      // decoding a full-size photo in Dart.
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        await File(path).readAsBytes(),
      );
      final desc = await ui.ImageDescriptor.encoded(buffer);
      final codec = await desc.instantiateCodec(
        targetWidth: math.min(desc.width, _width),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final size = (image.width, image.height);
      image.dispose();
      codec.dispose();
      desc.dispose();
      buffer.dispose();
      if (rgba == null) return null;
      return compute(_cleanJpeg, (
        rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        size.$1,
        size.$2,
      ));
    } catch (e) {
      debugPrint('Review: clean preview failed: $e');
      return null;
    }
  }

  @override
  State<_CleanPreview> createState() => _CleanPreviewState();
}

class _CleanPreviewState extends State<_CleanPreview> {
  late Future<Uint8List?> _jpeg = _CleanPreview._load(widget.path);

  @override
  void didUpdateWidget(_CleanPreview old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _jpeg = _CleanPreview._load(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _jpeg,
    builder: (context, snap) {
      final bytes = snap.data;
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      }
      if (snap.connectionState == ConnectionState.done) return widget.fallback;
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.fallback,
          const Center(child: CircularProgressIndicator()),
        ],
      );
    },
  );
}

/// compute() entry: RGBA pixels → the Clean page as JPEG.
Uint8List _cleanJpeg((Uint8List, int, int) args) {
  final (rgba, w, h) = args;
  final page = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(cleanPage(page), quality: 85);
}
