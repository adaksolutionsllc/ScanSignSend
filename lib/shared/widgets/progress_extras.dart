import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/l10n_ext.dart';

/// Whole minutes for a rough time shown to the user, or null when it is
/// under a minute.
int? roughMinutes(Duration d) =>
    d.inSeconds < 50 ? null : (d.inSeconds / 60).round().clamp(1, 999);

/// Under a long job's "page N of M" line: the time left, from the speed so
/// far, and a light line that changes every few seconds so the wait feels
/// shorter.
class ProgressExtras extends StatefulWidget {
  const ProgressExtras({
    super.key,
    required this.done,
    required this.total,
    required this.elapsed,
    this.color,
  });

  /// Pages finished, of [total], in [elapsed].
  final int done, total;
  final Duration elapsed;
  final Color? color;

  @override
  State<ProgressExtras> createState() => _ProgressExtrasState();
}

class _ProgressExtrasState extends State<ProgressExtras> {
  var _line = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => setState(() => _line++),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = [
      l10n.progressQuip1,
      l10n.progressQuip2,
      l10n.progressQuip3,
      l10n.progressQuip4,
      l10n.progressQuip5,
      l10n.progressQuip6,
    ];
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    // Known once one page is done: the time per page so far, times the rest.
    String? left;
    if (widget.done >= 1 && widget.done < widget.total) {
      final rest =
          widget.elapsed * ((widget.total - widget.done) / widget.done);
      left = switch (roughMinutes(rest)) {
        final m? => l10n.progressMinutesLeft(m),
        null => l10n.progressUnderMinuteLeft,
      };
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (left != null) ...[
          const SizedBox(height: 6),
          Text(left, style: TextStyle(color: color)),
        ],
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            lines[_line % lines.length],
            key: ValueKey(_line),
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
