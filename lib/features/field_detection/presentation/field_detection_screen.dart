import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/import_service.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/field_box.dart';
import '../../../shared/widgets/field_type_labels.dart';
import '../../../shared/widgets/page_canvas.dart';
import 'field_detection_notifier.dart';

const _kHasFormFields = ImportService.formFieldsSentinel;

class FieldDetectionScreen extends ConsumerStatefulWidget {
  const FieldDetectionScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<FieldDetectionScreen> createState() =>
      _FieldDetectionScreenState();
}

class _FieldDetectionScreenState extends ConsumerState<FieldDetectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final doc = await ref
          .read(documentRepositoryProvider)
          .getById(widget.docId);
      final notifier = ref.read(
        fieldDetectionNotifierProvider(widget.docId).notifier,
      );
      final existingFields = await ref
          .read(fieldRepositoryProvider)
          .watchFields(widget.docId)
          .first;
      // Load instead of detecting when:
      //  - the PDF brought its own form (its fields show locked, and the
      //    user can add more around them), or
      //  - the user has been here before (e.g. "Edit fields" from Fill
      //    mode) — re-detecting would discard their positions and edits.
      if ((doc != null && doc.ocrText == _kHasFormFields) ||
          existingFields.any((f) => f.sourceKind == 'app')) {
        await notifier.loadExisting();
        return;
      }
      notifier.run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fieldDetectionNotifierProvider(widget.docId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.detectTitle),
        actions: state.phase == DetectionPhase.done
            ? [
                TextButton(
                  onPressed: () => _confirmAll(context),
                  child: Text(context.l10n.detectConfirmAll),
                ),
              ]
            : null,
      ),
      body: switch (state.phase) {
        DetectionPhase.idle || DetectionPhase.running => _RunningView(
          message: switch (state) {
            _ when state.phase == DetectionPhase.idle =>
              context.l10n.detectStarting,
            _ when state.progressTotal == 0 => context.l10n.detectReading,
            _ => context.l10n.detectAnalysingPage(
              state.progressCurrent,
              state.progressTotal,
            ),
          },
        ),
        DetectionPhase.error => _ErrorView(
          message: state.errorMessage ?? context.l10n.detectUnknownError,
          onRetry: () => ref
              .read(fieldDetectionNotifierProvider(widget.docId).notifier)
              .run(),
        ),
        DetectionPhase.done => _EditorView(
          docId: widget.docId,
          state: state,
          notifier: ref.read(
            fieldDetectionNotifierProvider(widget.docId).notifier,
          ),
          onProceed: () => _proceed(context),
        ),
      },
    );
  }

  bool _proceeding = false;

  Future<void> _confirmAll(BuildContext context) async {
    ref
        .read(fieldDetectionNotifierProvider(widget.docId).notifier)
        .confirmAll();
    await _proceed(context);
  }

  Future<void> _proceed(BuildContext context) async {
    // Fields are already saved as they're edited; this only waits for the
    // last writes. The guard stops a double tap pushing Fill mode twice.
    if (_proceeding) return;
    _proceeding = true;
    try {
      final notifier = ref.read(
        fieldDetectionNotifierProvider(widget.docId).notifier,
      );
      notifier.commitLearning();
      await notifier.flush();
      if (context.mounted) {
        context.pushReplacement(
          AppRoutes.fillMode.replaceAll(':docId', '${widget.docId}'),
        );
      }
    } finally {
      _proceeding = false;
    }
  }
}

// ── Running ───────────────────────────────────────────────────────────────────

class _RunningView extends StatelessWidget {
  const _RunningView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.detectOnDeviceNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.detectFailed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor ────────────────────────────────────────────────────────────────────

class _EditorView extends ConsumerStatefulWidget {
  const _EditorView({
    required this.docId,
    required this.state,
    required this.notifier,
    required this.onProceed,
  });

  final int docId;
  final FieldDetectionState state;
  final FieldDetectionNotifier notifier;
  final VoidCallback onProceed;

  @override
  ConsumerState<_EditorView> createState() => _EditorViewState();
}

/// Assemble fields: tap a toolbar button to drop that field on the page; tap
/// a field to select it (delete button + resize handle appear); tap it again
/// to edit its name/type; drag to move; pinch to resize; tap the page to
/// deselect.
class _EditorViewState extends ConsumerState<_EditorView> {
  // Created once — a fresh drift stream per build re-subscribes every frame.
  late final Stream<List<db.Page>> _pages = ref
      .read(pageRepositoryProvider)
      .watchPages(widget.docId);

  /// Width / height of the page on screen, captured from the last layout so
  /// new checkboxes and radios come out square. A4 until the page is measured.
  double _pageAspect = 0.707;

  EditableField? _selected;

