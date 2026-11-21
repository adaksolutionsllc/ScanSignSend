import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/app_lock_provider.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/document_sorter.dart';
import '../../../core/services/edge_check_service.dart';
import '../../../core/services/free_usage_service.dart';
import '../../../core/services/import_service.dart';
import '../../../core/services/scan_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';
import '../../capture/presentation/page_limit_prompt.dart';

/// Whether [doc] can take more pages: drafts and fillable documents. A
/// completed document is final, a template is copied rather than changed,
/// and a PDF with its own form fields stays that PDF (its form can't carry
/// scanned pages).
bool canAddPages(Document doc) =>
    !doc.hasFormFields &&
    (doc.statusEnum == DocumentStatus.draft ||
        doc.statusEnum == DocumentStatus.fillable);

enum _Source { scan, photos }

/// "Add pages": asks scan or photos, appends what the user brings after the
/// document's last page, and checks the edges of added photos. Pages of an
/// imported PDF are turned into images first, since a document's pages are
/// all one kind.
///
/// Returns the position of the first new page, or null when nothing was
/// added (cancelled, failed, or removed again at the free page limit).
Future<int?> addPages(BuildContext context, WidgetRef ref, int docId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final source = await showModalBottomSheet<_Source>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(ctx.l10n.captureScanWithCamera),
            onTap: () => Navigator.pop(ctx, _Source.scan),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(ctx.l10n.addPagesPhotos),
            onTap: () => Navigator.pop(ctx, _Source.photos),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  final importer = ref.read(importServiceProvider);
  final edges = ref.read(edgeCheckServiceProvider);
  final sorter = ref.read(documentSorterProvider);
  final lock = ref.read(appLockProvider.notifier);
  final pageRepo = ref.read(pageRepositoryProvider);
  final usage = ref.read(freeUsageServiceProvider);
  final scanner = ref.read(scanServiceProvider);
  final savingText = l10n.captureSavingPages;
  final before = (await pageRepo.pagesOf(docId)).length;

  /// Copying photos, and turning an imported PDF's pages into images, take
  /// a few seconds: show that something is happening.
  Future<List<int>> saving(Future<List<int>> Function() work) async {
    if (!context.mounted) return work();
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(savingText)),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      return await work();
    } finally {
      nav.pop();
    }
  }

  List<int> added;
  try {
    switch (source) {
      case _Source.scan:
        final premium = await usage.isPremium();
        final paths = await lock.whileExternal(
          () => scanner.scan(
            pageLimit: premium ? null : FreeUsageService.freePageLimit,
          ),
        );
        if (paths.isEmpty) return null;
        added = await saving(() async {
          await edges.convertPdfPages(docId);
          return importer.appendScans(docId, paths);
        });
      case _Source.photos:
        final files = await lock.whileExternal(importer.pickPhotos);
        if (files.isEmpty) return null;
        added = await saving(() async {
          await edges.convertPdfPages(docId);
          return importer.appendPhotos(docId, files);
        });
    }
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.addPagesFailed)));
    return null;
  }
  if (added.isEmpty || !context.mounted) return null;

  await enforcePageLimit(context, ref, docId);
  final kept = [
    for (final pg in await pageRepo.pagesOf(docId))
      if (added.contains(pg.id)) pg.id,
  ];
  if (kept.isEmpty) return null;
  unawaited(sorter.storeAddedPagesText(docId, fromPage: before));

  // The scanner straightens its own pages; photos get the 1.3.0 edge check.
  if (source == _Source.photos) {
    final candidates = await edges.candidatesFor(
      docId,
      onlyPageIds: kept.toSet(),
    );
    if (candidates.isNotEmpty && context.mounted) {
      await context.push(
        '${AppRoutes.crop.replaceAll(':docId', '$docId')}?back=1',
        extra: candidates,
      );
    }
  }
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.addPagesAdded(kept.length))),
  );
  return before;
}
