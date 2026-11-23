import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/document_edges.dart';
import '../../../core/services/edge_check_service.dart';
import '../../../core/services/import_job_runner.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';

/// "Check the edges": one page at a time, the corners found in a picked or
/// opened photo (or a photo-only PDF) are shown for the user to confirm or
/// drag. Only pages the check thought worth fixing come here; the rest go
/// straight to Review.
///
/// The pages and each choice live in the document's import job
/// ([ImportJobRunner]), so leaving and coming back (even after the app
/// stopped) starts at the first page not decided yet. When done, the job
/// straightens the pages and [JobScreen] shows it.
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key, required this.docId, this.popWhenDone = false});

  final int docId;

  /// Opened from Review (Straighten pages): return to it, rather than open
  /// Review again on top.
  final bool popWhenDone;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  List<EdgeCandidate> _candidates = const [];
  bool _loaded = false;
  int _index = 0;
  EdgeQuad? _quad;
  bool _finishing = false;

  EdgeCandidate get _current => _candidates[_index];

  // Read up front: ref can't be used after an await once the screen is gone.
  late final ImportJobRunner _runner;

  @override
  void initState() {
    super.initState();
    _runner = ref.read(importJobRunnerProvider);
    _load();
  }

  Future<void> _load() async {
    final router = GoRouter.of(context);
    final (candidates, chosen) = await _runner.toChoose(widget.docId);
    if (!mounted) return;
    if (candidates.isEmpty) {
      // No job waiting for the user (a restored route): show Review.
      router.pushReplacement(
        AppRoutes.review.replaceAll(':docId', '${widget.docId}'),
      );
      return;
    }
    final first = candidates.indexWhere((c) => !chosen.containsKey(c.pageId));
    setState(() {
      _candidates = candidates;
      _loaded = true;
      _index = first < 0 ? candidates.length - 1 : first;
      _quad = _current.quad;
    });
    if (first < 0) _finish();
  }

  Future<void> _decide({required bool crop}) async {
    await _runner.choose(widget.docId, _current.pageId, crop ? _quad : null);
    if (!mounted) return;
    if (_index + 1 < _candidates.length) {
      setState(() {
        _index++;
        _quad = _current.quad;
      });
    } else {
      await _finish();
    }
  }

  /// The pages not decided keep their whole image; the job straightens the
  /// rest.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final router = GoRouter.of(context);
    await _runner.startStraighten(widget.docId);
    router.pushReplacement(
      '${AppRoutes.job.replaceAll(':docId', '${widget.docId}')}'
      '${widget.popWhenDone ? '?back=1' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = _candidates.length;
    final quad = _quad;
    if (!_loaded || quad == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.cropTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cropTitle),
        bottom: total > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l10n.reviewPageOf(_index + 1, total)),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              l10n.cropHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _QuadEditor(
                key: ValueKey(_current.pageId),
                imagePath: _current.imagePath,
                quad: quad,
                onChanged: (q) => setState(() => _quad = q),
              ),
            ),
          ),
          // Many pages: the rest can be kept as they are at once.
          if (_index + 1 < total)
            TextButton(
              key: const ValueKey('crop-use-whole-rest'),
              onPressed: _finishing ? null : _finish,
              child: Text(l10n.cropUseWholeRest),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: _finishing ? null : () => _decide(crop: false),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l10n.cropUseWhole),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: quad.isConvex && !_finishing
                      ? () => _decide(crop: true)
                      : null,
                  icon: const Icon(Icons.crop),
                  label: Text(l10n.cropApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page image with the crop outline and four draggable corners.
class _QuadEditor extends StatefulWidget {
  const _QuadEditor({
    super.key,
    required this.imagePath,
    required this.quad,
    required this.onChanged,
  });

  final String imagePath;
  final EdgeQuad quad;
  final ValueChanged<EdgeQuad> onChanged;

  @override
  State<_QuadEditor> createState() => _QuadEditorState();
}

class _QuadEditorState extends State<_QuadEditor> {
  // The image's pixel size, read from its header without decoding it.
  late final Future<Size> _size = () async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(widget.imagePath);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(desc.width.toDouble(), desc.height.toDouble());
    desc.dispose();
    buffer.dispose();
    return size;
  }();

  static const _handle = 44.0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return FutureBuilder<Size>(
      future: _size,
      builder: (context, snap) {
        final size = snap.data;
        if (size == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, box) {
            final scale = math.min(
              box.maxWidth / size.width,
              box.maxHeight / size.height,
            );
            final w = size.width * scale, h = size.height * scale;
            final points = widget.quad.points;
            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.fill,
                        semanticLabel: context.l10n.cropTitle,
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _QuadPainter(widget.quad, color),
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      Positioned(
                        left: points[i].x * w - _handle / 2,
                        top: points[i].y * h - _handle / 2,
                        width: _handle,
                        height: _handle,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) {
                            final p = widget.quad.points[i];
                            widget.onChanged(
                              widget.quad.withCorner(
                                i,
                                math.Point(
                                  (p.x + d.delta.dx / w).clamp(0.0, 1.0),
                                  (p.y + d.delta.dy / h).clamp(0.0, 1.0),
                                ),
                              ),
                            );
                          },
                          child: Center(
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.quad, this.color);
  final EdgeQuad quad;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final pts = [
      for (final p in quad.points) Offset(p.x * size.width, p.y * size.height),
    ];
    path.addPolygon(pts, true);
    // Dim what will be cut away.
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      path,
    );
    canvas.drawPath(outside, Paint()..color = Colors.black45);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.quad != quad || old.color != color;
}
