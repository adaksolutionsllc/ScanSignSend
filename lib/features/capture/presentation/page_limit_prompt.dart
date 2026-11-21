import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/document_repository.dart';
import '../../../core/services/free_usage_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/paywall_screen.dart';

/// Free documents are limited to [FreeUsageService.freePageLimit] pages.
/// Tell the user right away (not after they've filled page 5): unlock Full
/// Access, or keep the first pages. Asks again if they close the paywall
/// without buying, so the document never silently stays over the limit.
Future<void> enforcePageLimit(
  BuildContext context,
  WidgetRef ref,
  int docId,
) async {
  final usage = ref.read(freeUsageServiceProvider);
  final pageRepo = ref.read(pageRepositoryProvider);
  while (context.mounted) {
    final pages = await pageRepo.watchPages(docId).first;
    if (await usage.pagesAllowed(pages.length) || !context.mounted) return;
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.pageLimitTitle(FreeUsageService.freePageLimit)),
        content: Text(
          ctx.l10n.pageLimitBody(pages.length, FreeUsageService.freePageLimit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.l10n.pageLimitKeepFirst(FreeUsageService.freePageLimit),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.paywallTitle),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (keep == true) {
      // Deleting through the repository also removes those pages' fields.
      for (final page in pages.skip(FreeUsageService.freePageLimit)) {
        await pageRepo.deletePage(page.id);
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaywallScreen(reason: PaywallReason.tooManyPages),
      ),
    );
  }
}
