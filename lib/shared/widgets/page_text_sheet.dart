import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_lock_provider.dart';
import '../../core/services/document_repository.dart';
import '../../core/services/page_text_service.dart';
import '../../core/utils/l10n_ext.dart';
import '../utils/share_pdf.dart';

/// Review / Viewer → Text: the text of every page of [docId], to select,
/// copy or share as a .txt file named after [title].
Future<void> showPageTextSheet(
  BuildContext context, {
  required int docId,
  required String title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _PageTextSheet(docId: docId, title: title),
);

class _PageTextSheet extends ConsumerStatefulWidget {
  const _PageTextSheet({required this.docId, required this.title});
  final int docId;
  final String title;

  @override
  ConsumerState<_PageTextSheet> createState() => _PageTextSheetState();
}

class _PageTextSheetState extends ConsumerState<_PageTextSheet> {
  late final Future<List<Future<String>>> _texts = () async {
    final pages = await ref.read(pageRepositoryProvider).pagesOf(widget.docId);
    final service = ref.read(pageTextServiceProvider);
    return [for (final pg in pages) service.textOf(pg)];
  }();

  /// Every page's text, once all are read.
  late final Future<String> _all = _texts.then(
    (t) async => PageTextService.joined(await Future.wait(t)),
  );

  bool _copied = false;
  final _shareKey = GlobalKey();

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: await _all));
    if (!mounted) return;
    // iOS shows nothing when text is copied, and a snackbar would sit
    // behind this sheet: the button itself says so.
    setState(() => _copied = true);
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      }),
    );
  }

  Future<void> _share() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final lock = ref.read(appLockProvider.notifier);
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await shareDocumentText(
        lock: lock,
        text: await _all,
        title: widget.title,
        origin: origin,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sendShareFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.textTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FutureBuilder<String>(
              future: _all,
              builder: (context, snap) {
                final ready = snap.hasData && snap.data!.isNotEmpty;
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: ready ? _copyAll : null,
                        icon: Icon(_copied ? Icons.check : Icons.copy),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _copied ? l10n.textCopied : l10n.textCopyAll,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: _shareKey,
                        onPressed: ready ? _share : null,
                        icon: const Icon(Icons.ios_share),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(l10n.textShareTxt),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Future<String>>>(
              future: _texts,
              builder: (context, snap) {
                final texts = snap.data;
                if (texts == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: texts.length,
                  itemBuilder: (context, i) =>
                      _PageText(number: i + 1, text: texts[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageText extends StatelessWidget {
  const _PageText({required this.number, required this.text});
  final int number;
  final Future<String> text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.textPageN(number), style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          FutureBuilder<String>(
            future: text,
            builder: (context, snap) {
              final t = snap.data;
              if (t == null) {
                return Row(
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.textReading),
                  ],
                );
              }
              if (t.isEmpty) {
                return Text(
                  l10n.textNoneOnPage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return SelectableText(t, style: theme.textTheme.bodyLarge);
            },
          ),
        ],
      ),
    );
  }
}
