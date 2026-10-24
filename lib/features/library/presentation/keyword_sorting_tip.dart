import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/document_sorter.dart';
import '../../../core/services/on_device_ai_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/ai_sort_status.dart';

/// Shown once, the first time a document is sorted by keywords because this
/// phone's own AI model isn't available, saying why (hardware, iOS version,
/// a setting, the language). "Got it" hides it for good; Settings keeps the
/// same line under the sorting switch.
class KeywordSortingTip extends ConsumerStatefulWidget {
  const KeywordSortingTip({super.key});

  @override
  ConsumerState<KeywordSortingTip> createState() => _KeywordSortingTipState();
}

class _KeywordSortingTipState extends ConsumerState<KeywordSortingTip> {
  OnDeviceAiStatus? _status;
  late final DocumentSorter _sorter = ref.read(documentSorterProvider);

  @override
  void initState() {
    super.initState();
    _sorter.keywordTipDue.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    _sorter.keywordTipDue.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final due =
          (prefs.getBool(DocumentSorter.keywordTipPendingKey) ?? false) &&
          !(prefs.getBool(DocumentSorter.keywordTipShownKey) ?? false);
      if (!due) return;
      final status = await ref.read(onDeviceAiServiceProvider).status();
      if (mounted && status != OnDeviceAiStatus.available) {
        setState(() => _status = status);
      }
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    setState(() => _status = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DocumentSorter.keywordTipShownKey, true);
      await prefs.remove(DocumentSorter.keywordTipPendingKey);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.label_outline, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      aiSortMessage(context.l10n, status),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _dismiss,
                child: Text(context.l10n.actionGotIt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
