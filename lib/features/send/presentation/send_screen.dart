import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  bool _sharing = false;
  bool _shared = false;

  // Fetch the doc once. Toggling _sharing/_shared calls setState; a fresh
  // getById() future per build would reload and can flicker.
  late final Future<Document?> _docFuture =
      ref.read(documentRepositoryProvider).getById(widget.docId);

  @override
  Widget build(BuildContext context) {
    // The document is already pressed and saved before we reach this screen,
    // so never trap the user here — back always returns to the Library.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.library);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send Document'),
          leading: IconButton(
            icon: Icon(_shared ? Icons.check : Icons.arrow_back),
            tooltip: 'Back to Library',
            onPressed: () => context.go(AppRoutes.library),
          ),
        ),
        body: FutureBuilder(
          future: _docFuture,
          builder: (context, snapshot) {
            final doc = snapshot.data;
            final storedPdf = doc?.pressedPdfPath;
            final pdfPath =
                storedPdf == null ? null : PathResolver.resolve(storedPdf);

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _shared
                          ? Icons.check_circle_outline
                          : Icons.send_outlined,
                      size: 80,
                      color: _shared ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _shared
                          ? 'Document sent!'
                          : 'Ready to send',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shared
                          ? 'The pressed PDF has been shared.'
                          : 'Share your pressed PDF via Mail, Messages, AirDrop, or any app.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    if (!_shared)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed:
                              (_sharing || pdfPath == null)
                                  ? null
                                  : () => _share(context, pdfPath,
                                      doc?.title ?? 'Document'),
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.share),
                          label: Text(_sharing
                              ? 'Opening share sheet…'
                              : 'Share Pressed Document'),
                        ),
                      ),

                    if (!_shared && pdfPath != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.viewer
                                .replaceAll(':docId', '${widget.docId}'),
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Preview Document'),
                        ),
                      ),
                    ],

                    if (_shared) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.library),
                          icon: const Icon(Icons.home),
                          label: const Text('Back to Library'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: pdfPath != null
                            ? () => _share(context, pdfPath,
                                doc?.title ?? 'Document')
                            : null,
                        icon: const Icon(Icons.share),
                        label: const Text('Share Again'),
                      ),
                    ],

                    if (pdfPath == null && !_sharing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Document not yet pressed.',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _share(
      BuildContext context, String pdfPath, String title) async {
    if (!File(pdfPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pressed PDF file not found.')),
      );
      return;
    }
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    // iPad (and iOS in general) requires a non-zero source rect to anchor the
    // share popover; without it share_plus throws a PlatformException.
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await Share.shareXFiles(
        [XFile(pdfPath, mimeType: 'application/pdf')],
        subject: title,
        text: 'Signed with Scan Sign Send',
        sharePositionOrigin: origin,
      );
      if (mounted) {
        setState(() {
          _sharing = false;
          _shared = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sharing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }
}
