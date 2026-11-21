import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/merge_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/progress_dialog.dart';
import '../../capture/presentation/page_limit_prompt.dart';

/// Library → select documents → Merge: after a confirmation, makes a new
/// document with their pages in the order they were selected, and opens it.
/// Returns whether a document was made.
Future<bool> mergeDocuments(
  BuildContext context,
  WidgetRef ref,
  List<Document> docs,
) async {
  if (docs.length < 2) return false;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.mergeTitle(docs.length)),
      content: Text(l10n.mergeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('merge-confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.libraryMerge),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final merger = ref.read(mergeServiceProvider);
  final int id;
  try {
    id = await withProgress(
      context,
      l10n.captureSavingPages,
      () => merger.merge([
        for (final d in docs) d.id,
      ], title: l10n.mergedName(docs.first.title, docs.length - 1)),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.newDocumentFailed)));
    return false;
  }
  if (!context.mounted) return true;
  await openNewDocument(context, ref, id);
  return true;
}

/// Opens a document made by merging or splitting: after the free page-limit
/// check, Fill mode when it has fields, Review when it doesn't.
Future<void> openNewDocument(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final fields = ref.read(fieldRepositoryProvider);
  final router = GoRouter.of(context);
  await enforcePageLimit(context, ref, id);
  final hasFields = (await fields.watchFields(id).first).isNotEmpty;
  router.push(
    (hasFields ? AppRoutes.fillMode : AppRoutes.review).replaceAll(
      ':docId',
      '$id',
    ),
  );
}
