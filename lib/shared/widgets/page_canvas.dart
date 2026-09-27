import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/page_raster_service.dart';
import '../../core/utils/l10n_ext.dart';

/// Draws one document page and lays field overlays out on top of it.
///
/// This is the single source of truth for "where is the page on screen".
/// Fields are stored normalised to the **page content** (0..1 of the scanned
/// image or of the PDF page), so every overlay must be positioned relative to
/// [pageRect] — the letterboxed rect the page actually occupies — and never
/// relative to the surrounding container. Measuring against the container is
/// what used to make fields drift between the editor, fill mode and the
/// pressed PDF, because each screen's container has a different shape.
class PageCanvas extends ConsumerStatefulWidget {
  const PageCanvas({
    super.key,
    required this.storedPath,
    required this.overlayBuilder,
    this.onTapPage,
  });

  /// The page's `imagePath` as stored in the DB (may carry `#page=N`).
  final String storedPath;

  /// Builds the overlay children (typically [Positioned]s) for [pageRect],
  /// which is in this widget's local coordinates.
  final List<Widget> Function(BuildContext context, Rect pageRect)
  overlayBuilder;

  /// A tap on the page outside any overlay, with the position normalised to
  /// the page (0..1 on each axis).
  final void Function(Offset normalised)? onTapPage;

  @override
  ConsumerState<PageCanvas> createState() => _PageCanvasState();
}

class _PageCanvasState extends ConsumerState<PageCanvas> {
  /// Decoded at a bounded width: plenty for a phone screen and it keeps a
  /// 12 MP scan from holding ~48 MB of bitmap per page.
  static const _decodeWidth = 1600;

  ImageProvider? _provider;
  Size? _imageSize;
  Object? _error;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PageCanvas old) {
    super.didUpdateWidget(old);
    if (old.storedPath != widget.storedPath) _load();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  Future<void> _load() async {
    _detach();
    setState(() {
      _provider = null;
      _imageSize = null;
      _error = null;
    });
    final requested = widget.storedPath;
    try {
      final path = await ref
          .read(pageRasterServiceProvider)
          .imageFor(requested);
      if (!mounted || widget.storedPath != requested) return;
      if (!File(path).existsSync()) {
        throw FileSystemException('Page image missing', path);
      }
      // The same provider both measures and paints, so the size used for
      // layout is exactly the decoded (EXIF-oriented) image that is drawn.
      final provider = ResizeImage(
        FileImage(File(path)),
        width: _decodeWidth,
        policy: ResizeImagePolicy.fit,
      );
      final stream = provider.resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener(
        (info, _) {
          if (!mounted || widget.storedPath != requested) return;
          setState(() {
            _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
          });
        },
        onError: (e, _) {
          if (mounted) setState(() => _error = e);
        },
      );
      stream.addListener(listener);
      _stream = stream;
      _listener = listener;
      setState(() => _provider = provider);
    } catch (e) {
      if (mounted && widget.storedPath == requested) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.fillImageNotFound,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    final provider = _provider;
    final imageSize = _imageSize;
    if (provider == null || imageSize == null || imageSize.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        if (!box.isFinite || box.isEmpty) return const SizedBox.shrink();
        final pageRect = pageRectFor(imageSize, box);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.onTapPage == null
              ? null
              : (d) {
                  final local = d.localPosition;
                  if (!pageRect.contains(local)) return;
                  widget.onTapPage!(
                    Offset(
                      (local.dx - pageRect.left) / pageRect.width,
                      (local.dy - pageRect.top) / pageRect.height,
                    ),
                  );
                },
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fromRect(
                rect: pageRect,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Image(image: provider, fit: BoxFit.fill),
                ),
              ),
              ...widget.overlayBuilder(context, pageRect),
            ],
          ),
        );
      },
    );
  }
}

/// The rect a page of [imageSize] occupies when fitted (contain, centred)
/// into [box]. Public so the geometry can be unit-tested.
Rect pageRectFor(Size imageSize, Size box) {
  final fitted = applyBoxFit(BoxFit.contain, imageSize, box);
  return Alignment.center.inscribe(fitted.destination, Offset.zero & box);
}
