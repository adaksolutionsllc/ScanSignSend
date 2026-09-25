import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncpdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';

class FillModeScreen extends ConsumerStatefulWidget {
  const FillModeScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<FillModeScreen> createState() => _FillModeScreenState();
}

class _FillModeScreenState extends ConsumerState<FillModeScreen> {
  int _currentPage = 0;

  // Streams are created ONCE here — not in build(). Rebuilding a StreamBuilder
  // with a freshly-allocated stream on every build re-subscribes each frame and
  // spins an infinite rebuild loop (the "flicker" seen when opening a doc).
  late final Stream<List<db.Page>> _pagesStream =
      ref.read(pageRepositoryProvider).watchPages(widget.docId);
  late final Stream<List<db.Field>> _fieldsStream =
      ref.read(fieldRepositoryProvider).watchFields(widget.docId);
  late final Stream<db.Document?> _docStream =
      ref.read(documentRepositoryProvider).watchAll().map(
            (docs) => docs.fold<db.Document?>(
              null,
              (found, d) => found ?? (d.id == widget.docId ? d : null),
            ),
          );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<db.Document?>(
      stream: _docStream,
      builder: (context, docSnap) {
        final doc = docSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(doc?.title ?? context.l10n.fillFallbackTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: context.l10n.fillEditFields,
                onPressed: () => context.push(
                  AppRoutes.fieldDetection
                      .replaceAll(':docId', '${widget.docId}'),
                ),
              ),
            ],
          ),
          // Primary next-step action: prominent, bottom-centre, always reachable.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.press.replaceAll(':docId', '${widget.docId}'),
                  ),
                  icon: const Icon(Icons.task_alt),
                  label: Text(context.l10n.fillReviewAndFinish),
                ),
              ),
            ),
          ),
          body: StreamBuilder<List<db.Page>>(
            stream: _pagesStream,
            builder: (context, pagesSnap) {
              final pages = pagesSnap.data ?? [];
              if (pages.isEmpty) {
                if (pagesSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Doc has no pages (e.g. all deleted) — don't spin forever.
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(context.l10n.fillNoPages,
                        textAlign: TextAlign.center),
                  ),
                );
              }
              // Keep the active page in range so field/page views never diverge.
              final safePage = _currentPage.clamp(0, pages.length - 1);
              final page = pages[safePage];

              return StreamBuilder<List<db.Field>>(
                stream: _fieldsStream,
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
                          // PdfPageLayoutMode.single lets the user swipe
                          // left/right to a different page *inside* the PDF
                          // viewer itself, bypassing the page-picker chips
                          // below — without this, our own _currentPage state
                          // (and therefore which fields get overlaid) falls
                          // out of sync with whatever page is actually on
                          // screen. Mirror the viewer's own page back into
                          // our state instead of fighting the gesture.
                          onPageChanged: (i) => setState(
                              () => _currentPage = i.clamp(0, pages.length - 1)),
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
        // Capture the pattern + locale before awaiting the picker.
        final datePattern = context.l10n.dateFormatInput;
        final dateLocale = Localizations.localeOf(context).toString();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        final formatted = DateFormat(datePattern, dateLocale).format(picked);
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

  Future<String?> _showTextInput(BuildContext context, db.Field field) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TextInputSheet(field: field),
    );
  }
}

