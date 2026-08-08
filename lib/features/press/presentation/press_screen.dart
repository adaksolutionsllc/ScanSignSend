import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/fillable_form_export_service.dart';
import '../../../core/services/press_service.dart';
import '../../../core/utils/router.dart';

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
  late final Stream<List<Field>> _fieldsStream =
      ref.read(fieldRepositoryProvider).watchFields(widget.docId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Press')),
      body: StreamBuilder<List<Field>>(
        stream: _fieldsStream,
        builder: (context, snapshot) {
          final fields = snapshot.data ?? [];
          final filled =
              fields.where((f) => f.isFilled).length;
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
                      Text('Field Summary',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _SummaryRow(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          label: 'Filled',
                          count: filled),
                      if (unfilled > 0)
                        _SummaryRow(
                            icon: Icons.warning_amber_rounded,
                            color: Colors.amber.shade700,
                            label: 'Unfilled',
                            count: unfilled),
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
                    // Primary, safe default: keep fields editable.
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _exportFillable(context),
                        icon: const Icon(Icons.edit_document),
                        label: const Text('Save as Fillable Form'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Deliberate, irreversible: flatten + lock.
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmPress(context),
                        icon: Icon(Icons.lock_outline,
                            color: Theme.of(context).colorScheme.error),
                        label: Text(
                          'Flatten & Sign (locks the document)',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.5)),
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
  Future<void> _exportFillable(BuildContext context) async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(fillableFormExportServiceProvider)
          .export(widget.docId);
      if (mounted) {
        router.pushReplacement(
          AppRoutes.send.replaceAll(':docId', '${widget.docId}'),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _confirmPress(BuildContext context) async {
    // D3 guardrail: if this document carries live (AcroForm) fields, warn that
    // flattening throws away their interactivity.
    final fields =
        await ref.read(fieldRepositoryProvider).watchFields(widget.docId).first;
    final hasLiveFields = fields.any((f) => f.sourceKind == 'acroform');
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flatten & lock this document?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flattening bakes your entries into a new PDF. The result is '
              'permanent — no one can edit it afterward, including you.',
            ),
            if (hasLiveFields) ...[
              const SizedBox(height: 12),
              Text(
                'This document has interactive form fields. Flattening removes '
                'them — to keep them editable, choose “Save as Fillable Form” '
                'instead.',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Note: a drawn signature here is a visual mark, not a certified '
              'digital e-signature.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError),
            child: const Text('Flatten & Lock'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    // ignore: use_build_context_synchronously
    final router = GoRouter.of(context);
    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pressedPath =
          await ref.read(pressServiceProvider).press(widget.docId);
      debugPrint('Pressed PDF: $pressedPath');
      if (mounted) {
        router.pushReplacement(
          AppRoutes.send.replaceAll(':docId', '${widget.docId}'),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Press failed: $e')),
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
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Working…'),
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
        field.isFilled ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        color: field.isFilled ? Colors.green : Colors.amber.shade700,
        size: 20,
      ),
      title: Text(
        field.label.isNotEmpty ? field.label : _typeName(type),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: field.isFilled
          ? Text(
              _displayValue(field, type),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              'Not filled',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.amber.shade700),
            ),
      trailing: Chip(
        label: Text(_typeName(type),
            style: const TextStyle(fontSize: 10)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _typeName(FieldType t) => switch (t) {
        FieldType.text => 'Text',
        FieldType.date => 'Date',
        FieldType.checkbox => 'Checkbox',
        FieldType.signature => 'Signature',
      };

  String _displayValue(Field f, FieldType t) => switch (t) {
        FieldType.checkbox => f.isChecked ? 'Checked ✓' : 'Unchecked',
        FieldType.signature => 'Signature captured',
        _ => f.value,
      };
}
