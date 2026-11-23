import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/document_edges.dart';
import '../../../core/services/edge_check_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/progress_extras.dart';

/// "Check the edges": one page at a time, the corners found in a picked or
/// opened photo (or a photo-only PDF) are shown for the user to confirm or
/// drag. Only pages EdgeCheckService thought worth fixing come here; the
/// rest go straight to Review. Ends on Review either way.
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({
    super.key,
    required this.docId,
    required this.candidates,
    this.popWhenDone = false,
  });

  final int docId;
  final List<EdgeCandidate> candidates;

  /// Opened from Review (Straighten pages): return to it, rather than open
  /// Review again on top.
  final bool popWhenDone;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  int _index = 0;
  late EdgeQuad _quad = widget.candidates.first.quad;
  final Map<int, EdgeQuad> _crops = {};
  bool _applying = false;
  (int, int)? _progress; // pages straightened, of how many
  bool _skip = false; // Skip tapped while the pages are straightened
  final _clock = Stopwatch();

  EdgeCandidate get _current => widget.candidates[_index];

  // Read up front: ref can't be used in dispose.
  late final EdgeCheckService _edges;

  @override
  void initState() {
    super.initState();
    _edges = ref.read(edgeCheckServiceProvider);
  }

  @override
  void dispose() {
    // Left with Back: nothing more will change these pages.
    _edges.end(widget.docId);
    super.dispose();
  }

  void _decide({required bool crop}) {
    if (crop) _crops[_current.pageId] = _quad;
    if (_index + 1 < widget.candidates.length) {
      setState(() {
        _index++;
        _quad = _current.quad;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Resolve before the await.
    final failedText = context.l10n.cropFailed;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _applying = true);
    var failed = const <int>[];
    try {
      failed = await _edges.apply(
        widget.docId,
        _crops,
        onProgress: (done, total) {
          if (done == 0) {
            _clock
              ..reset()
              ..start();
          }
          if (mounted) setState(() => _progress = (done, total));
        },
        stop: () => _skip,
      );
    } catch (_) {
      failed = _crops.keys.toList();
    }
    _edges.end(widget.docId);
    if (failed.isNotEmpty && !_skip) {
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
    if (widget.popWhenDone) {
      router.pop();
    } else {
      router.pushReplacement(
        AppRoutes.review.replaceAll(':docId', '${widget.docId}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = widget.candidates.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cropTitle),
        bottom: total > 1 && !_applying
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l10n.reviewPageOf(_index + 1, total)),
                ),
              )
            : null,
      ),
      body: _applying
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_progress case (
                    final done,
                    final total,
                  ) when total > 1) ...[
                    const SizedBox(height: 20),
                    Text(
                      l10n.cropStraighteningPage(
                        (done + 1).clamp(1, total),
                        total,
                      ),
                    ),
                    ProgressExtras(
                      done: done,
                      total: total,
                      elapsed: _clock.elapsed,
                    ),
                    // Go on without the rest of the straightening.
                    const SizedBox(height: 12),
                    TextButton(
                      key: const ValueKey('straighten-progress-skip'),
                      onPressed: _skip
                          ? null
                          : () => setState(() => _skip = true),
                      child: Text(l10n.actionSkip),
                    ),
                  ],
                ],
              ),
            )
          : Column(
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
                      quad: _quad,
                      onChanged: (q) => setState(() => _quad = q),
                    ),
                  ),
                ),
                // Many pages: the rest can be kept as they are at once.
                if (_index + 1 < total)
                  TextButton(
                    key: const ValueKey('crop-use-whole-rest'),
                    onPressed: _finish,
                    child: Text(l10n.cropUseWholeRest),
                  ),
              ],
            ),
      bottomNavigationBar: _applying
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () => _decide(crop: false),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.cropUseWhole),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: _quad.isConvex
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
