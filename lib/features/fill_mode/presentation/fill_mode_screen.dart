import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/router.dart';

class FillModeScreen extends ConsumerStatefulWidget {
  const FillModeScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<FillModeScreen> createState() => _FillModeScreenState();
}

class _FillModeScreenState extends ConsumerState<FillModeScreen> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final pagesStream =
        ref.watch(pageRepositoryProvider).watchPages(widget.docId);
    final fieldsStream =
        ref.watch(fieldRepositoryProvider).watchFields(widget.docId);
    final docStream = ref.watch(documentRepositoryProvider).watchAll().map(
          (docs) => docs.fold<db.Document?>(
            null,
            (found, d) => found ?? (d.id == widget.docId ? d : null),
          ),
        );

    return StreamBuilder<db.Document?>(
      stream: docStream,
      builder: (context, docSnap) {
        final doc = docSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(doc?.title ?? 'Fill Document'),
            actions: [
              TextButton(
                onPressed: () => context.push(
                  AppRoutes.press.replaceAll(':docId', '${widget.docId}'),
                ),
                child: const Text('Review & Press →'),
              ),
            ],
          ),
          body: StreamBuilder<List<db.Page>>(
            stream: pagesStream,
            builder: (context, pagesSnap) {
              final pages = pagesSnap.data ?? [];
              if (pages.isEmpty) {
                if (pagesSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Doc has no pages (e.g. all deleted) — don't spin forever.
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('This document has no pages.',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              // Keep the active page in range so field/page views never diverge.
              final safePage = _currentPage.clamp(0, pages.length - 1);
              final page = pages[safePage];

              return StreamBuilder<List<db.Field>>(
                stream: fieldsStream,
                builder: (context, fieldsSnap) {
                  final allFields = fieldsSnap.data ?? [];
                  final pageFields = allFields
                      .where((f) => f.pageIndex == safePage)
                      .toList();

                  return Column(
                    children: [
                      // ── Smart-fill chip bar ───────────────────────────────
                      _SmartFillBar(
                        docId: widget.docId,
                        fields: pageFields,
                      ),
                      // ── Page image + overlay ──────────────────────────────
                      Expanded(
                        child: _FillOverlay(
                          page: page,
                          fields: pageFields,
                          onFieldTap: (field) =>
                              _openFieldInput(context, field),
                        ),
                      ),
                      // ── Page picker ───────────────────────────────────────
                      if (pages.length > 1)
                        _PagePicker(
                          pageCount: pages.length,
                          currentIndex: safePage,
                          onSelect: (i) => setState(() => _currentPage = i),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openFieldInput(BuildContext context, db.Field field) async {
    final type = field.type.toFieldType();
    switch (type) {
      case FieldType.signature:
        await context.push(
          AppRoutes.signatureCapture
              .replaceAll(':docId', '${widget.docId}')
              .replaceAll(':fieldId', '${field.id}'),
        );
        return;

      case FieldType.checkbox:
        await ref.read(fieldRepositoryProvider).updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                isChecked: Value(!field.isChecked),
                isFilled: const Value(true),
                value: Value(field.isChecked ? '' : '✓'),
              ),
            );
        return;

      case FieldType.date:
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        final formatted = DateFormat('MM/dd/yyyy').format(picked);
        await ref.read(fieldRepositoryProvider).updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                value: Value(formatted),
                isFilled: const Value(true),
              ),
            );
        return;

      case FieldType.text:
        final result = await _showTextInput(context, field);
        if (result == null) return;
        await ref.read(fieldRepositoryProvider).updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                value: Value(result),
                isFilled: Value(result.isNotEmpty),
              ),
            );
    }
  }

  Future<String?> _showTextInput(BuildContext context, db.Field field) async {
    final ctrl = TextEditingController(text: field.value);
    try {
      return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label.isNotEmpty ? field.label : 'Text Field',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter value…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
      );
    } finally {
      ctrl.dispose();
    }
  }
}

// ── Smart-fill chip bar ───────────────────────────────────────────────────────

class _SmartFillBar extends ConsumerWidget {
  const _SmartFillBar({required this.docId, required this.fields});
  final int docId;
  final List<db.Field> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<db.UserProfileData>(
      future: ref.read(profileRepositoryProvider).getOrCreate(),
      builder: (context, snap) {
        final profile = snap.data;
        if (profile == null) return const SizedBox.shrink();

        final today = DateFormat('MM/dd/yyyy').format(DateTime.now());
        final chips = <_ChipData>[
          if (profile.fullName.isNotEmpty)
            _ChipData('Name', profile.fullName, FieldType.text),
          if (profile.email.isNotEmpty)
            _ChipData('Email', profile.email, FieldType.text),
          if (profile.phone.isNotEmpty)
            _ChipData('Phone', profile.phone, FieldType.text),
          if (profile.address.isNotEmpty)
            _ChipData('Address', profile.address, FieldType.text),
          if (profile.company.isNotEmpty)
            _ChipData('Company', profile.company, FieldType.text),
          _ChipData('Today', today, FieldType.date),
        ];

        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: chips.length,
            separatorBuilder: (_, i) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final chip = chips[i];
              return ActionChip(
                label: Text(chip.label,
                    style: const TextStyle(fontSize: 12)),
                onPressed: () =>
                    _fillMatchingFields(ref, chip),
                avatar: const Icon(Icons.auto_awesome, size: 14),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _fillMatchingFields(WidgetRef ref, _ChipData chip) async {
    final repo = ref.read(fieldRepositoryProvider);
    // Fill the first unfilled text/date field on the current page
    final candidates = fields
        .where((f) =>
            f.type.toFieldType() == chip.type && !f.isFilled)
        .toList();
    if (candidates.isEmpty) return;
    final target = candidates.first;
    await repo.updateField(
      db.FieldsCompanion(
        id: Value(target.id),
        value: Value(chip.value),
        isFilled: const Value(true),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String value;
  final FieldType type;
  const _ChipData(this.label, this.value, this.type);
}

// ── Fill overlay ──────────────────────────────────────────────────────────────

class _FillOverlay extends ConsumerStatefulWidget {
  const _FillOverlay({
    required this.page,
    required this.fields,
    required this.onFieldTap,
  });

  final db.Page page;
  final List<db.Field> fields;
  final ValueChanged<db.Field> onFieldTap;

  @override
  ConsumerState<_FillOverlay> createState() => _FillOverlayState();
}

class _FillOverlayState extends ConsumerState<_FillOverlay> {
  static const _typeColors = {
    FieldType.text: Color(0xFF1565C0),
    FieldType.date: Color(0xFF6A1B9A),
    FieldType.checkbox: Color(0xFF2E7D32),
    FieldType.signature: Color(0xFFBF360C),
  };

  // Per-field drag/resize state (keyed by field id)
  final Map<int, Offset> _offsets = {};
  final Map<int, Size> _sizes = {};

  static const double _minW = 40;
  static const double _minH = 24;
  static const double _handleSize = 18;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cw = constraints.maxWidth;
      final ch = constraints.maxHeight;

      // Guard: during transient layout passes the box can be unbounded or
      // smaller than a field's minimum — bail rather than feed invalid values
      // to clamp() / Positioned (both throw on inverted or negative ranges).
      if (!cw.isFinite || !ch.isFinite || cw < _minW || ch < _minH) {
        return _PageBackground(imagePath: widget.page.imagePath);
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          _PageBackground(imagePath: widget.page.imagePath),

          ...widget.fields.map((field) {
            final bbox = BoundingBox.fromJsonString(field.boundingBoxJson);
            final type = field.type.toFieldType();
            final color = _typeColors[type] ?? Colors.blue;

            // Compute current position/size — start from bbox, apply any drag delta
            final baseLeft = bbox.x * cw;
            final baseTop = bbox.y * ch;
            final baseW = bbox.w * cw;
            final baseH = bbox.h * ch;

            final offset = _offsets[field.id] ?? Offset.zero;
            final size = _sizes[field.id] ?? Size(baseW, baseH);

            // left/top are bounded so at least _minW/_minH remains to the edge,
            // guaranteeing the width/height clamp ranges below are non-inverted.
            final left = (baseLeft + offset.dx).clamp(0.0, cw - _minW);
            final top = (baseTop + offset.dy).clamp(0.0, ch - _minH);
            final w = size.width.clamp(_minW, cw - left);
            final h = size.height.clamp(_minH, ch - top);

            // Real AcroForm fields (from an imported PDF) are fill-only — moving
            // a live widget's geometry is an authoring action (Phase C), and we
            // must not shift a field away from where the source form placed it.
            final movable = field.sourceKind == 'app';

            return Positioned(
              left: left,
              top: top,
              width: w,
              height: h,
              child: _DraggableField(
                field: field,
                type: type,
                color: color,
                handleSize: _handleSize,
                movable: movable,
                onTap: () => widget.onFieldTap(field),
                onDrag: (delta) {
                  setState(() {
                    final prev = _offsets[field.id] ?? Offset.zero;
                    _offsets[field.id] = prev + delta;
                  });
                },
                onResize: (delta) {
                  setState(() {
                    final prev = _sizes[field.id] ?? Size(baseW, baseH);
                    _sizes[field.id] = Size(
                      (prev.width + delta.dx).clamp(_minW, cw),
                      (prev.height + delta.dy).clamp(_minH, ch),
                    );
                  });
                },
                onDragEnd: () => _persistPosition(
                    field, left, top, w, h, cw, ch),
                onResizeEnd: () => _persistPosition(
                    field, left, top, w, h, cw, ch),
              ),
            );
          }),
        ],
      );
    });
  }

  Future<void> _persistPosition(
    db.Field field,
    double left,
    double top,
    double w,
    double h,
    double cw,
    double ch,
  ) async {
    final newBbox = BoundingBox(
      x: (left / cw).clamp(0.0, 1.0),
      y: (top / ch).clamp(0.0, 1.0),
      w: (w / cw).clamp(0.001, 1.0),
      h: (h / ch).clamp(0.001, 1.0),
    );
    await ref.read(fieldRepositoryProvider).updateField(
          db.FieldsCompanion(
            id: Value(field.id),
            boundingBoxJson: Value(newBbox.toJsonString()),
          ),
        );
    // Clear local override — DB value now matches
    setState(() {
      _offsets.remove(field.id);
      _sizes.remove(field.id);
    });
  }
}

class _DraggableField extends StatelessWidget {
  const _DraggableField({
    required this.field,
    required this.type,
    required this.color,
    required this.handleSize,
    required this.movable,
    required this.onTap,
    required this.onDrag,
    required this.onResize,
    required this.onDragEnd,
    required this.onResizeEnd,
  });

  final db.Field field;
  final FieldType type;
  final Color color;
  final double handleSize;
  final bool movable;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onResize;
  final VoidCallback onDragEnd;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final isFilled = field.isFilled;

    return GestureDetector(
      onTap: onTap,
      // Drag only when the field is app-authored; real AcroForm fields keep
      // the geometry the source PDF gave them.
      onPanUpdate: movable ? (d) => onDrag(d.delta) : null,
      onPanEnd: movable ? (_) => onDragEnd() : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Field body
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isFilled
                    ? Colors.yellow.withValues(alpha: 0.35)
                    : color.withValues(alpha: 0.12),
                border: Border.all(
                  color: isFilled ? Colors.amber.shade700 : color,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              child: _fieldContent(),
            ),
          ),

          // Resize handle — bottom-right corner (app-authored fields only)
          if (movable)
            Positioned(
              right: -handleSize / 2,
              bottom: -handleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => onResize(d.delta),
                onPanEnd: (_) => onResizeEnd(),
                onTap: () {}, // absorb tap so it doesn't trigger field tap
                child: Container(
                  width: handleSize,
                  height: handleSize,
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

  Widget _fieldContent() {
    if (!field.isFilled) {
      return Text(
        _placeholder(type),
        style: const TextStyle(
            color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
        overflow: TextOverflow.ellipsis,
      );
    }
    if (type == FieldType.signature && field.value.isNotEmpty) {
      final sigFile = File(field.value);
      if (sigFile.existsSync()) {
        return Image.file(sigFile, fit: BoxFit.contain);
      }
    }
    return Text(
      field.value,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _placeholder(FieldType type) => switch (type) {
        FieldType.text => 'Tap to fill…',
        FieldType.date => 'Tap for date…',
        FieldType.checkbox => 'Tap to check',
        FieldType.signature => 'Tap to sign…',
      };
}

// ── Page background (image or PDF page) ──────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    // PDF-backed page: render with SfPdfViewer
    if (imagePath.contains('#page=')) {
      final parts = imagePath.split('#page=');
      final pdfPath = parts[0];
      final pageNum = int.tryParse(parts[1]) ?? 1;
      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) {
        return _placeholder(Icons.picture_as_pdf_outlined, 'PDF not found');
      }
      return SfPdfViewer.file(
        pdfFile,
        initialPageNumber: pageNum,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        enableDoubleTapZooming: false,
        pageLayoutMode: PdfPageLayoutMode.single,
      );
    }

    // Regular image
    final file = File(imagePath);
    if (!file.existsSync()) {
      return _placeholder(Icons.broken_image_outlined, 'Image not found');
    }
    return Image.file(file, fit: BoxFit.contain);
  }

  Widget _placeholder(IconData icon, String label) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            const Text(
              'Scan or import a new document',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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
