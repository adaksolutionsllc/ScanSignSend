import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_service.dart';
import 'profile_repository.dart';

/// True = locked, false = unlocked.
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(
    ref.watch(biometricServiceProvider),
    ref.watch(profileRepositoryProvider),
  );
});

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(this._bio, this._profile) : super(false) {
    _init();
  }

  final BiometricService _bio;
  final ProfileRepository _profile;

  Future<void> _init() async {
    final profile = await _profile.getOrCreate();
    if (profile.biometricLockEnabled) {
      state = true;
      await unlock();
    }
  }

  Future<void> unlock() async {
    final ok = await _bio.authenticate();
    if (ok) state = false;
  }

  void lock() => state = true;
}

/// Wraps the app; shows a lock screen when [appLockProvider] is true.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockProvider);
    if (!locked) return child;

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 72),
              const SizedBox(height: 16),
              const Text('Scan Sign Send is locked'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(appLockProvider.notifier).unlock(),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
