import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../core/db/app_database.dart';
import '../../core/models/document_model.dart';
import '../../core/services/app_lock_provider.dart';
import '../../core/services/document_repository.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/router.dart';

/// Quick action types, as the OS hands them back.
abstract final class QuickActionType {
  static const scan = 'scan';
  static const openPdf = 'open_pdf';
  static const lastDraft = 'last_draft';
}

/// The draft "Fill last draft" opens: the most recently changed document
/// that is still being filled (a draft, or one shared as fillable).
Document? lastDraft(List<Document> docs) {
  Document? best;
  for (final d in docs) {
    final s = d.statusEnum;
    if (s != DocumentStatus.draft && s != DocumentStatus.fillable) continue;
    if (best == null || d.updatedAt.isAfter(best.updatedAt)) best = d;
  }
  return best;
}

/// Where a quick action goes, or null when there's nothing to open.
String? quickActionRoute(String type, List<Document> docs) => switch (type) {
  QuickActionType.scan => '${AppRoutes.capture}?action=scan',
  QuickActionType.openPdf => '${AppRoutes.capture}?action=import',
  QuickActionType.lastDraft => switch (lastDraft(docs)) {
    final d? => AppRoutes.fillMode.replaceAll(':docId', '${d.id}'),
    null => null,
  },
  _ => null,
};

/// The home-screen quick actions (press and hold the app icon): Scan, Open
/// a PDF, and Fill last draft while there is one. Titles follow the app's
/// language. An action waits for the app lock: the camera or file picker
/// must never open over the lock screen.
///
/// The same three actions come from Siri, Spotlight and the Shortcuts app on
/// iOS (AppShortcuts.swift), through [shortcuts]. Those can't be hidden when
/// there is no draft, so "Fill my last draft" then says so.
class QuickActionsSetup extends ConsumerStatefulWidget {
  const QuickActionsSetup({
    super.key,
    required this.child,
    this.quickActions = const QuickActions(),
    this.shortcuts = const MethodChannel('com.scansignsend/shortcuts'),
  });

  final Widget child;
  final QuickActions quickActions;
  final MethodChannel shortcuts;

  @override
  ConsumerState<QuickActionsSetup> createState() => _QuickActionsSetupState();
}

class _QuickActionsSetupState extends ConsumerState<QuickActionsSetup> {
  StreamSubscription<List<Document>>? _docsSub;
  List<Document> _docs = const [];
  bool? _hasDraft;
  (String, String, String)? _titles;

  @override
  void initState() {
    super.initState();
    widget.quickActions.initialize(_handle);
    widget.shortcuts.setMethodCallHandler((call) async {
      if (call.method == 'pending') await _takeShortcut();
    });
    unawaited(_takeShortcut());
    _docsSub = ref.read(documentRepositoryProvider).watchAll().listen((docs) {
      _docs = docs;
      final hasDraft = lastDraft(docs) != null;
      if (hasDraft != _hasDraft) {
        _hasDraft = hasDraft;
        _apply();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    final titles = (l10n.quickScan, l10n.quickOpenPdf, l10n.quickLastDraft);
    if (titles != _titles) {
      _titles = titles;
      _apply();
    }
  }

  @override
  void dispose() {
    widget.shortcuts.setMethodCallHandler(null);
    _docsSub?.cancel();
    super.dispose();
  }

  /// A Siri / Shortcuts action queued natively (cold launch included).
  Future<void> _takeShortcut() async {
    try {
      final type = await widget.shortcuts.invokeMethod<String>('takePending');
      if (type != null) await _handle(type);
    } on MissingPluginException {
      // Android and tests: no shortcuts channel.
    }
  }

  void _apply() {
    final titles = _titles;
    if (titles == null) return;
    final (scan, open, draft) = titles;
    unawaited(
      widget.quickActions
          .setShortcutItems([
            ShortcutItem(
              type: QuickActionType.scan,
              localizedTitle: scan,
              icon: 'qa_scan',
            ),
            ShortcutItem(
              type: QuickActionType.openPdf,
              localizedTitle: open,
              icon: 'qa_open',
            ),
            if (_hasDraft ?? false)
              ShortcutItem(
                type: QuickActionType.lastDraft,
                localizedTitle: draft,
                icon: 'qa_draft',
              ),
          ])
          .catchError((Object _) {}),
    );
  }

  Future<void> _handle(String type) async {
    final lock = ref.read(appLockProvider.notifier);
    final router = ref.read(routerProvider);
    final docs = ref.read(documentRepositoryProvider);
    await lock.whenUnlocked();
    // A cold launch delivers the action before the first frame: let the
    // router build its first page before pushing onto it.
    await WidgetsBinding.instance.endOfFrame;
    final route = quickActionRoute(
      type,
      type == QuickActionType.lastDraft ? await docs.watchAll().first : _docs,
    );
    if (!mounted) return;
    if (route != null) {
      unawaited(router.push(route));
    } else if (type == QuickActionType.lastDraft) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.shortcutNoDraft)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
