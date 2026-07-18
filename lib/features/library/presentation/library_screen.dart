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
    return base.map(
      (docs) => docs.where((d) => d.status == statusStr).toList(),
    );
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
              if (docs.isEmpty) return const _EmptyState();
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) => _DocumentCard(
                  doc: docs[i],
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
      final newId =
          await ref.read(templateServiceProvider).useTemplate(doc.id);
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
    if (result != null && result.isNotEmpty) {
      await ref.read(documentRepositoryProvider).updateDocument(
            DocumentsCompanion(
              id: Value(doc.id),
              title: Value(result),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.onDelete,
    required this.onRename,
    this.onUseTemplate,
  });

  final Document doc;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback? onUseTemplate;

  Color _chipColor(DocumentStatus s) => switch (s) {
        DocumentStatus.pressed => AppTheme.statusPressed,
        DocumentStatus.template => AppTheme.statusTemplate,
        DocumentStatus.draft => AppTheme.statusDraft,
      };

  String _chipLabel(DocumentStatus s) => switch (s) {
        DocumentStatus.pressed => 'Pressed',
        DocumentStatus.template => 'Template',
        DocumentStatus.draft => 'Draft',
      };

  IconData _chipIcon(DocumentStatus s) => switch (s) {
        DocumentStatus.pressed => Icons.lock,
        DocumentStatus.template => Icons.layers,
        DocumentStatus.draft => Icons.edit,
      };

  void _showCardMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                onRename();
              },
            ),
            if (onUseTemplate != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Use as Template'),
                onTap: () {
                  Navigator.pop(ctx);
                  onUseTemplate!();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text('Delete',
                  style:
                      TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = doc.statusEnum;
    final dateStr = DateFormat('MMM d, yyyy').format(doc.updatedAt);

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the stream update handle removal
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            AppRoutes.fillMode.replaceAll(':docId', '${doc.id}'),
          ),
          onLongPress: () => _showCardMenu(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  child: Center(
                    child: Icon(
                      status == DocumentStatus.pressed
                          ? Icons.lock
                          : Icons.description_outlined,
                      size: 48,
                      color: status == DocumentStatus.pressed
                          ? AppTheme.statusPressed.withValues(alpha: 0.5)
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr · ${doc.pageCount}p',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      avatar: Icon(_chipIcon(status),
                          size: 14, color: Colors.white),
                      label: Text(
                        _chipLabel(status),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: _chipColor(status),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.document_scanner_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No documents yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap "New Scan" to get started.\nScan → Sign → Send.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
