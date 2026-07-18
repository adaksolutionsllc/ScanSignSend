import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../../core/services/document_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final docRepo = ref.watch(documentRepositoryProvider);

    return PopScope(
      canPop: _shared,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Share the document before leaving.')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send Document'),
          leading: _shared
              ? IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => context.go(AppRoutes.library),
                )
              : null,
        ),
        body: FutureBuilder(
          future: docRepo.getById(widget.docId),
          builder: (context, snapshot) {
            final doc = snapshot.data;
            final pdfPath = doc?.pressedPdfPath;

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
                          ? 'The pressed PDF has been shared. Your original is preserved as a template.'
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
    try {
      await Share.shareXFiles(
        [XFile(pdfPath, mimeType: 'application/pdf')],
        subject: title,
        text: 'Signed with Scan Sign Send',
      );
      if (mounted) {
        setState(() {
          _sharing = false;
          _shared = true;
        });
        // ignore: use_build_context_synchronously
        if (mounted) _offerSaveAsTemplate(context);
      }
    } catch (e) {
      if (mounted) setState(() => _sharing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _offerSaveAsTemplate(BuildContext context) async {
    // Template is already auto-created by PressService.
    // Just confirm to the user.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Template Saved'),
        content: const Text(
          'A blank template was saved to your Library so you can re-use this form without re-scanning.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
