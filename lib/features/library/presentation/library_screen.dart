import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/template_service.dart';
import '../../../core/utils/router.dart';
import '../../../shared/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<Document>> _stream(_LibraryTab tab) {
    final repo = ref.read(documentRepositoryProvider);
    final base = _query.isEmpty ? repo.watchAll() : repo.watchByQuery(_query);
    if (tab == _LibraryTab.all) return base;
    final statusStr = switch (tab) {
      _LibraryTab.draft => 'draft',
      _LibraryTab.pressed => 'pressed',
      _LibraryTab.template => 'template',
      _LibraryTab.all => 'all',
    };
    return base.map((docs) => docs.where((d) => d.status == statusStr).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Sign Send'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
                  hintText: 'Search documents…',
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
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Draft'),
                  Tab(text: 'Pressed'),
                  Tab(text: 'Template'),
                ],
                onTap: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _LibraryTab.values.map((tab) {
          return StreamBuilder<List<Document>>(
            stream: _stream(tab),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data ?? [];
              if (docs.isEmpty) return _EmptyState(tab: tab);

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
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            onPressed: () => context.push(AppRoutes.capture),
            tooltip: 'Import PDF / Image',
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => context.push(AppRoutes.capture),
            icon: const Icon(Icons.document_scanner),
            label: const Text('New Scan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDoc(Document doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Delete "${doc.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
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
          SnackBar(content: Text('Failed to use template: $e')),
        );
      }
    }
  }

  Future<void> _renameDoc(Document doc) async {
    final ctrl = TextEditingController(text: doc.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Document name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.trim().isNotEmpty) {
      await ref.read(documentRepositoryProvider).updateDocument(
            DocumentsCompanion(
              id: Value(doc.id),
              title: Value(result.trim()),
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
    this.onUseTemplate,
  });

  final Document doc;
  final _LibraryTab tab;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onUseTemplate;

  static Color _statusColor(DocumentStatus s) => switch (s) {
        DocumentStatus.pressed => AppTheme.statusPressed,
        DocumentStatus.fillable => AppTheme.statusFillable,
        DocumentStatus.template => AppTheme.statusTemplate,
        DocumentStatus.draft => AppTheme.statusDraft,
      };

  static String _statusLabel(DocumentStatus s) => switch (s) {
        DocumentStatus.pressed => 'Pressed',
        DocumentStatus.fillable => 'Fillable',
        DocumentStatus.template => 'Template',
        DocumentStatus.draft => 'Draft',
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
    final dateStr = DateFormat('MMM d, yyyy').format(doc.updatedAt);
    final isDraft = status == DocumentStatus.draft;
    final isTemplate = status == DocumentStatus.template;
    // Exported docs (pressed/fillable) open in the viewer; drafts open in fill
    // mode; templates spawn a new draft.
    final isExported = status == DocumentStatus.pressed ||
        status == DocumentStatus.fillable;
    final showStatusPill = tab == _LibraryTab.all;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isTemplate
            ? onUseTemplate
            : isExported
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
                  Container(
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
                  // Status pill — only on All tab
                  if (showStatusPill)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(status),
                                size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              _statusLabel(status),
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
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.drive_file_rename_outline, size: 16),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    color: Colors.grey,
                    tooltip: 'Rename',
                    onPressed: onRename,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text(
                '$dateStr · ${doc.pageCount}p',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),

            // ── Inline actions (Draft tab + All tab for drafts) ─────────────
            if (isDraft && (tab == _LibraryTab.draft || tab == _LibraryTab.all))
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () => context.push(
                          AppRoutes.fillMode.replaceAll(':docId', '${doc.id}'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
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
                    label: const Text('Use Template'),
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
    final c = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
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
                      fontSize: 11, color: c, fontWeight: FontWeight.w500),
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
          'No drafts',
          'Start a new scan to create a draft.',
        ),
      _LibraryTab.pressed => (
          Icons.lock_outlined,
          'No pressed documents',
          'Fill and press a draft to see it here.',
        ),
      _LibraryTab.template => (
          Icons.layers_outlined,
          'No templates yet',
          'When you press a document, a reusable\ntemplate is saved here automatically.',
        ),
      _LibraryTab.all => (
          Icons.document_scanner_outlined,
          'No documents yet',
          'Tap "New Scan" to get started.\nScan → Sign → Send.',
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
