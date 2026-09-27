import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/field_model.dart';

/// How a field's outline is drawn.
enum FieldBoxShape {
  /// Tinted rectangle — text, date, signature, initials.
  box,

  /// Plain square outline, no fill — checkbox.
  square,

  /// Plain circle outline, no fill — radio button.
  circle,
}

/// One field overlay on a [PageCanvas]: tap, one-finger move, two-finger pinch
/// resize, a corner handle for precise resizing and (when selected) a delete
/// button.
///
/// The box works in page-normalised coordinates throughout and converts to
/// pixels only through [pageRect], so a field keeps its place on the page
/// whatever the screen, orientation or surrounding layout. While a gesture is
/// in progress the box is tracked locally; [onChanged] fires once, when the
/// gesture ends, which is when the caller writes it to the database.
class FieldBox extends StatefulWidget {
  const FieldBox({
    super.key,
    required this.bbox,
    required this.pageRect,
    required this.color,
    required this.child,
    required this.onTap,
    required this.onChanged,
    this.shape = FieldBoxShape.box,
    this.movable = true,
    this.resizable = true,
    this.showHandles = true,
    this.selected = false,
    this.highlighted = false,
    this.onDelete,
    this.onGestureStart,
  });

  final BoundingBox bbox;
  final Rect pageRect;
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final ValueChanged<BoundingBox> onChanged;
  final FieldBoxShape shape;
  final bool movable;
  final bool resizable;

  /// Show the resize handle (and the delete button, if [onDelete] is set).
  final bool showHandles;

  /// Drawn with a heavier outline and a soft glow.
  final bool selected;

  /// A lighter emphasis, e.g. the other options of the selected radio group.
  final bool highlighted;

  final VoidCallback? onDelete;

  /// A drag or pinch began on this field — the editor selects it.
  final VoidCallback? onGestureStart;

  /// Invisible margin around every field that still counts as touching it, so
  /// a 16 px checkbox is as easy to grab as a big box. Large enough to contain
  /// the corner buttons, which Flutter can only hit-test inside the bounds.
  static const touchSlop = 18.0;
  static const handleSize = 26.0;

  /// Smallest on-screen size, so a field stays visible and tappable.
  static const minSidePx = 14.0;

  @override
  State<FieldBox> createState() => _FieldBoxState();
}

class _FieldBoxState extends State<FieldBox> {
  BoundingBox? _live;

  // Pinch tracking. Scale values are cumulative from the gesture's baseline,
  // and Flutter re-baselines whenever a finger is added or lifted, so each
  // update applies the ratio to the previous update rather than to the start.
  int _pointers = 0;
  double _lastH = 1, _lastV = 1, _last = 1;

  BoundingBox get _box => _live ?? widget.bbox;
  Rect get _page => widget.pageRect;

  /// Checkboxes and radios stay square on the page (in pixels, not in
  /// normalised units, which differ per axis on a non-square page).
  bool get _square => widget.shape != FieldBoxShape.box;

  /// Keeps the box on the page and no smaller than [FieldBox.minSidePx].
  BoundingBox _clamp(double x, double y, double w, double h) {
    var wPx = math.max(w * _page.width, FieldBox.minSidePx);
    var hPx = math.max(h * _page.height, FieldBox.minSidePx);
    if (_square) wPx = hPx = math.max(wPx, hPx);
    wPx = math.min(wPx, _page.width);
    hPx = math.min(hPx, _page.height);
    if (_square) wPx = hPx = math.min(wPx, hPx);
    final cw = wPx / _page.width, ch = hPx / _page.height;
    return BoundingBox(
      x: x.clamp(0.0, 1.0 - cw).toDouble(),
      y: y.clamp(0.0, 1.0 - ch).toDouble(),
      w: cw,
      h: ch,
    );
  }

  void _moveBy(Offset px) {
    final b = _box;
    setState(
      () => _live = _clamp(
        b.x + px.dx / _page.width,
        b.y + px.dy / _page.height,
        b.w,
        b.h,
      ),
    );
  }

  /// Scales about the box's centre. Rectangles scale independently per axis,
  /// so a pinch can make a field wider without making it taller.
  void _scaleBy(double fx, double fy) {
    final b = _box;
    final cx = b.x + b.w / 2, cy = b.y + b.h / 2;
    final w = b.w * fx, h = b.h * fy;
    setState(() => _live = _clamp(cx - w / 2, cy - h / 2, w, h));
  }

  void _resizeBy(Offset px) {
    final b = _box;
    var d = px;
    if (_square) {
      final m = (px.dx + px.dy) / 2;
      d = Offset(m, m);
    }
    setState(
      () => _live = _clamp(
        b.x,
        b.y,
        b.w + d.dx / _page.width,
        b.h + d.dy / _page.height,
      ),
    );
  }

  void _commit() {
    final live = _live;
    if (live == null) return;
    widget.onChanged(live);
    // Keep showing the committed box until the parent rebuilds with it, so it
    // doesn't flash back to the old position for a frame.
  }