// Owns its TextEditingController via normal State lifecycle so it's disposed
// only once the sheet's exit animation actually finishes removing it from the
// tree — disposing manually right after the pop future resolves races the
// still-animating TextField and corrupts the widget tree.
class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({required this.field});
  final db.Field field;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.field.value);

  @override
  void dispose() {
    _ctrl.dispose();
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
          Text(
            widget.field.label.isNotEmpty
                ? widget.field.label
                : switch (widget.field.type.toFieldType()) {
                    FieldType.date => context.l10n.fieldTypeDate,
                    FieldType.checkbox => context.l10n.fieldTypeCheckbox,
                    FieldType.signature => context.l10n.fieldTypeSignature,
                    FieldType.text => context.l10n.fillTextFieldFallback,
                  },
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: context.l10n.fillEnterValueHint,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.actionCancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _ctrl.text),
                child: Text(context.l10n.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
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

        final today = DateFormat(context.l10n.dateFormatInput,
                Localizations.localeOf(context).toString())
            .format(DateTime.now());
        final chips = <_ChipData>[
          if (profile.fullName.isNotEmpty)
            _ChipData(context.l10n.fillChipName, profile.fullName, FieldType.text),
          if (profile.email.isNotEmpty)
            _ChipData(context.l10n.fillChipEmail, profile.email, FieldType.text),
          if (profile.phone.isNotEmpty)
            _ChipData(context.l10n.fillChipPhone, profile.phone, FieldType.text),
          if (profile.address.isNotEmpty)
            _ChipData(context.l10n.fillChipAddress, profile.address, FieldType.text),
          if (profile.company.isNotEmpty)
            _ChipData(context.l10n.fillChipCompany, profile.company, FieldType.text),
          _ChipData(context.l10n.fillChipToday, today, FieldType.date),
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
    this.onPageChanged,
  });

  final db.Page page;
  final List<db.Field> fields;
  final ValueChanged<db.Field> onFieldTap;
  // Fires when the PDF viewer's own swipe-between-pages gesture moves it off
  // this page (0-indexed) — see the call site in FillModeScreen for why this
  // exists.
  final ValueChanged<int>? onPageChanged;

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

  // ── PDF scroll/zoom tracking ─────────────────────────────────────────────
  // SfPdfViewer manages its own internal scroll+zoom for a PDF-backed page,
  // independently of the Positioned overlay below — without this, panning or
  // pinching the page leaves every field box stuck at its original screen
  // position while the document moves underneath it. Owning the controller
  // here lets the overlay math re-derive each field's on-screen rect from
  // the viewer's live zoomLevel/scrollOffset instead of assuming the page is
  // always static at 1:1 with the viewport (true only for image-backed pages).
  PdfViewerController? _pdfController;
  // Native PDF page size in points — needed because SfPdfViewer fits a
  // page's WIDTH to the viewport at zoomLevel 1.0 but preserves its own
  // aspect ratio for height, which we can't derive from the viewport alone.
  Size? _pdfNativeSize;

  @override
  void initState() {
    super.initState();
    _syncPdfController();
  }

  @override
  void didUpdateWidget(covariant _FillOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.imagePath != widget.page.imagePath) {
      _syncPdfController();
    }
  }

  @override
  void dispose() {
    _pdfController?.removeListener(_onPdfControllerChanged);
    _pdfController?.dispose();
    super.dispose();
  }

  void _syncPdfController() {
    _pdfController?.removeListener(_onPdfControllerChanged);
    _pdfController?.dispose();
    _pdfController = null;
    _pdfNativeSize = null;

    final resolved = PathResolver.resolve(widget.page.imagePath);
    if (!resolved.contains('#page=')) return; // image-backed page — no viewer

    _pdfController = PdfViewerController()
      ..addListener(_onPdfControllerChanged);
    _loadNativePageSize(resolved);
  }

  void _onPdfControllerChanged() {
    // zoomLevel notifies on pinch; scrollOffset does not (see
    // _onPdfPointerActivity) — this catches the zoom half of that gap.
    if (mounted) setState(() {});
  }

  /// Every pointer move/up during an interaction with a PDF-backed page.
  /// PdfViewerController.scrollOffset has no change notification, so a pan
  /// gesture is otherwise invisible to this widget — polling it here, tied
  /// to actual touch events rather than a timer, keeps the overlay honest
  /// while the user is dragging. One known gap: a post-release fling keeps
  /// gliding after the last pointer event, so the overlay freezes at the
  /// release position until the next touch — acceptable for a form-filling
  /// screen where users scroll deliberately rather than flinging.
  void _onPdfPointerActivity(PointerEvent _) {
    if (mounted) setState(() {});
  }

  Future<void> _loadNativePageSize(String resolved) async {
    final parts = resolved.split('#page=');
    final pageIndex = int.tryParse(parts[1]) ?? 0;
    try {
      final bytes = await File(parts[0]).readAsBytes();
      final doc = syncpdf.PdfDocument(inputBytes: bytes);
      if (pageIndex >= 0 && pageIndex < doc.pages.count) {
        final size = doc.pages[pageIndex].size;
        // The page may have changed again while this load was in flight.
        if (mounted && PathResolver.resolve(widget.page.imagePath) == resolved) {
          setState(() => _pdfNativeSize = Size(size.width, size.height));
        }
      }
      doc.dispose();
    } catch (_) {
      // Leave _pdfNativeSize null — build() falls back to the viewport's own
      // aspect ratio, which is usually close enough for the brief gap until
      // this either succeeds on retry or the page is abandoned.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cw = constraints.maxWidth;
      final ch = constraints.maxHeight;

      // Guard: during transient layout passes the box can be unbounded or
      // smaller than a field's minimum — bail rather than feed invalid values
      // to clamp() / Positioned (both throw on inverted or negative ranges).
      if (!cw.isFinite || !ch.isFinite || cw < _minW || ch < _minH) {
        return _PageBackground(
            imagePath: widget.page.imagePath, controller: _pdfController);
      }

      final pdfCtrl = _pdfController;
      // Defaults (zoom 1, no scroll) match a controller that hasn't attached
      // to a live viewer yet, which is exactly the state on the first build.
      final zoom = pdfCtrl?.zoomLevel ?? 1.0;
      final scroll = pdfCtrl?.scrollOffset ?? Offset.zero;
      final pageAspect = (_pdfNativeSize != null && _pdfNativeSize!.height > 0)
          ? _pdfNativeSize!.width / _pdfNativeSize!.height
          : (cw / ch);
      // SfPdfViewer fits a single page's WIDTH to the viewport at zoomLevel
      // 1.0 — so the viewport width doubles as "page width in pixels at
      // zoom 1", and height follows from the page's own aspect ratio.
      final pdfFitW = cw;
      final pdfFitH = cw / pageAspect;

      Widget content = Stack(
        fit: StackFit.expand,
        children: [
          _PageBackground(
            imagePath: widget.page.imagePath,
            controller: pdfCtrl,
            onPageChanged: widget.onPageChanged,
          ),

          ...widget.fields.map((field) {
            final bbox = BoundingBox.fromJsonString(field.boundingBoxJson);
            final type = field.type.toFieldType();
            final color = _typeColors[type] ?? Colors.blue;

            // Compute current position/size — start from bbox (re-derived
            // against the PDF viewer's live zoom/scroll when this is a
            // PDF-backed page), apply any drag delta.
            final double baseLeft, baseTop, baseW, baseH;
            if (pdfCtrl != null) {
              baseLeft = bbox.x * pdfFitW * zoom - scroll.dx;
              baseTop = bbox.y * pdfFitH * zoom - scroll.dy;
              baseW = bbox.w * pdfFitW * zoom;
              baseH = bbox.h * pdfFitH * zoom;
            } else {
              baseLeft = bbox.x * cw;
              baseTop = bbox.y * ch;
              baseW = bbox.w * cw;
              baseH = bbox.h * ch;
            }

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
                // Two-finger pinch resize — works on ANY field (incl. filled /
                // signed / AcroForm), grown symmetrically around its centre.
                onScale: (factor) {
                  setState(() {
                    final prev = _sizes[field.id] ?? Size(baseW, baseH);
                    final newW = (prev.width * factor).clamp(_minW, cw);
                    final newH = (prev.height * factor).clamp(_minH, ch);
                    // Keep the centre fixed while scaling.
                    final prevOff = _offsets[field.id] ?? Offset.zero;
                    _offsets[field.id] = prevOff +
                        Offset((prev.width - newW) / 2,
                            (prev.height - newH) / 2);
                    _sizes[field.id] = Size(newW, newH);
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

      if (pdfCtrl != null) {
        // Not a gesture arena participant — just observes pointer activity so
        // the overlay can re-poll scrollOffset (see _onPdfPointerActivity)
        // without stealing the pan/pinch gesture SfPdfViewer needs to see.
        content = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: _onPdfPointerActivity,
          onPointerUp: _onPdfPointerActivity,
          onPointerCancel: _onPdfPointerActivity,
          child: content,
        );
      }
      return content;
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
    final pdfCtrl = _pdfController;
    final BoundingBox newBbox;
    if (pdfCtrl != null) {
      // Invert the same transform used to render the field, so a drag/resize
      // made while scrolled/zoomed persists the correct page-relative bbox
      // rather than baking in whatever scroll/zoom happened to be active.
      final zoom = pdfCtrl.zoomLevel;
      final scroll = pdfCtrl.scrollOffset;
      final pageAspect = (_pdfNativeSize != null && _pdfNativeSize!.height > 0)
          ? _pdfNativeSize!.width / _pdfNativeSize!.height
          : (cw / ch);
      final denomW = cw * zoom;
      final denomH = (cw / pageAspect) * zoom;
      newBbox = BoundingBox(
        x: ((left + scroll.dx) / denomW).clamp(0.0, 1.0),
        y: ((top + scroll.dy) / denomH).clamp(0.0, 1.0),
        w: (w / denomW).clamp(0.001, 1.0),
        h: (h / denomH).clamp(0.001, 1.0),
      );
    } else {
      newBbox = BoundingBox(
        x: (left / cw).clamp(0.0, 1.0),
        y: (top / ch).clamp(0.0, 1.0),
        w: (w / cw).clamp(0.001, 1.0),
        h: (h / ch).clamp(0.001, 1.0),
      );
    }
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

class _DraggableField extends StatefulWidget {
  const _DraggableField({
    required this.field,
    required this.type,
    required this.color,
    required this.handleSize,
    required this.movable,
    required this.onTap,
    required this.onDrag,
    required this.onResize,
    required this.onScale,
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
  final ValueChanged<double> onScale;
  final VoidCallback onDragEnd;
  final VoidCallback onResizeEnd;

  @override
  State<_DraggableField> createState() => _DraggableFieldState();
}

class _DraggableFieldState extends State<_DraggableField> {
  // Baseline scale at the start of a pinch, so each update applies an
  // incremental factor rather than the absolute cumulative one.
  double _lastScale = 1.0;

  db.Field get field => widget.field;
  FieldType get type => widget.type;
  Color get color => widget.color;
  double get handleSize => widget.handleSize;
  bool get movable => widget.movable;

  @override
  Widget build(BuildContext context) {
    final isFilled = field.isFilled;

    return GestureDetector(
      onTap: widget.onTap,
      // Unified drag + pinch. Using scale callbacks (not pan) so 1-finger drag
      // and 2-finger resize coexist without gesture-arena conflicts.
      // 1 pointer → move (app-authored fields only). 2 pointers → resize ANY
      // field (incl. filled / signed / AcroForm) via the pinch scale factor.
      onScaleStart: (_) => _lastScale = 1.0,
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          final incremental = details.scale / _lastScale;
          _lastScale = details.scale;
          widget.onScale(incremental);
        } else if (movable) {
          widget.onDrag(details.focalPointDelta);
        }
      },
      onScaleEnd: (_) {
        _lastScale = 1.0;
        widget.onResizeEnd();
      },
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

          // Resize handle — bottom-right corner. Shown on every field so users
          // can resize signatures / filled fields (pinch works too).
          Positioned(
              right: -handleSize / 2,
              bottom: -handleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => widget.onResize(d.delta),
                onPanEnd: (_) => widget.onResizeEnd(),
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
      final sigFile = File(PathResolver.resolve(field.value));
      if (sigFile.existsSync()) {
        // Fill the field box; the PNG is pre-cropped to the ink bounds.
        return SizedBox.expand(
          child: Image.file(sigFile, fit: BoxFit.contain),
        );
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
        FieldType.text => context.l10n.fillTapToFill,
        FieldType.date => context.l10n.fillTapForDate,
        FieldType.checkbox => context.l10n.fillTapToCheck,
        FieldType.signature => context.l10n.fillTapToSign,
      };
}

// ── Page background (image or PDF page) ──────────────────────────────────────

class _PageBackground extends StatelessWidget {
  const _PageBackground(
      {required this.imagePath, this.controller, this.onPageChanged});
  final String imagePath;
  // Shared with _FillOverlayState so the overlay's position math can read the
  // same live zoomLevel/scrollOffset this viewer instance is actually using.
  final PdfViewerController? controller;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    // Rebase onto the current app container (paths in the DB may be stale after
    // a reinstall — see PathResolver).
    final resolved = PathResolver.resolve(imagePath);
    // PDF-backed page: render with SfPdfViewer
    if (resolved.contains('#page=')) {
      final parts = resolved.split('#page=');
      final pdfPath = parts[0];
      // The `#page=N` fragment is 0-indexed; SfPdfViewer.initialPageNumber is
      // 1-indexed (see field_detection_screen.dart's _buildBackground, which
      // does the same +1).
      final pageNum = (int.tryParse(parts[1]) ?? 0) + 1;
      final pdfFile = File(pdfPath);
      if (!pdfFile.existsSync()) {
        return _placeholder(
            context, Icons.picture_as_pdf_outlined, context.l10n.fillPdfNotFound);
      }
      return SfPdfViewer.file(
        pdfFile,
        // `initialPageNumber` is only honoured when the widget is first
        // created — SfPdfViewer's State otherwise survives a rebuild that
        // just changes this prop (same file, same tree slot), so tapping a
        // different page chip did nothing. Keying on the resolved path
        // (which embeds `#page=N`) forces a fresh element per page.
        key: ValueKey(resolved),
        controller: controller,
        initialPageNumber: pageNum,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        enableDoubleTapZooming: false,
        pageLayoutMode: PdfPageLayoutMode.single,
        // PdfPageLayoutMode.single lets the user swipe to the next/previous
        // page of the underlying PDF without going through our page-picker
        // chips — mirror that back into app state (see FillModeScreen).
        onPageChanged: onPageChanged == null
            ? null
            : (details) => onPageChanged!(details.newPageNumber - 1),
      );
    }

    // Regular image
    final file = File(resolved);
    if (!file.existsSync()) {
      return _placeholder(
          context, Icons.broken_image_outlined, context.l10n.fillImageNotFound);
    }
    return Image.file(file, fit: BoxFit.contain);
  }

  Widget _placeholder(BuildContext context, IconData icon, String label) {
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
            Text(
              context.l10n.fillScanOrImport,
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
