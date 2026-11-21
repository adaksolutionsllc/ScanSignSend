import 'package:flutter/material.dart';

import '../../../core/utils/l10n_ext.dart';

/// Opening a password-protected PDF: asks for its password. Pops with what
/// was typed, or null on Cancel. [retry]: the last one didn't work.
class PdfPasswordPrompt extends StatefulWidget {
  const PdfPasswordPrompt({super.key, this.retry = false});
  final bool retry;

  @override
  State<PdfPasswordPrompt> createState() => _PdfPasswordPromptState();
}

class _PdfPasswordPromptState extends State<PdfPasswordPrompt> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    if (_ctrl.text.isNotEmpty) Navigator.pop(context, _ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.importPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.importPasswordBody),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('import-password'),
            controller: _ctrl,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _open(),
            decoration: InputDecoration(
              labelText: l10n.passwordField,
              errorText: widget.retry ? l10n.importPasswordWrong : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('import-password-open'),
          onPressed: _open,
          child: Text(l10n.actionOpen),
        ),
      ],
    );
  }
}