  @override
  void didUpdateWidget(covariant FieldBox old) {
    super.didUpdateWidget(old);
    if (_pointers == 0 &&
        widget.bbox.toJsonString() != old.bbox.toJsonString()) {
      _live = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const slop = FieldBox.touchSlop;
    final visual = _box.inPageRect(_page);
    final canGesture = widget.movable || widget.resizable;
    final active = widget.selected || _pointers > 0;

    return Positioned.fromRect(
      rect: visual.inflate(slop),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // Scale callbacks (not pan) so one-finger move and two-finger pinch
        // share one recogniser instead of fighting in the gesture arena.
        onScaleStart: canGesture
            ? (d) {
                _pointers = d.pointerCount;
                _lastH = _lastV = _last = 1;
                widget.onGestureStart?.call();
              }
            : null,
        onScaleUpdate: canGesture ? _onScaleUpdate : null,
        onScaleEnd: canGesture
            ? (_) {
                setState(() => _pointers = 0);
                _commit();
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: slop,
              top: slop,
              right: slop,
              bottom: slop,
              child: _Outline(
                shape: widget.shape,
                color: widget.color,
                selected: active,
                highlighted: widget.highlighted,
                child: widget.child,
              ),
            ),
            if (widget.showHandles && widget.onDelete != null)
              // Top-left, diagonally opposite the resize handle: on a thin
              // field, top-right and bottom-right sat on top of each other.
              Positioned(
                left: slop - FieldBox.handleSize / 2,
                top: slop - FieldBox.handleSize / 2,
                child: _CornerButton(
                  color: Theme.of(context).colorScheme.error,
                  icon: Icons.close,
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onDelete!();
                  },
                ),
              ),
            if (widget.showHandles && widget.resizable)
              Positioned(
                right: slop - FieldBox.handleSize / 2,
                bottom: slop - FieldBox.handleSize / 2,
                child: _CornerButton(
                  color: widget.color,
                  icon: Icons.open_in_full,
                  onTap: () {}, // absorb, so it doesn't count as a field tap
                  onPanStart: (_) => widget.onGestureStart?.call(),
                  onPanUpdate: (d) => _resizeBy(d.delta),
                  onPanEnd: (_) => _commit(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != _pointers) {
      // Finger added or lifted: re-baseline, apply nothing.
      setState(() => _pointers = d.pointerCount);
      _lastH = d.horizontalScale;
      _lastV = d.verticalScale;
      _last = d.scale;
      return;
    }
    if (d.pointerCount >= 2) {
      if (!widget.resizable) return;
      if (_square) {
        final f = _last == 0 ? 1.0 : d.scale / _last;
        _last = d.scale;
        _scaleBy(f, f);
      } else {
        final fx = _lastH == 0 ? 1.0 : d.horizontalScale / _lastH;
        final fy = _lastV == 0 ? 1.0 : d.verticalScale / _lastV;
        _lastH = d.horizontalScale;
        _lastV = d.verticalScale;
        _scaleBy(fx, fy);
      }
    } else if (widget.movable) {
      _moveBy(d.focalPointDelta);
    }
  }
}

class _Outline extends StatelessWidget {
  const _Outline({
    required this.shape,
    required this.color,
    required this.selected,
    required this.highlighted,
    required this.child,
  });

  final FieldBoxShape shape;
  final Color color;
  final bool selected;
  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = selected ? 2.5 : (highlighted ? 2.0 : 1.5);
    final glow = selected
        ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)]
        : null;
    return switch (shape) {
      FieldBoxShape.box => DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.20 : 0.12),
          border: Border.all(color: color, width: width),
          borderRadius: BorderRadius.circular(3),
          boxShadow: glow,
        ),
        child: child,
      ),
      // Checkbox / radio: a clean outline on white, like the real control.
      FieldBoxShape.square || FieldBoxShape.circle => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape == FieldBoxShape.circle
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: shape == FieldBoxShape.square
              ? BorderRadius.circular(2)
              : null,
          border: Border.all(color: color, width: width),
          boxShadow: glow,
        ),
        child: child,
      ),
    };
  }
}

class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.color,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final Color color;
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Count movement from the touch-down point, so the handle tracks the
      // finger from the start instead of lagging by the drag slop.
      dragStartBehavior: DragStartBehavior.down,
      onTap: onTap,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Container(
        width: FieldBox.handleSize,
        height: FieldBox.handleSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// The shape a field of [type] is drawn with.
FieldBoxShape shapeFor(FieldType type) => switch (type) {
  FieldType.checkbox => FieldBoxShape.square,
  FieldType.radio => FieldBoxShape.circle,
  _ => FieldBoxShape.box,
};

/// One colour per field type, shared by the editor and fill mode.
Color colorFor(FieldType type) => switch (type) {
  FieldType.text => const Color(0xFF1565C0),
  FieldType.date => const Color(0xFF6A1B9A),
  FieldType.checkbox => const Color(0xFF2E7D32),
  FieldType.radio => const Color(0xFF00838F),
  FieldType.initials => const Color(0xFFE65100),
  FieldType.signature => const Color(0xFFBF360C),
};

/// Toolbar / badge icon per field type.
IconData iconFor(FieldType type) => switch (type) {
  FieldType.text => Icons.text_fields,
  FieldType.date => Icons.calendar_today,
  FieldType.checkbox => Icons.check_box_outline_blank,
  FieldType.radio => Icons.radio_button_unchecked,
  FieldType.initials => Icons.gesture,
  FieldType.signature => Icons.draw,
};
