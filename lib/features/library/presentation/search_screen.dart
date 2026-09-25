import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/utils/router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/l10n_ext.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(documentRepositoryProvider);
    final stream = _query.isEmpty
        ? repo.watchAll()
        : repo.watchByQuery(_query);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.librarySearchHint,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: StreamBuilder<List<Document>>(
        stream: stream,
        builder: (context, snapshot) {
          final docs = snapshot.data ?? [];
          if (docs.isEmpty && _query.isNotEmpty) {
            return Center(
              child: Text(context.l10n.searchNoResults(_query)),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final status = doc.statusEnum;
              return ListTile(
                leading: Icon(
                  status == DocumentStatus.pressed
                      ? Icons.lock
                      : status == DocumentStatus.template
                          ? Icons.layers
                          : Icons.description_outlined,
                  color: switch (status) {
                    DocumentStatus.pressed => AppTheme.statusPressed,
                    DocumentStatus.fillable => AppTheme.statusFillable,
                    DocumentStatus.template => AppTheme.statusTemplate,
                    DocumentStatus.draft => AppTheme.statusDraft,
                  },
                ),
                title: Text(doc.title),
                subtitle: Text(
                    '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  status == DocumentStatus.pressed
                      ? AppRoutes.viewer.replaceAll(':docId', '${doc.id}')
                      : AppRoutes.fillMode.replaceAll(':docId', '${doc.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