  /// Staggers successive toolbar adds so they don't land exactly on top of
  /// each other.
  int _addCount = 0;

  FieldDetectionState get state => widget.state;
  FieldDetectionNotifier get notifier => widget.notifier;

  void _select(EditableField? f) {
    if (identical(_selected, f)) return;
    setState(() => _selected = f);
    if (f != null) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    // A field deleted elsewhere (edit sheet) can't stay selected.
    if (_selected != null && !state.fields.contains(_selected)) {
      _selected = null;
    }

    return StreamBuilder<List<db.Page>>(
      stream: _pages,
      builder: (context, snapshot) {
        final pageList = snapshot.data ?? [];
        if (pageList.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(child: Text(context.l10n.detectNoPages));
        }

        final pageIndex = state.currentPageIndex.clamp(0, pageList.length - 1);
        final currentPage = pageList[pageIndex];
        final pageFields = state.fields
            .where((f) => f.pageIndex == pageIndex)
            .toList();
        final sel = _selected;
        final radioSelected = sel != null && sel.type == FieldType.radio;

        return Column(
          children: [
            // ── Page + overlays ────────────────────────────────────────────
            Expanded(
              child: PageCanvas(
                storedPath: currentPage.imagePath,
                onTapPage: (_) => _select(null),
                overlayBuilder: (context, pageRect) {
                  _pageAspect = pageRect.width / pageRect.height;
                  return [
                    // The PDF's own form fields: shown for context, locked.
                    for (final f in state.formFields)
                      if (f.pageIndex == pageIndex)
                        FieldBox(
                          key: ValueKey('form-${f.id}'),
                          bbox: BoundingBox.fromJsonString(f.boundingBoxJson),
                          pageRect: pageRect,
                          color: Colors.blueGrey,
                          shape: shapeFor(f.type.toFieldType()),
                          movable: false,
                          resizable: false,
                          showHandles: false,
                          onTap: () => ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.detectFormFieldLocked,
                                ),
                              ),
                            ),
                          onChanged: (_) {},
                          child: f.type.toFieldType().isToggle
                              ? const SizedBox.expand()
                              : const Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 2),
                                    child: Icon(
                                      Icons.lock_outline,
                                      size: 10,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                        ),
                    for (final f in pageFields)
                      FieldBox(
                        key: ObjectKey(f),
                        bbox: f.bbox,
                        pageRect: pageRect,
                        color: colorFor(f.type),
                        shape: shapeFor(f.type),
                        selected: identical(f, sel),
                        highlighted:
                            radioSelected &&
                            f.type == FieldType.radio &&
                            f.radioGroup == sel.radioGroup,
                        showHandles: identical(f, sel),
                        onDelete: () => _delete(f),
                        onGestureStart: () => _select(f),
                        onTap: () => identical(f, _selected)
                            ? _showFieldSheet(context, f)
                            : _select(f),
                        onChanged: (b) =>
                            notifier.updateBbox(state.fields.indexOf(f), b),
                        child: f.type.isToggle
                            ? const SizedBox.expand()
                            : _TypeBadge(type: f.type, label: f.label.trim()),
                      ),
                  ];
                },
              ),
            ),

            // ── Page picker ────────────────────────────────────────────────
            if (pageList.length > 1)
              _PagePicker(
                pageCount: pageList.length,
                currentIndex: pageIndex,
                onSelect: (i) {
                  _select(null);
                  notifier.setPageIndex(i);
                },
              ),

            // ── Hint ───────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                radioSelected
                    ? context.l10n.detectRadioAddChoiceHint
                    : sel != null
                    ? context.l10n.detectSelectedHint
                    : context.l10n.detectPinchHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),

            // ── Add-field toolbar: one tap drops the field on the page ──────
            _AddFieldToolbar(onAdd: (type) => _addField(type, pageIndex)),

            // ── CTA ────────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: widget.onProceed,
                    icon: const Icon(Icons.edit_note),
                    label: Text(
                      state.fields.isEmpty
                          ? context.l10n.detectSkipToFill
                          : context.l10n.detectFillFields(state.fields.length),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addField(FieldType type, int pageIndex) {
    final sel = _selected;
    BoundingBox box;
    String? group;
    if (type == FieldType.radio &&
        sel != null &&
        sel.type == FieldType.radio &&
        sel.pageIndex == pageIndex) {
      // Another choice for the selected question: same group, same size,
      // just below the selected option (or beside it at the page bottom).
      group = sel.radioGroup;
      final b = sel.bbox;
      final below = b.y + b.h * 1.8;
      box = below + b.h <= 1
          ? BoundingBox(x: b.x, y: below, w: b.w, h: b.h)
          : BoundingBox(
              x: (b.x + b.w * 1.8).clamp(0.0, 1 - b.w).toDouble(),
              y: b.y,
              w: b.w,
              h: b.h,
            );
    } else {
      final stagger = (_addCount++ % 6) * 0.04;
      box = defaultFieldBox(
        type,
        Offset(0.5, 0.3 + stagger),
        _pageAspect,
        textSize: state.textSize,
      );
    }
    final added = notifier.addManualField(
      type: type,
      pageIndex: pageIndex,
      bbox: box,
      radioGroup: group,
    );
    HapticFeedback.lightImpact();
    setState(() => _selected = added);
  }

  void _delete(EditableField f) {
    final l10n = context.l10n;
    final removed = notifier.removeField(f);
    setState(() => _selected = null);
    if (removed == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.detectFieldDeleted),
          // Short-lived: it only needs to be there long enough to tap Undo.
          duration: const Duration(seconds: 2),
          // A SnackBar with an action persists until tapped by default;
          // this one should get out of the way.
          persist: false,
          // Floating so it doesn't cover the toolbar and Fill button.
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () {
              final restored = notifier.restoreField(removed);
              if (mounted) setState(() => _selected = restored);
            },
          ),
        ),
      );
  }

