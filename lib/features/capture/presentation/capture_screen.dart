import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/import_service.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/services/scan_service.dart';
import '../../../core/utils/router.dart';
import '../../../shared/widgets/paywall_screen.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/l10n_ext.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  bool _loading = false;
  String? _loadingMessageKey; // resolved through AppLocalizations in build()

  Future<void> _startScan() async {
    // Resolve the localized default title first: everything below runs past an
    // async gap, where reading `context` is unsafe.
    _defaultTitle = context.l10n.captureDefaultDocumentName(_dateStamp());

    final profileRepo = ref.read(profileRepositoryProvider);
    final canScan = await profileRepo.canScan();
    if (!canScan && mounted) {
      _showPaywall();
      return;
    }

    setState(() {
      _loading = true;
      _loadingMessageKey = 'launching';
    });

    try {
      final scanService = ref.read(scanServiceProvider);
      final paths = await scanService.scan();
      if (paths.isEmpty) {
        // User cancelled
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (mounted) setState(() => _loadingMessageKey = 'saving');
      final docId = await _saveScannedPages(paths);
      await profileRepo.incrementScanCount();

      if (mounted) {
        setState(() => _loading = false);
        context.pushReplacement(
          AppRoutes.review.replaceAll(':docId', '$docId'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.captureScanFailed('$e'))),
        );
      }
    }
  }

  Future<void> _importFile() async {
    setState(() {
      _loading = true;
      _loadingMessageKey = 'importing';
    });
    try {
      final doc = await ref.read(importServiceProvider).pickAndImport();
      if (doc == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (mounted) {
        setState(() => _loading = false);
        context.pushReplacement(
          AppRoutes.review.replaceAll(':docId', '${doc.id}'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // ImportService reports a typed cause so the message can be localized
        // here; anything else falls back to the generic failure text.
        final l10n = context.l10n;
        final message = switch (e) {
          ImportException(failure: ImportFailure.unreadablePdf) =>
            l10n.importErrorUnreadable,
          ImportException(failure: ImportFailure.emptyPdf) =>
            l10n.importErrorNoPages,
          _ => l10n.captureImportFailed('$e'),
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  /// Captured in the caller (which has a BuildContext) before the async work.
  String _defaultTitle = 'Document';

  Future<int> _saveScannedPages(List<String> tempPaths) async {
    final uuid = const Uuid().v4();
    final appDir = await getApplicationDocumentsDirectory();
    final pagesDir = Directory(p.join(appDir.path, 'pages', uuid));
    await pagesDir.create(recursive: true);

    final docRepo = ref.read(documentRepositoryProvider);
    final pageRepo = ref.read(pageRepositoryProvider);

    final doc = await docRepo.createDocument(_defaultTitle);

    for (var i = 0; i < tempPaths.length; i++) {
      final dest = p.join(pagesDir.path, 'page_$i.jpg');
      final src = File(tempPaths[i]);
      await src.copy(dest);
      // Remove the staging file now that it's safely copied
      try { await src.delete(); } catch (_) {}
      await pageRepo.addPage(
        documentId: doc.id,
        pageIndex: i,
        imagePath: dest,
      );
    }

    await docRepo.updateDocument(DocumentsCompanion(
      id: Value(doc.id),
      pageCount: Value(tempPaths.length),
      updatedAt: Value(DateTime.now()),
    ));

    return doc.id;
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _showPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PaywallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.captureTitle),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    switch (_loadingMessageKey) {
                      'saving' => context.l10n.captureSavingPages,
                      'importing' => context.l10n.captureImporting,
                      _ => context.l10n.captureLaunching,
                    },
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.document_scanner_outlined,
                      size: 96, color: Colors.white30),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(context.l10n.captureScanWithCamera),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(220, 52),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _importFile,
                    icon: const Icon(Icons.upload_file,
                        color: Colors.white70),
                    label: Text(context.l10n.captureImportPdfImage,
                        style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      minimumSize: const Size(220, 52),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    context.l10n.captureUpTo20Pages,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
