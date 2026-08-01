import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
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

  bool _authInFlight = false;

  Future<void> _init() async {
    try {
      final profile = await _profile.getOrCreate();
      if (profile.biometricLockEnabled) {
        state = true;
        await unlock();
      }
    } catch (_) {
      // Never leave the user stranded on a lock screen due to a profile read
      // failure — default to unlocked rather than bricking the app.
      state = false;
    }
  }

  Future<void> unlock() async {
    if (_authInFlight) return; // guard against double taps stacking prompts
    _authInFlight = true;
    try {
      final ok = await _bio.authenticate();
      if (ok) state = false;
    } catch (_) {
      // Auth plugin threw (no hardware, cancelled, etc.) — stay locked but
      // the user can retry via the Unlock button.
    } finally {
      _authInFlight = false;
    }
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Scan Sign Send is locked',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock with Face ID or your fingerprint to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => ref.read(appLockProvider.notifier).unlock(),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(200, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
