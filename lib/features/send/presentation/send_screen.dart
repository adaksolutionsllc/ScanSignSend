import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/services/app_lock_provider.dart';
import '../../../shared/utils/share_pdf.dart';
import '../../../core/services/template_service.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  bool _sharing = false;
  bool _shared = false;

  /// Set once the form has been saved as a template, so it's saved once.
  bool _templateSaved = false;

  Future<void> _saveTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.sendTemplateSaved;
    setState(() => _templateSaved = true);
    try {
      await ref.read(templateServiceProvider).createTemplate(widget.docId);
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    } catch (_) {
      if (mounted) setState(() => _templateSaved = false);
    }
  }

  // Fetch the doc once. Toggling _sharing/_shared calls setState; a fresh
  // getById() future per build would reload and can flicker.
  late final Future<Document?> _docFuture = ref
      .read(documentRepositoryProvider)
      .getById(widget.docId);

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
          title: Text(context.l10n.sendTitle),
          leading: IconButton(
            icon: Icon(_shared ? Icons.check : Icons.arrow_back),
            tooltip: context.l10n.sendBackToLibrary,
            onPressed: () => context.go(AppRoutes.library),
          ),
        ),
        body: FutureBuilder(
          future: _docFuture,
          builder: (context, snapshot) {
            final doc = snapshot.data;
            // Prefer the locked/flattened PDF; fall back to the fillable
            // export (this screen is reached from either "Flatten & Sign" or
            // "Save as Fillable").
            final storedPdf = doc?.pressedPdfPath ?? doc?.fillablePdfPath;
            final pdfPath = storedPdf == null
                ? null
                : PathResolver.resolve(storedPdf);

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
                          ? context.l10n.sendDocumentSent
                          : context.l10n.sendReadyToSend,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shared
                          ? context.l10n.sendSharedBody
                          : context.l10n.sendReadyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    if (!_shared)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: (_sharing || pdfPath == null)
                              ? null
                              : () => _share(
                                  context,
                                  pdfPath,
                                  doc?.title ??
                                      context.l10n.documentFallbackTitle,
                                ),
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share),
                          label: Text(
                            _sharing
                                ? context.l10n.sendOpeningShareSheet
                                : context.l10n.sendSharePressed,
                          ),
                        ),
                      ),

                    if (!_shared && pdfPath != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.viewer.replaceAll(
                              ':docId',
                              '${widget.docId}',
                            ),
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(context.l10n.sendPreviewDocument),
                        ),
                      ),
                    ],

                    // Reuse this form next time: same pages and fields, empty.
                    if (pdfPath != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton.icon(
                          onPressed: _templateSaved ? null : _saveTemplate,
                          icon: Icon(
                            _templateSaved
                                ? Icons.check
                                : Icons.layers_outlined,
                          ),
                          label: Text(
                            _templateSaved
                                ? context.l10n.sendTemplateSavedShort
                                : context.l10n.sendSaveAsTemplate,
                          ),
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
                          label: Text(context.l10n.sendBackToLibrary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: pdfPath != null
                            ? () => _share(
                                context,
                                pdfPath,
                                doc?.title ??
                                    context.l10n.documentFallbackTitle,
                              )
                            : null,
                        icon: const Icon(Icons.share),
                        label: Text(context.l10n.sendShareAgain),
                      ),
                    ],

                    if (pdfPath == null && !_sharing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          context.l10n.sendNotYetPressed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
    BuildContext context,
    String pdfPath,
    String title,
  ) async {
    if (!File(pdfPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sendPressedPdfNotFound)),
      );
      return;
    }
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    // iPad (and iOS in general) requires a non-zero source rect to anchor the
    // share popover; without it share_plus throws a PlatformException.
    // Resolve strings before the await — `context` is unsafe past the gap.
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      final sent = await shareDocumentPdf(
        lock: ref.read(appLockProvider.notifier),
        pdfPath: pdfPath,
        title: title,
        message: l10n.sendShareMessage,
        origin: origin,
      );
      // Only "sent" if it was: dismissing the share sheet isn't sending.
      if (mounted) {
        setState(() {
          _sharing = false;
          _shared = _shared || sent;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sharing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sendShareFailed('$e'))),
      );
    }
  }
}
