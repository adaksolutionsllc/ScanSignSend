import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Keeps a long job going (plan 1.3.2): the screen on while the app is open,
/// and the app running when the user leaves it or locks the phone.
///
/// Channel `com.scansignsend/background`:
/// - "keepScreenOn" {on}: iOS `isIdleTimerDisabled`, Android
///   `FLAG_KEEP_SCREEN_ON`.
/// - "begin" / "progress" {title, subtitle, done, total}, "end": iOS 26+ a
///   continued-processing task (the system shows the progress), older iOS a
///   short background task; Android a foreground service with a progress
///   notification (BackgroundWorkPlugin.swift, ImportWorkService.kt).
/// - "expired" (from the phone): the system ended the background time; the
///   job pauses and goes on when the app is back.
class BackgroundWorkService {
  BackgroundWorkService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'expired') onExpired?.call();
    });
  }

  static const _channel = MethodChannel('com.scansignsend/background');

  /// Called when the system ends the background time.
  void Function()? onExpired;

  Future<void> keepScreenOn(bool on) => _call('keepScreenOn', {'on': on});

  Future<void> begin(String title, String subtitle, int done, int total) =>
      _call('begin', {
        'title': title,
        'subtitle': subtitle,
        'done': done,
        'total': total,
      });

  Future<void> progress(String title, String subtitle, int done, int total) =>
      _call('progress', {
        'title': title,
        'subtitle': subtitle,
        'done': done,
        'total': total,
      });

  Future<void> end() => _call('end');

  /// Never throws: the job goes on in the app even when the phone can't
  /// help (tests, an older phone).
  static Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Tests.
    } catch (e) {
      debugPrint('BackgroundWorkService: $method: $e');
    }
  }
}
