import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/utils/router.dart';
import 'field_detection_notifier.dart';

// Sentinel written by ImportService when a PDF already has AcroForm fields
const _kHasFormFields = '__has_form_fields__';

class FieldDetectionScreen extends ConsumerStatefulWidget {
  const FieldDetectionScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<FieldDetectionScreen> createState() =>
      _FieldDetectionScreenState();
}

class _FieldDetectionScreenState
    extends ConsumerState<FieldDetectionScreen> {
  bool _hasFormFields = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check sentinel before running OCR
      final doc = await ref.read(documentRepositoryProvider).getById(widget.docId);
      if (doc != null && doc.ocrText == _kHasFormFields) {
        if (mounted) setState(() => _hasFormFields = true);
        return;
      }
      ref
          .read(fieldDetectionNotifierProvider(widget.docId).notifier)
          .run();
    });
  }

  @override
  Widget build(BuildContext context) {
    // PDF already has form fields — skip detection entirely
    if (_hasFormFields) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detect Fields')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text('Fillable PDF detected',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  'This PDF already contains form fields.\nYou can add your own fields manually or continue directly to fill.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _proceed(context),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue to Fill'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(fieldDetectionNotifierProvider(widget.docId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detect Fields'),
        actions: state.phase == DetectionPhase.done
            ? [
                TextButton(
                  onPressed: () => _confirmAll(context),
                  child: const Text('Confirm All'),
                ),
              ]
            : null,
      ),
      body: switch (state.phase) {
        DetectionPhase.idle || DetectionPhase.running => _RunningView(
            message: state.statusMessage.isEmpty
                ? 'Starting…'
                : state.statusMessage,
          ),
        DetectionPhase.error => _ErrorView(
            message: state.errorMessage ?? 'Unknown error',
            onRetry: () => ref
                .read(fieldDetectionNotifierProvider(widget.docId).notifier)
                .run(),
          ),
        DetectionPhase.done => _EditorView(
            docId: widget.docId,
            state: state,
            notifier: ref.read(
                fieldDetectionNotifierProvider(widget.docId).notifier),
            onProceed: () => _proceed(context),
          ),
      },
    );
  }

  Future<void> _confirmAll(BuildContext context) async {
    final notifier =
        ref.read(fieldDetectionNotifierProvider(widget.docId).notifier);
    final state = ref.read(fieldDetectionNotifierProvider(widget.docId));
    for (var i = 0; i < state.fields.length; i++) {
      notifier.confirmField(i);
    }
    await _proceed(context);
  }

  Future<void> _proceed(BuildContext context) async {
    final notifier =
        ref.read(fieldDetectionNotifierProvider(widget.docId).notifier);
    await notifier.saveAll();
    if (context.mounted) {
      context.pushReplacement(
        AppRoutes.fillMode.replaceAll(':docId', '${widget.docId}'),
      );
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
          Text(message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'All processing happens on-device.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
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
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Detection failed',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor ────────────────────────────────────────────────────────────────────

class _EditorView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(pageRepositoryProvider).watchPages(docId);

    return StreamBuilder(
      stream: pages,
      builder: (context, snapshot) {
        final pageList = snapshot.data ?? [];
        if (pageList.isEmpty) {
          return const Center(child: Text('No pages.'));
        }

        final pageIndex = state.currentPageIndex
            .clamp(0, pageList.length - 1);
        final currentPage = pageList[pageIndex];
        final pageFields = state.fields
            .asMap()
            .entries
            .where((e) => e.value.pageIndex == pageIndex)
            .toList();

        return Column(
          children: [
            // ── Status bar ─────────────────────────────────────────────────
            Container(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    state.statusMessage,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${state.fields.length} field${state.fields.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),

            // ── Page image + overlays ───────────────────────────────────────
            Expanded(
              child: _PageOverlayEditor(
                imagePath: currentPage.imagePath,
                fields: pageFields,
                onFieldTap: (globalIndex) =>
                    _showFieldSheet(context, globalIndex),
                onAddField: (bbox) => _showAddFieldSheet(
                    context, pageIndex, bbox),
                onFieldMoved: notifier.updateBbox,
              ),
            ),

            // ── Manual add toolbar ─────────────────────────────────────────
            _ManualAddToolbar(
              onAdd: (type) => _showAddFieldSheet(
                context,
                pageIndex,
                // Default placement at centre of current page
                BoundingBox(
                    x: 0.1, y: 0.45, w: 0.5, h: 0.05),
                preselectedType: type,
              ),
            ),

            // ── Page picker ────────────────────────────────────────────────
            if (pageList.length > 1)
              _PagePicker(
                pageCount: pageList.length,
                currentIndex: pageIndex,
                onSelect: notifier.setPageIndex,
              ),

            // ── CTA ────────────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onProceed,
                    icon: const Icon(Icons.edit_note),
                    label: Text(
                      state.fields.isEmpty
                          ? 'Skip to Fill →'
                          : 'Fill Fields (${state.fields.length}) →',
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

  void _showFieldSheet(BuildContext context, int fieldIndex) {
    final field = state.fields[fieldIndex];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _FieldEditSheet(
        field: field,
        onConfirm: () {
          notifier.confirmField(fieldIndex);
          Navigator.pop(ctx);
        },
        onDelete: () {
          notifier.deleteField(fieldIndex);
          Navigator.pop(ctx);
        },
        onChangeType: (t) {
          notifier.changeType(fieldIndex, t);
          Navigator.pop(ctx);
        },
        onUpdateLabel: (l) => notifier.updateLabel(fieldIndex, l),
      ),
    );
  }

  void _showAddFieldSheet(
    BuildContext context,
    int pageIndex,
    BoundingBox defaultBbox, {
    FieldType? preselectedType,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _AddFieldSheet(
        preselectedType: preselectedType,
        onAdd: (type) {
          notifier.addManualField(
            type: type,
            pageIndex: pageIndex,
            bbox: defaultBbox,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ── Page overlay editor ───────────────────────────────────────────────────────

class _PageOverlayEditor extends StatefulWidget {
  const _PageOverlayEditor({
    required this.imagePath,
    required this.fields,
    required this.onFieldTap,
    required this.onAddField,
    required this.onFieldMoved,
  });

  final String imagePath;
  final List<MapEntry<int, EditableField>> fields;
  final ValueChanged<int> onFieldTap;
  final ValueChanged<BoundingBox> onAddField;
  final void Function(int index, BoundingBox bbox) onFieldMoved;

  @override
  State<_PageOverlayEditor> createState() => _PageOverlayEditorState();
}

class _PageOverlayEditorState extends State<_PageOverlayEditor> {
  static const _fieldColors = {
    FieldType.text: Color(0xFF1565C0),
    FieldType.date: Color(0xFF6A1B9A),
    FieldType.checkbox: Color(0xFF2E7D32),
    FieldType.signature: Color(0xFFBF360C),
  };

  static const double _minW = 40;
  static const double _minH = 24;
  static const double _handleSize = 18;

  // Live drag/resize deltas keyed by field index (pixels), cleared on end.
  final Map<int, Offset> _dragPx = {};
  final Map<int, Offset> _resizePx = {};

  @override
  Widget build(BuildContext context) {
    final isPdf = widget.imagePath.contains('#page=');

    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        final valid = cw.isFinite && ch.isFinite && cw >= _minW && ch >= _minH;

        return GestureDetector(
          onTapUp: (details) {
            if (!valid) return;
            // Tap on blank area → add field
            final rel = details.localPosition;
            final bbox = BoundingBox(
              x: (rel.dx / cw).clamp(0.0, 0.9),
              y: (rel.dy / ch).clamp(0.0, 0.9),
              w: 0.3,
              h: 0.05,
            );
            widget.onAddField(bbox);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(isPdf),

              // Field overlays
              if (valid)
                ...widget.fields.map((entry) {
                  final idx = entry.key;
                  final field = entry.value;
                  final color = _fieldColors[field.type] ?? Colors.blue;

                  final drag = _dragPx[idx] ?? Offset.zero;
                  final resize = _resizePx[idx] ?? Offset.zero;

                  final left = (field.bbox.x * cw + drag.dx).clamp(0.0, cw - _minW);
                  final top = (field.bbox.y * ch + drag.dy).clamp(0.0, ch - _minH);
                  final w =
                      (field.bbox.w * cw + resize.dx).clamp(_minW, cw - left);
                  final h =
                      (field.bbox.h * ch + resize.dy).clamp(_minH, ch - top);

                  return Positioned(
                    left: left,
                    top: top,
                    width: w,
                    height: h,
                    child: _buildField(
                      idx: idx,
                      field: field,
                      color: color,
                      left: left,
                      top: top,
                      w: w,
                      h: h,
                      cw: cw,
                      ch: ch,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({
    required int idx,
    required EditableField field,
    required Color color,
    required double left,
    required double top,
    required double w,
    required double h,
    required double cw,
    required double ch,
  }) {
    void persist() {
      widget.onFieldMoved(
        idx,
        BoundingBox(
          x: (left / cw).clamp(0.0, 1.0),
          y: (top / ch).clamp(0.0, 1.0),
          w: (w / cw).clamp(0.001, 1.0),
          h: (h / ch).clamp(0.001, 1.0),
        ),
      );
      setState(() {
        _dragPx.remove(idx);
        _resizePx.remove(idx);
      });
    }

    return GestureDetector(
      onTap: () => widget.onFieldTap(idx),
      onPanUpdate: (d) => setState(() {
        _dragPx[idx] = (_dragPx[idx] ?? Offset.zero) + d.delta;
      }),
      onPanEnd: (_) => persist(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                border: Border.all(
                  color: color,
                  width: field.confirmed ? 2 : 1.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  color: color,
                  child: Text(
                    _typeLabel(field.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Resize handle — bottom-right corner
          Positioned(
            right: -_handleSize / 2,
            bottom: -_handleSize / 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorb so it doesn't trigger field tap
              onPanUpdate: (d) => setState(() {
                _resizePx[idx] = (_resizePx[idx] ?? Offset.zero) + d.delta;
              }),
              onPanEnd: (_) => persist(),
              child: Container(
                width: _handleSize,
                height: _handleSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.open_in_full,
                    color: Colors.white, size: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isPdf) {
    if (isPdf) {
      final parts = widget.imagePath.split('#page=');
      final pdfFile = File(parts[0]);
      final pageNum = (int.tryParse(parts[1]) ?? 0) + 1;
      if (!pdfFile.existsSync()) {
        return Container(
          color: Colors.grey.shade100,
          child: const Center(
              child: Icon(Icons.picture_as_pdf_outlined,
                  size: 64, color: Colors.grey)),
        );
      }
      return IgnorePointer(
        child: SfPdfViewer.file(
          pdfFile,
          initialPageNumber: pageNum,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          enableDoubleTapZooming: false,
          pageLayoutMode: PdfPageLayoutMode.single,
        ),
      );
    }
    final file = File(widget.imagePath);
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 64, color: Colors.grey)),
      );
    }
    return Image.file(file, fit: BoxFit.contain);
  }

  String _typeLabel(FieldType t) => switch (t) {
        FieldType.text => 'TEXT',
        FieldType.date => 'DATE',
        FieldType.checkbox => 'CHECK',
        FieldType.signature => 'SIGN',
      };
}

// ── Bottom sheets ─────────────────────────────────────────────────────────────

class _FieldEditSheet extends StatefulWidget {
  const _FieldEditSheet({
    required this.field,
    required this.onConfirm,
    required this.onDelete,
    required this.onChangeType,
    required this.onUpdateLabel,
  });

  final EditableField field;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;
  final ValueChanged<FieldType> onChangeType;
  final ValueChanged<String> onUpdateLabel;

  @override
  State<_FieldEditSheet> createState() => _FieldEditSheetState();
}

class _FieldEditSheetState extends State<_FieldEditSheet> {
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
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
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Field',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          // Type selector
          Text('Type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: FieldType.values.map((t) {
              return ChoiceChip(
                label: Text(_typeLabel(t)),
                selected: widget.field.type == t,
                onSelected: (_) => widget.onChangeType(t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Label
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: widget.onUpdateLabel,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.error),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onConfirm,
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(FieldType t) => switch (t) {
        FieldType.text => 'Text',
        FieldType.date => 'Date',
        FieldType.checkbox => 'Checkbox',
        FieldType.signature => 'Signature',
      };
}

class _AddFieldSheet extends StatefulWidget {
  const _AddFieldSheet({
    required this.onAdd,
    this.preselectedType,
  });
  final ValueChanged<FieldType> onAdd;
  final FieldType? preselectedType;

  @override
  State<_AddFieldSheet> createState() => _AddFieldSheetState();
}

class _AddFieldSheetState extends State<_AddFieldSheet> {
  late FieldType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselectedType ?? FieldType.text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Field',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: FieldType.values.map((t) {
              return ChoiceChip(
                label: Text(_typeLabel(t)),
                selected: _selected == t,
                onSelected: (_) => setState(() => _selected = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onAdd(_selected),
              icon: const Icon(Icons.add),
              label: Text('Add ${_typeLabel(_selected)} Field'),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(FieldType t) => switch (t) {
        FieldType.text => 'Text',
        FieldType.date => 'Date',
        FieldType.checkbox => 'Checkbox',
        FieldType.signature => 'Signature',
      };
}

// ── Manual add toolbar ────────────────────────────────────────────────────────

class _ManualAddToolbar extends StatelessWidget {
  const _ManualAddToolbar({required this.onAdd});
  final ValueChanged<FieldType> onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarBtn(
              icon: Icons.text_fields,
              label: 'Text',
              onTap: () => onAdd(FieldType.text)),
          _ToolbarBtn(
              icon: Icons.check_box_outline_blank,
              label: 'Check',
              onTap: () => onAdd(FieldType.checkbox)),
          _ToolbarBtn(
              icon: Icons.calendar_today,
              label: 'Date',
              onTap: () => onAdd(FieldType.date)),
          _ToolbarBtn(
              icon: Icons.draw,
              label: 'Sign',
              onTap: () => onAdd(FieldType.signature)),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
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
