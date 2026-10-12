import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/document_repository.dart';
import '../../../core/services/fillable_form_export_service.dart';
import '../../../core/services/free_usage_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/paywall_screen.dart';

/// Free tier: may document [docId] be finished now? Opens the paywall (and
/// returns false) when not. See FreeUsageService.
Future<bool> mayFinishDocument(
  BuildContext context,
  WidgetRef ref,
  int docId,
) async {
  final usage = ref.read(freeUsageServiceProvider);
  final doc = await ref.read(documentRepositoryProvider).getById(docId);
  final pages = await ref.read(pageRepositoryProvider).watchPages(docId).first;
  if (doc == null) return false;
  final check = await usage.checkFinish(doc, pageCount: pages.length);
  if (check == FinishCheck.allowed) return true;
  if (!context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(
        reason: check == FinishCheck.tooManyPages
            ? PaywallReason.tooManyPages
            : PaywallReason.allowanceUsed,
      ),
    ),
  );
  // Bought it on the paywall → carry on; otherwise stay here.
  return usage.isPremium();
}

/// Saves a document that has no fields as a plain PDF — the scanner /
/// organiser use — after the user confirms, then opens Send. Counts as a
/// finished document on the free tier, like any other.
///
/// [onBusy] is told when the export starts and, on failure, ends (on success
/// the route is replaced).
Future<void> saveWithoutFields(
  BuildContext context,
  WidgetRef ref,
  int docId, {
  ValueChanged<bool>? onBusy,
}) async {
  // Resolve strings and navigators before any await.
  final l10n = context.l10n;
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.saveNoFieldsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.saveNoFieldsBody),
          const FreeAllowanceNote(padding: EdgeInsets.only(top: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.pressSavePdf),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  if (!await mayFinishDocument(context, ref, docId)) return;

  onBusy?.call(true);
  try {
    await ref.read(fillableFormExportServiceProvider).export(docId);
    await ref.read(freeUsageServiceProvider).recordFinish(docId);
    router.pushReplacement(AppRoutes.send.replaceAll(':docId', '$docId'));
  } catch (e) {
    onBusy?.call(false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e is ExportEmptyDocumentException
              ? l10n.exportErrorNoPages
              : l10n.pressExportFailed('$e'),
        ),
      ),
    );
  }
}

/// "Finishing uses 1 of your 2 free documents" — nothing with Unlimited.
class FreeAllowanceNote extends ConsumerStatefulWidget {
  const FreeAllowanceNote({super.key, this.padding = EdgeInsets.zero});
  final EdgeInsets padding;

  @override
  ConsumerState<FreeAllowanceNote> createState() => _FreeAllowanceNoteState();
}

class _FreeAllowanceNoteState extends ConsumerState<FreeAllowanceNote> {
  // Created once, not per build.
  late final Future<(bool, int)> _usage = () async {
    final usage = ref.read(freeUsageServiceProvider);
    return (await usage.isPremium(), await usage.remaining());
  }();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(bool, int)>(
      future: _usage,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.$1) return const SizedBox.shrink();
        return Padding(
          padding: widget.padding,
          child: Text(
            context.l10n.pressFreeRemaining(
              data.$2,
              FreeUsageService.freeDocuments,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
