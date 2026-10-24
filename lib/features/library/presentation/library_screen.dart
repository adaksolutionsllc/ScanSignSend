import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/page_raster_service.dart';
import '../../../core/services/template_service.dart';
import '../../../core/utils/router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/category_ui.dart';
import '../../../shared/widgets/text_edit_dialog.dart';
import '../../../core/utils/l10n_ext.dart';
import 'keyword_sorting_tip.dart';
import 'unlimited_banner.dart';

enum _LibraryTab { all, draft, pressed, template }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _query = '';
  late final TabController _tabController;

  /// Category filter: null shows every document, [_noCategory] the
  /// Uncategorised ones, anything else that category's key.
  String? _category;
  static const _noCategory = '\u0000none';

  /// Selected documents (long-press a card); non-empty = selection mode.
  final _selected = <int>{};
  List<Document> _visible = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      // A selection belongs to the tab it was made on.
      ..addListener(() {
        if (_selected.isNotEmpty) setState(_selected.clear);
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Streams are cached per (tab, query): creating fresh ones on every
  /// rebuild re-subscribed all four tabs whenever a tab was tapped or a key
  /// typed, and each flashed a loading spinner.
  final _streams = <(_LibraryTab, String, String?), Stream<List<Document>>>{};

  Stream<List<Document>> _stream(_LibraryTab tab) {
    if (_streams.length > 32) _streams.clear();
    return _streams[(tab, _query, _category)] ??= _createStream(
      tab,
    ).map(_inCategory);
  }

  List<Document> _inCategory(List<Document> docs) => switch (_category) {
    null => docs,
    _noCategory => docs.where((d) => d.category == null).toList(),
    final key => docs.where((d) => d.category == key).toList(),
  };

  Stream<List<Document>> _createStream(_LibraryTab tab) {
    final repo = ref.read(documentRepositoryProvider);
    final base = _query.isEmpty ? repo.watchAll() : repo.watchByQuery(_query);
    if (tab == _LibraryTab.all) return base;
    final statusStr = switch (tab) {
      _LibraryTab.draft => 'draft',
      _LibraryTab.pressed => 'pressed',
      _LibraryTab.template => 'template',
      _LibraryTab.all => 'all',
    };
    return base.map(
      (docs) => docs.where((d) => d.status == statusStr).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: _scaffold(context, selecting),
    );
  }

  Widget _scaffold(BuildContext context, bool selecting) {
    return Scaffold(
      appBar: AppBar(
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => setState(_selected.clear),
              )
            : null,
        title: Text(
          selecting
              ? context.l10n.librarySelectedCount(_selected.length)
              : context.l10n.appTitle,
        ),
        actions: selecting
            ? [
                IconButton(
                  icon: const Icon(Icons.label_outline),
                  tooltip: context.l10n.categoryChange,
                  onPressed: _changeSelectedCategory,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.actionDelete,
                  onPressed: _deleteSelected,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: context.l10n.settingsTitle,
                  onPressed: () => context.push(AppRoutes.settings),
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  controller: _searchController,
                  hintText: context.l10n.librarySearchHint,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: context.l10n.libraryTabAll),
                  Tab(text: context.l10n.libraryTabDraft),
                  Tab(text: context.l10n.libraryTabCompleted),
                  Tab(text: context.l10n.libraryTabTemplate),
                ],
                onTap: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          const UnlimitedBanner(),
          const KeywordSortingTip(),
          _CategoryFilterBar(
            selected: _category,
            noCategory: _noCategory,
            onSelected: (key) => setState(() => _category = key),
          ),
          Expanded(child: _tabs()),
        ],
      ),
      floatingActionButton: selecting ? null : _actions(),
    );
  }

  void _toggle(Document doc) => setState(() {
    if (!_selected.remove(doc.id)) _selected.add(doc.id);
  });

  List<Document> get _selectedDocs =>
      _visible.where((d) => _selected.contains(d.id)).toList();

  Future<void> _changeSelectedCategory() async {
    await showCategorySheet(context, ref, _selectedDocs);
    if (mounted) setState(_selected.clear);
  }

  Future<void> _deleteSelected() async {
    final docs = _selectedDocs;
    if (docs.isEmpty) return;
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.libraryDeleteManyTitle(docs.length)),
        content: Text(l10n.libraryDeleteManyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final repo = ref.read(documentRepositoryProvider);
    for (final d in docs) {
      await repo.deleteDocument(d.id);
    }
    if (mounted) setState(_selected.clear);
  }

  Widget _tabs() {
    return TabBarView(
      controller: _tabController,
      children: _LibraryTab.values.map((tab) {
        return StreamBuilder<List<Document>>(
          stream: _stream(tab),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data ?? [];
            if (tab == _LibraryTab.values[_tabController.index]) {
              _visible = docs;
            }
            if (docs.isEmpty) return _EmptyState(tab: tab);
            final names = ref.watch(userCategoryNamesProvider);

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: docs.length,
              itemBuilder: (context, i) => _DocumentCard(
                doc: docs[i],
                tab: tab,
                categoryText: categoryLabel(
                  context.l10n,
                  docs[i].category,
                  names,
                ),
                selecting: _selected.isNotEmpty,
                selected: _selected.contains(docs[i].id),
                onToggleSelect: () => _toggle(docs[i]),
                onCategory: () => showCategorySheet(context, ref, [docs[i]]),
                onDelete: () => _deleteDoc(docs[i]),
                onRename: () => _renameDoc(docs[i]),
                onUseTemplate: docs[i].statusEnum == DocumentStatus.template
                    ? () => _useTemplate(docs[i])
                    : null,
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _actions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Both labelled, same size, and each starts its action directly.
        FloatingActionButton.extended(
          heroTag: 'import',
          onPressed: () => context.push('${AppRoutes.capture}?action=import'),
          tooltip: context.l10n.libraryImportTooltip,
          icon: const Icon(Icons.upload_file),
          label: Text(context.l10n.libraryImport),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'scan',
          onPressed: () => context.push('${AppRoutes.capture}?action=scan'),
          icon: const Icon(Icons.document_scanner),
          label: Text(context.l10n.libraryNewScan),
        ),
      ],
    );
  }

  Future<void> _deleteDoc(Document doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.libraryDeleteTitle),
        content: Text(context.l10n.libraryDeleteBody(doc.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(context.l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(documentRepositoryProvider).deleteDocument(doc.id);
    }
  }

  Future<void> _useTemplate(Document doc) async {
    try {
      final newId = await ref.read(templateServiceProvider).useTemplate(doc.id);
      if (mounted) {
        context.push(AppRoutes.fillMode.replaceAll(':docId', '$newId'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.libraryUseTemplateFailed('$e'))),
        );
      }
    }
  }

  Future<void> _renameDoc(Document doc) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => TextEditDialog(
        title: context.l10n.libraryRenameTitle,
        initialValue: doc.title,
        hint: context.l10n.libraryDocumentNameHint,
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await ref
          .read(documentRepositoryProvider)
          .updateDocument(
            DocumentsCompanion(
              id: Value(doc.id),
              title: Value(result.trim()),
              titleEdited: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }
  }
}

// ── Document card ─────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.tab,
    required this.onDelete,
    required this.onRename,
    required this.categoryText,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
    required this.onCategory,
    this.onUseTemplate,
  });

  final Document doc;
  final _LibraryTab tab;
  final String categoryText;

  /// Selection mode: a tap selects instead of opening.
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onCategory;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onUseTemplate;

  static Color _statusColor(DocumentStatus s) => switch (s) {
    DocumentStatus.pressed => AppTheme.statusPressed,
    DocumentStatus.fillable => AppTheme.statusFillable,
    DocumentStatus.template => AppTheme.statusTemplate,
    DocumentStatus.draft => AppTheme.statusDraft,
  };

  static String _statusLabel(BuildContext context, DocumentStatus s) =>
      switch (s) {
        DocumentStatus.pressed => context.l10n.statusCompleted,
        DocumentStatus.fillable => context.l10n.statusEditable,
        DocumentStatus.template => context.l10n.statusTemplate,
        DocumentStatus.draft => context.l10n.statusDraft,
      };

  static IconData _statusIcon(DocumentStatus s) => switch (s) {
    DocumentStatus.pressed => Icons.lock,
    DocumentStatus.fillable => Icons.edit_document,
    DocumentStatus.template => Icons.layers,
    DocumentStatus.draft => Icons.edit,
  };

  @override
  Widget build(BuildContext context) {
    final status = doc.statusEnum;
    // Pattern and locale both come from the active translation so dates read
    // naturally (e.g. "3 déc. 2026", not "Dec 3, 2026") in every language.
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat(
      context.l10n.dateFormatShort,
      locale,
    ).format(doc.updatedAt);
    final isTemplate = status == DocumentStatus.template;
    // Only a pressed (flattened & signed) document is actually locked — it
    // opens read-only in the viewer. Everything else, including a document
    // that's been exported once as a fillable form, stays reachable through
    // fill/sign/press so exporting a shareable snapshot never locks the
    // original out of further editing. Templates spawn a new draft.
    final isLocked = status == DocumentStatus.pressed;
    final showStatusPill = tab == _LibraryTab.all;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: InkWell(
        onLongPress: onToggleSelect,
        onTap: selecting
            ? onToggleSelect
            : isTemplate
            ? onUseTemplate
            : isLocked
            ? () => context.push(
                AppRoutes.viewer.replaceAll(':docId', '${doc.id}'),
              )
            : () => context.push(
                AppRoutes.fillMode.replaceAll(':docId', '${doc.id}'),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A preview of the first page, so documents are recognisable
                  // at a glance; the type icon if it can't be shown.
                  _FirstPageThumb(
                    key: ValueKey('${doc.id}-${doc.updatedAt}'),
                    docId: doc.id,
                    finishedPdf: doc.pressedPdfPath,
                    fallback: Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Icon(
                          isTemplate
                              ? Icons.layers_outlined
                              : status == DocumentStatus.pressed
                              ? Icons.lock_outlined
                              : Icons.description_outlined,
                          size: 48,
                          color: status == DocumentStatus.pressed
                              ? AppTheme.statusPressed.withValues(alpha: 0.5)
                              : isTemplate
                              ? AppTheme.statusTemplate.withValues(alpha: 0.5)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  if (selecting)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        shadows: const [Shadow(blurRadius: 4)],
                        semanticLabel: context.l10n.librarySelect,
                      ),
                    ),
                  // Status pill — only on All tab
                  if (showStatusPill)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(status),
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _statusLabel(context, status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.drive_file_rename_outline, size: 16),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    color: Colors.grey,
                    tooltip: context.l10n.libraryRenameTooltip,
                    onPressed: onRename,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 6, 4),
              child: Text(
                '$dateStr · ${doc.pageCount}p',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
            // The document's category; tap to change it.
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              // Its own node: otherwise the card's tap target swallows it and
              // a screen reader can't reach it.
              child: Semantics(
                container: true,
                button: true,
                label: '${context.l10n.categoryChange}: $categoryText',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: selecting ? onToggleSelect : onCategory,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon(doc.category),
                          size: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            categoryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Inline actions: Edit + Delete on every card ─────────────────
            // "Edit" adapts to the doc type: not-yet-pressed → fill mode
            // (fill/sign/re-sign, even if a fillable copy was shared before),
            // pressed (locked) → read-only viewer, templates → spawn a draft.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: isLocked
                          ? Icons.visibility_outlined
                          : Icons.edit_outlined,
                      label: isLocked
                          ? context.l10n.actionOpen
                          : context.l10n.actionEdit,
                      onTap: () {
                        if (isTemplate) {
                          onUseTemplate?.call();
                        } else if (isLocked) {
                          context.push(
                            AppRoutes.viewer.replaceAll(':docId', '${doc.id}'),
                          );
                        } else {
                          context.push(
                            AppRoutes.fillMode.replaceAll(
                              ':docId',
                              '${doc.id}',
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_outline,
                      label: context.l10n.actionDelete,
                      color: Theme.of(context).colorScheme.error,
                      onTap: onDelete,
                    ),
                  ),
                ],
              ),
            ),

            // ── Template "Use" button ───────────────────────────────────────
            if (isTemplate && tab == _LibraryTab.template)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onUseTemplate,
                    icon: const Icon(Icons.copy_outlined, size: 14),
                    label: Text(context.l10n.libraryUseTemplate),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.statusTemplate,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c =
        color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: c,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});
  final _LibraryTab tab;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tab) {
      _LibraryTab.draft => (
        Icons.edit_document,
        context.l10n.emptyDraftsTitle,
        context.l10n.emptyDraftsBody,
      ),
      _LibraryTab.pressed => (
        Icons.lock_outlined,
        context.l10n.emptyPressedTitle,
        context.l10n.emptyPressedBody,
      ),
      _LibraryTab.template => (
        Icons.layers_outlined,
        context.l10n.emptyTemplatesTitle,
        context.l10n.emptyTemplatesBody,
      ),
      _LibraryTab.all => (
        Icons.document_scanner_outlined,
        context.l10n.emptyAllTitle,
        context.l10n.emptyAllBody,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// The first page of a document as a card thumbnail (scans and imported PDF
/// pages alike, via the page renderer's cache). Shows [fallback] while
/// loading or if the page can't be read.
class _FirstPageThumb extends ConsumerStatefulWidget {
  const _FirstPageThumb({
    super.key,
    required this.docId,
    required this.fallback,
    this.finishedPdf,
  });
  final int docId;
  final Widget fallback;

  /// A completed document's flattened PDF: its first page (filled in and
  /// signed) is the thumbnail, rather than the blank original.
  final String? finishedPdf;

  @override
  ConsumerState<_FirstPageThumb> createState() => _FirstPageThumbState();
}

class _FirstPageThumbState extends ConsumerState<_FirstPageThumb> {
  late final Future<String?> _path = _load();

  Future<String?> _load() async {
    try {
      final raster = ref.read(pageRasterServiceProvider);
      final finished = widget.finishedPdf;
      if (finished != null && finished.isNotEmpty) {
        try {
          return await raster.imageFor('$finished#page=0');
        } catch (_) {
          // Fall back to the original first page below.
        }
      }
      final pages = await ref
          .read(pageRepositoryProvider)
          .watchPages(widget.docId)
          .first;
      if (pages.isEmpty) return null;
      return await ref
          .read(pageRasterServiceProvider)
          .imageFor(pages.first.imagePath);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _path,
      builder: (context, snap) {
        final path = snap.data;
        if (path == null || !File(path).existsSync()) return widget.fallback;
        return ColoredBox(
          color: Colors.white,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 400,
            errorBuilder: (_, _, _) => widget.fallback,
          ),
        );
      },
    );
  }
}

// ── Category filter ───────────────────────────────────────────────────────────

/// One chip per category that has documents (plus "No category" when some
/// have none), above the tabs' grids. Hidden until there is something to
/// choose between.
class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar({
    required this.selected,
    required this.noCategory,
    required this.onSelected,
  });

  final String? selected;
  final String noCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(_allDocumentsProvider).valueOrNull ?? const [];
    final names = ref.watch(userCategoryNamesProvider);
    final used = <String>{for (final d in docs) ?d.category};
    final hasNone = docs.any((d) => d.category == null);
    if (used.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final keys = used.toList()
      ..sort(
        (a, b) => categoryLabel(
          l10n,
          a,
          names,
        ).toLowerCase().compareTo(categoryLabel(l10n, b, names).toLowerCase()),
      );

    Widget chip(String? key, String label, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16),
        label: Text(label),
        selected: selected == key,
        onSelected: (_) => onSelected(selected == key ? null : key),
      ),
    );

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        children: [
          chip(null, l10n.libraryTabAll),
          for (final k in keys)
            chip(k, categoryLabel(l10n, k, names), icon: categoryIcon(k)),
          if (hasNone)
            chip(noCategory, l10n.categoryNone, icon: categoryIcon(null)),
        ],
      ),
    );
  }
}

final _allDocumentsProvider = StreamProvider<List<Document>>(
  (ref) => ref.watch(documentRepositoryProvider).watchAll(),
);
