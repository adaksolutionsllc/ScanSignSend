import 'package:flutter/material.dart';

import '../../core/utils/l10n_ext.dart';

/// A single-field text-edit dialog. Returns the trimmed input via
/// `Navigator.pop`, or null if cancelled.
///
/// Owns its [TextEditingController] through normal [State] lifecycle —
/// disposing it manually right after `showDialog` resolves races the
/// dialog's still-running exit animation (the [TextField] is disposed of
/// while it's still mounted and painting), corrupting the widget tree.
class TextEditDialog extends StatefulWidget {
  const TextEditDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.hint,
  });

  final String title;
  final String initialValue;
  final String? hint;

  @override
  State<TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<TextEditDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(context.l10n.actionSave),
        ),
      ],
    );
  }
}
