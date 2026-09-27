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
import '../../../core/services/app_lock_provider.dart';

/// What the capture screen should start straight away when opened from a
/// library button, so "New Scan" opens the camera and "Import" the file
/// picker without an extra tap.
enum CaptureAction { scan, import }

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, this.action});

  /// Started on open; cancelling it returns to where the user came from.
  final CaptureAction? action;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  bool _loading = false;
  String? _loadingMessageKey; // resolved through AppLocalizations in build()

  @override
  void initState() {
    super.initState();
    final action = widget.action;
    if (action != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (action) {
          case CaptureAction.scan:
            _startScan();
          case CaptureAction.import:
            _importFile();
        }
      });
    }
  }

  /// A cancelled scan/import that was started for the user (from a library
  /// button) leaves this screen too, instead of stranding them on it.
  void _leaveIfAutoStarted() {
    if (widget.action != null && mounted && context.canPop()) context.pop();
  }

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
      final paths = await ref
          .read(appLockProvider.notifier)
          .whileExternal(scanService.scan);
      if (paths.isEmpty) {
        // User cancelled
        if (mounted) setState(() => _loading = false);
        _leaveIfAutoStarted();
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
    // An import starts a document just like a scan does, so it counts toward
    // the free limit. It used to skip both the check and the count, which let
    // a free user import and complete documents without ever reaching the
    // paywall.
    final profileRepo = ref.read(profileRepositoryProvider);
    if (!await profileRepo.canScan()) {
      if (mounted) _showPaywall();
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadingMessageKey = 'importing';
    });
    try {
      final doc = await ref
          .read(appLockProvider.notifier)
          .whileExternal(ref.read(importServiceProvider).pickAndImport);
      if (doc == null) {
        if (mounted) setState(() => _loading = false);
        _leaveIfAutoStarted();
        return;
      }
      await profileRepo.incrementScanCount();
      if (mounted) {
        setState(() => _loading = false);
        // A PDF that already carries a fillable form goes straight to Fill
        // mode — its fields are ready to use. "Edit fields" there still lets
        // the user adjust or add to them.
        final route = doc.ocrText == ImportService.formFieldsSentinel
            ? AppRoutes.fillMode
            : AppRoutes.review;
        context.pushReplacement(route.replaceAll(':docId', '${doc.id}'));
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
          ImportException(failure: ImportFailure.unreadableImage) =>
            l10n.importErrorUnreadableImage,
          _ => l10n.captureImportFailed('$e'),
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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

    // Files first, then every row in one transaction: a crash part-way can
    // then never leave a document in the library with only some of its pages.
    final dests = <String>[];
    for (var i = 0; i < tempPaths.length; i++) {
      final dest = p.join(pagesDir.path, 'page_$i.jpg');
      final src = File(tempPaths[i]);
      await src.copy(dest);
      // Remove the staging file now that it's safely copied
      try {
        await src.delete();
      } catch (_) {}
      dests.add(dest);
    }

    return docRepo.transaction(() async {
      final doc = await docRepo.createDocument(_defaultTitle);
      for (var i = 0; i < dests.length; i++) {
        await pageRepo.addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: dests[i],
        );
      }
      await docRepo.updateDocument(
        DocumentsCompanion(
          id: Value(doc.id),
          pageCount: Value(dests.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return doc.id;
    });
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
                  Text(switch (_loadingMessageKey) {
                    'saving' => context.l10n.captureSavingPages,
                    'importing' => context.l10n.captureImporting,
                    _ => context.l10n.captureLaunching,
                  }, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.document_scanner_outlined,
                    size: 96,
                    color: Colors.white30,
                  ),
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
                    icon: const Icon(Icons.upload_file, color: Colors.white70),
                    label: Text(
                      context.l10n.captureImportPdfImage,
                      style: TextStyle(color: Colors.white70),
                    ),
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
