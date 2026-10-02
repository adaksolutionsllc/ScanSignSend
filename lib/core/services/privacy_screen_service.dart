import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final privacyScreenServiceProvider = Provider<PrivacyScreenService>((ref) {
  return PrivacyScreenService();
});

/// Keeps document contents out of screenshots and the OS task switcher.
///
/// Android: toggles `WindowManager.LayoutParams.FLAG_SECURE`, which blanks the
/// window in the recents thumbnail and blocks screenshots / screen recording.
/// iOS: the snapshot blur is handled entirely by `PrivacyOverlay` (activated in
/// `AppDelegate`; always on, since it costs the user nothing). There is no iOS
/// handler for this channel, so the call throws and is swallowed below.
///
/// Driven by the user's Biometric App Lock setting — someone who asked for a
/// lock on their documents does not expect those documents to be legible in the
/// app switcher.
class PrivacyScreenService {
  static const _channel = MethodChannel('com.scansignsend/privacy');

  Future<void> setSecure(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } catch (_) {
      // Platform not implemented / channel unavailable — privacy hardening is
      // best-effort and must never break app start.
    }
  }
}
