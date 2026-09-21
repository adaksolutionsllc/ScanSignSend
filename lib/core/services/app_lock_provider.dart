import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_service.dart';
import 'privacy_screen_service.dart';
import 'profile_repository.dart';
import '../utils/l10n_ext.dart';

/// True = locked, false = unlocked.
final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(
    ref.watch(biometricServiceProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(privacyScreenServiceProvider),
  );
});

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier(this._bio, this._profile, this._privacy) : super(false) {
    _init();
  }

  final BiometricService _bio;
  final ProfileRepository _profile;
  final PrivacyScreenService _privacy;

  bool _authInFlight = false;
  /// The OS biometric sheet needs a localized prompt, but this notifier lives
  /// outside the widget tree. [AppLockGate] pushes the translated string in on
  /// every build, which always happens before the user can trigger an unlock.
  String _authReason = 'Unlock Scan Sign Send';

  /// ignore: use_setters_to_change_properties
  void setAuthReason(String reason) => _authReason = reason;
  /// Mirror of `profile.biometricLockEnabled`, kept live so toggling the
  /// setting takes effect without a restart.
  bool _lockEnabled = false;
  StreamSubscription<dynamic>? _profileSub;

  Future<void> _init() async {
    try {
      final profile = await _profile.getOrCreate();
      _applyLockEnabled(profile.biometricLockEnabled);
      if (_lockEnabled) {
        state = true;
        await unlock();
      }
    } catch (_) {
      // Never leave the user stranded on a lock screen due to a profile read
      // failure — default to unlocked rather than bricking the app.
      state = false;
    }
    _profileSub = _profile.watch().listen(
      (p) => _applyLockEnabled(p.biometricLockEnabled),
      onError: (_) {},
    );
  }

  void _applyLockEnabled(bool enabled) {
    if (_lockEnabled == enabled) return;
    _lockEnabled = enabled;
    // Someone who locks their documents doesn't want them legible in the task
    // switcher or in a screenshot either.
    _privacy.setSecure(enabled);
  }

  /// Re-arms the lock when the app leaves the foreground.
  ///
  /// Without this the lock was a cold-start-only gate: background the app,
  /// hand the unlocked phone to someone, and every scanned document was
  /// readable. We re-lock on `paused` rather than `inactive` so the platform
  /// biometric sheet — which briefly makes the app inactive — doesn't fight
  /// the unlock it was opened to perform.
  void handleLifecycle(AppLifecycleState lifecycle) {
    if (!_lockEnabled) return;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached ||
        lifecycle == AppLifecycleState.hidden) {
      state = true;
    }
  }

  Future<void> unlock() async {
    if (_authInFlight) return; // guard against double taps stacking prompts
    _authInFlight = true;
    try {
      final ok = await _bio.authenticate(reason: _authReason);
      if (ok) state = false;
    } catch (_) {
      // Auth plugin threw (no hardware, cancelled, etc.) — stay locked but
      // the user can retry via the Unlock button.
    } finally {
      _authInFlight = false;
    }
  }

  void lock() => state = true;

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }
}

/// Wraps the app; shows a lock screen when [appLockProvider] is true, and
/// observes the app lifecycle so the lock re-arms every time the app is
/// backgrounded.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Touch the provider so the notifier is constructed (and the privacy
    // screen flag applied) even before anything else reads the lock state.
    ref.read(appLockProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    ref.read(appLockProvider.notifier).handleLifecycle(lifecycle);
  }

  @override
  Widget build(BuildContext context) {
    ref.read(appLockProvider.notifier).setAuthReason(context.l10n.biometricReason);
    final locked = ref.watch(appLockProvider);
    if (!locked) return widget.child;

    return Scaffold(
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
                context.l10n.lockTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.lockBody,
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
                label: Text(context.l10n.lockUnlock),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
