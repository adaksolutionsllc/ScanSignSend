import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/free_usage_service.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/paywall_screen.dart';

/// A slim strip above the library for free users: how many free documents
/// are left, and Unlimited at its store price. Tapping it opens the paywall.
/// Hidden once Unlimited is owned (and while that's still loading).
class UnlimitedBanner extends ConsumerStatefulWidget {
  const UnlimitedBanner({super.key});

  @override
  ConsumerState<UnlimitedBanner> createState() => _UnlimitedBannerState();
}

class _UnlimitedBannerState extends ConsumerState<UnlimitedBanner> {
  StreamSubscription<Object?>? _profileSub;
  int? _left;
  String? _price;

  @override
  void initState() {
    super.initState();
    // The count lives in the profile (and the Keychain / Block Store copy
    // that remaining() reconciles), so re-read it whenever the profile
    // changes — e.g. right after a document is finished.
    _profileSub = ref
        .read(profileRepositoryProvider)
        .watch()
        .listen((_) => _refreshCount());
    ref.read(iapServiceProvider).localizedPrice().then((p) {
      if (mounted && p != null) setState(() => _price = p);
    });
  }

  Future<void> _refreshCount() async {
    final left = await ref.read(freeUsageServiceProvider).remaining();
    if (mounted) setState(() => _left = left);
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(isPurchasedProvider).valueOrNull ?? true;
    final left = _left;
    if (premium || left == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final price = _price;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: left == 0 ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const PaywallScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: context.l10n.libraryFreeLeft(left)),
                        const TextSpan(text: '  ·  '),
                        TextSpan(
                          text: price == null
                              ? context.l10n.paywallTitle
                              : context.l10n.libraryUnlimitedPrice(price),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    style: text.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
