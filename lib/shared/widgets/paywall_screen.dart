import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/iap_service.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/services/app_lock_provider.dart';

/// Full-screen paywall shown when the user has exhausted free scans.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  String? _error;

  /// The live, store-localized price. Null until the store responds — and it
  /// stays null if the store is unreachable. Never substitute a hardcoded
  /// number here: showing a price the user won't actually be charged is both
  /// wrong and an App Store review risk.
  String? _price;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    final price = await ref.read(iapServiceProvider).localizedPrice();
    if (price != null && mounted) setState(() => _price = price);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.paywallTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Icon(
              Icons.workspace_premium,
              size: 80,
              color: Color(0xFF1A73E8),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.paywallHeadline,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.paywallSubhead,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Feature list
            ...[
              (Icons.all_inclusive, context.l10n.paywallBenefitUnlimited),
              (Icons.layers, context.l10n.paywallBenefitTemplates),
              (Icons.draw, context.l10n.paywallBenefitSignatures),
              (Icons.person, context.l10n.paywallBenefitAutofill),
              (Icons.lock_outline, context.l10n.paywallBenefitLock),
              (Icons.cloud_off, context.l10n.paywallBenefitOffline),
            ].map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      row.$1,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(row.$2, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _buy,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _price == null
                            ? context.l10n.paywallTitle
                            : context.l10n.paywallUnlockForPrice(_price!),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : _restore,
              child: Text(context.l10n.paywallRestore),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.paywallPaymentDisclosure,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buy() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(appLockProvider.notifier)
          .whileExternal(ref.read(iapServiceProvider).buy);
      // Purchase result handled by IapService stream → isPurchasedProvider
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = iapErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final restored = await ref
          .read(appLockProvider.notifier)
          .whileExternal(ref.read(iapServiceProvider).restore);
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = context.l10n.paywallNoPreviousPurchase);
      }
    } catch (e) {
      if (mounted) setState(() => _error = iapErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// A translated, user-facing message for a failed store call.
String iapErrorText(BuildContext context, Object error) {
  final l10n = context.l10n;
  return switch (error) {
    IapException(failure: IapFailure.unavailable) => l10n.iapErrorUnavailable,
    IapException(failure: IapFailure.productNotFound) =>
      l10n.iapErrorProductNotFound,
    _ => l10n.iapErrorPurchaseFailed,
  };
}