  void _showFieldSheet(BuildContext context, EditableField field) {
    int index() => state.fields.indexOf(field);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FieldEditSheet(
        field: field,
        onConfirm: () {
          notifier.confirmField(index());
          Navigator.pop(ctx);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _delete(field);
        },
        onChangeType: (t) {
          notifier.changeType(index(), t);
          Navigator.pop(ctx);
        },
        onUpdateLabel: (l) => notifier.updateLabel(index(), l),
        onToggleRequired: (v) => notifier.setRequired(index(), v),
      ),
    );
  }
}

/// Icon (and the field's name, when it has one and there's room) in the
/// field's top-left corner, sized to the field so small fields stay clean.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.label});
  final FieldType type;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = (c.maxHeight * 0.6).clamp(8.0, 14.0).toDouble();
        final color = colorFor(type);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            children: [
              Icon(iconFor(type), size: size, color: color),
              if (label.isNotEmpty && c.maxWidth > 60) ...[
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: size * 0.85,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Add-field toolbar ─────────────────────────────────────────────────────────

class _AddFieldToolbar extends StatelessWidget {
  const _AddFieldToolbar({required this.onAdd});
  final ValueChanged<FieldType> onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            for (final type in FieldType.values)
              Expanded(
                child: Tooltip(
                  message: fieldTypeName(context, type),
                  child: InkWell(
                    onTap: () => onAdd(type),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconFor(type), size: 24, color: colorFor(type)),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              fieldTypeShortName(context, type),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
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

// ── Bottom sheets ─────────────────────────────────────────────────────────────

class _FieldEditSheet extends StatefulWidget {
  const _FieldEditSheet({
    required this.field,
    required this.onConfirm,
    required this.onDelete,
    required this.onChangeType,
    required this.onUpdateLabel,
    required this.onToggleRequired,
  });

  final EditableField field;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final ValueChanged<FieldType> onChangeType;
  final ValueChanged<String> onUpdateLabel;
  final ValueChanged<bool> onToggleRequired;

  @override
  State<_FieldEditSheet> createState() => _FieldEditSheetState();
}

class _FieldEditSheetState extends State<_FieldEditSheet> {
  late final TextEditingController _labelCtrl;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _required = widget.field.isRequired;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.detectEditField,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Type selector
          Text(
            context.l10n.detectFieldType,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: FieldType.values.map((t) {
              return ChoiceChip(
                label: Text(_typeLabel(context, t)),
                selected: widget.field.type == t,
                onSelected: (_) => widget.onChangeType(t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Label — also becomes the field name in an exported fillable form.
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: context.l10n.detectFieldLabelHint,
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: widget.onUpdateLabel,
          ),

          // Required toggle — used when exporting as a fillable form.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.l10n.detectRequiredField),
            value: _required,
            onChanged: (v) {
              setState(() => _required = v);
              widget.onToggleRequired(v);
            },
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.actionRemove),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onConfirm,
                icon: const Icon(Icons.check),
                label: Text(context.l10n.actionConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(BuildContext context, FieldType t) =>
      fieldTypeName(context, t);
}

// ── Page picker ───────────────────────────────────────────────────────────────

class _PagePicker extends StatelessWidget {
  const _PagePicker({
    required this.pageCount,
    required this.currentIndex,
    required this.onSelect,
  });
  final int pageCount;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: pageCount,
        separatorBuilder: (context, i) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) => ChoiceChip(
          label: Text('${i + 1}'),
          selected: currentIndex == i,
          onSelected: (_) => onSelect(i),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
