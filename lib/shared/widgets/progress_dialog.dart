import 'dart:async';

import 'package:flutter/material.dart';

/// Runs [work] behind a modal "[message]" dialog that can't be dismissed:
/// for steps that take a few seconds (copying pages, rendering a PDF).
Future<T> withProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() work,
) async {
  if (!context.mounted) return work();
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    nav.pop();
  }
}
