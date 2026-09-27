import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/fillable_form_export_service.dart';
import '../../../core/services/press_service.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/field_type_labels.dart';
import '../../../core/services/free_usage_service.dart';
import '../../../core/services/iap_service.dart' show isPurchasedProvider;
import '../../../shared/widgets/paywall_screen.dart';

class PressScreen extends ConsumerStatefulWidget {
  const PressScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<PressScreen> createState() => _PressScreenState();
}

class _PressScreenState extends ConsumerState<PressScreen> {
  bool _busy = false;

  // Created once — building a fresh drift stream in build() re-subscribes every
  // frame and can spin a rebuild loop. See fill_mode_screen.dart.
  late final Stream<List<Field>> _fieldsStream = ref
      .read(fieldRepositoryProvider)
      .watchFields(widget.docId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.pressTitle)),
      body: StreamBuilder<List<Field>>(
        stream: _fieldsStream,
        builder: (context, snapshot) {
          final fields = snapshot.data ?? [];
          final filled = fields.where((f) => f.isFilled).length;
          final unfilled = fields.length - filled;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.pressFieldSummary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        icon: Icons.check_circle,
                        color: Colors.green,
                        label: context.l10n.pressFilled,
                        count: filled,
                      ),
                      if (unfilled > 0)
                        _SummaryRow(
                          icon: Icons.warning_amber_rounded,
                          color: Colors.amber.shade700,
                          label: context.l10n.pressUnfilled,
                          count: unfilled,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Field list
              ...fields.map((f) => _FieldTile(field: f)),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _busy
              ? const _BusyBar()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _FreeAllowanceNote(),
                    // Primary, safe default: keep fields editable.
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _exportFillable(context),
                        icon: const Icon(Icons.edit_document),
                        label: Text(context.l10n.pressSaveDraft),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Deliberate, irreversible: flatten + lock.
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmPress(context),
                        icon: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(
                          context.l10n.pressFlattenAndSign,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Save-as-Fillable exit: exports a live AcroForm PDF (fields stay editable).
  /// Free tier: may this document be finished? Opens the paywall (and
  /// returns false) when not. See FreeUsageService.
  Future<bool> _mayFinish(BuildContext context) async {
    final usage = ref.read(freeUsageServiceProvider);
    final doc = await ref
        .read(documentRepositoryProvider)
        .getById(widget.docId);
    final pages = await ref
        .read(pageRepositoryProvider)
        .watchPages(widget.docId)
        .first;
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

  Future<void> _exportFillable(BuildContext context) async {
    if (_busy) return; // a second tap must not export twice
    if (!await _mayFinish(context) || !context.mounted) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Resolve strings up front — the catch below runs past an async gap.
    final l10n = context.l10n;
    try {
      await ref.read(fillableFormExportServiceProvider).export(widget.docId);
      await ref.read(freeUsageServiceProvider).recordFinish(widget.docId);
      if (mounted) {
        router.pushReplacement(
          AppRoutes.send.replaceAll(':docId', '${widget.docId}'),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
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

  /// Set while the confirm dialog is being prepared/shown, so a quick
  /// double tap can't open two dialogs and press the document twice.
  bool _confirming = false;

  Future<void> _confirmPress(BuildContext context) async {
    if (_busy || _confirming) return;
    _confirming = true;
    try {
      await _confirmPressOnce(context);
    } finally {
      _confirming = false;
    }
  }

  Future<void> _confirmPressOnce(BuildContext context) async {
    if (!await _mayFinish(context) || !context.mounted) return;
    // D3 guardrail: if this document carries live (AcroForm) fields, warn that
    // flattening throws away their interactivity.
    final fields = await ref
        .read(fieldRepositoryProvider)
        .watchFields(widget.docId)
        .first;
    final hasLiveFields = fields.any((f) => f.sourceKind == 'acroform');
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.pressConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.pressConfirmBody),
            if (hasLiveFields) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.pressConfirmLiveFields,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              context.l10n.pressConfirmNote,
              style: Theme.of(
                ctx,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(context.l10n.pressFlattenAndLock),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // The certificate page is baked inside a background isolate that can't
    // reach AppLocalizations, so its copy is resolved here and passed in.
    final cert = PressCertificateStrings(
      title: l10n.certTitle,
      documentLabel: l10n.certDocument,
      signedOnLabel: l10n.certSignedOn,
      methodLabel: l10n.certMethod,
      methodValue: l10n.certMethodValue,
      noteLabel: l10n.certNote,
      noteValue: l10n.certNoteValue,
      dateFormat: l10n.certDateFormat,
      localeName: Localizations.localeOf(context).toString(),
    );
    try {
      final pressedPath = await ref
          .read(pressServiceProvider)
          .press(widget.docId, cert);
      await ref.read(freeUsageServiceProvider).recordFinish(widget.docId);
      debugPrint('Pressed PDF: $pressedPath');
      if (mounted) {
        router.pushReplacement(
          AppRoutes.send.replaceAll(':docId', '${widget.docId}'),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is PressEmptyDocumentException
                ? l10n.pressErrorNoPages
                : l10n.pressFailed('$e'),
          ),
        ),
      );
    }
  }
}

/// Progress bar shown while either export path runs.
class _BusyBar extends StatelessWidget {
  const _BusyBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(context.l10n.pressWorking),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text('$count $label field${count == 1 ? '' : 's'}'),
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.field});
  final Field field;

  @override
  Widget build(BuildContext context) {
    final type = field.type.toFieldType();
    return ListTile(
      dense: true,
      leading: Icon(
        field.isFilled
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
        color: field.isFilled ? Colors.green : Colors.amber.shade700,
        size: 20,
      ),
      title: Text(
        field.label.isNotEmpty ? field.label : _typeName(context, type),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: field.isFilled
          ? Text(
              _displayValue(context, field, type),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              context.l10n.pressNotFilled,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.amber.shade700),
            ),
      trailing: Chip(
        label: Text(
          _typeName(context, type),
          style: const TextStyle(fontSize: 10),
        ),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _typeName(BuildContext context, FieldType t) =>
      fieldTypeName(context, t);

  String _displayValue(BuildContext context, Field f, FieldType t) =>
      switch (t) {
        FieldType.checkbox =>
          f.isChecked ? context.l10n.pressChecked : context.l10n.pressUnchecked,
        FieldType.radio =>
          f.isChecked
              ? context.l10n.pressRadioSelected
              : context.l10n.pressRadioNotSelected,
        FieldType.signature ||
        FieldType.initials => context.l10n.pressSignatureCaptured,
        _ => f.value,
      };
}

/// "Finishing uses 1 of your 2 free documents (2 left)" for free users, so
/// the allowance is never a surprise. Nothing with Full Access.
class _FreeAllowanceNote extends ConsumerWidget {
  const _FreeAllowanceNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(isPurchasedProvider).valueOrNull ?? true;
    if (premium) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: ref.read(freeUsageServiceProvider).remaining(),
      builder: (context, snap) {
        final left = snap.data;
        if (left == null) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            context.l10n.pressFreeRemaining(
              left,
              FreeUsageService.freeDocuments,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
