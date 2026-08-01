import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/iap_service.dart';

/// Full-screen paywall shown when the user has exhausted free scans.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  String? _error;
  String _price = '\$14.99'; // fallback until the live store price loads

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
        title: const Text('Unlock Full Access'),
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
            const Icon(Icons.workspace_premium,
                size: 80, color: Color(0xFF1A73E8)),
            const SizedBox(height: 24),
            Text('Scan Sign Send — Full Access',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'One-time purchase. No subscription. No account.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Feature list
            ...[
              (Icons.all_inclusive, 'Unlimited documents'),
              (Icons.layers, 'Reusable templates'),
              (Icons.draw, 'Multiple saved signatures'),
              (Icons.person, 'Profile autofill'),
              (Icons.lock_outline, 'Biometric app lock'),
              (Icons.cloud_off, 'Always offline — your data stays on device'),
            ].map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(row.$1, size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(row.$2,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )),

            const SizedBox(height: 32),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _buy,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Unlock — $_price',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : _restore,
              child: const Text('Restore Purchase'),
            ),
            const SizedBox(height: 8),
            Text(
              'Payment charged to your App Store / Play account at confirmation.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
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
      await ref.read(iapServiceProvider).buy();
      // Purchase result handled by IapService stream → isPurchasedProvider
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
      final restored = await ref.read(iapServiceProvider).restore();
      if (!mounted) return;
      if (restored) {
        Navigator.of(context).pop();
      } else {
        setState(() =>
            _error = 'No previous purchase found on this account.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
