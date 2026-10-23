import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document_category.dart';

final onDeviceAiServiceProvider = Provider<OnDeviceAiService>(
  (ref) => OnDeviceAiService(),
);

/// Why the phone's own language model can or can't sort documents. The
/// Settings line and the one-time Library tip tell the user which one applies.
enum OnDeviceAiStatus {
  available,

  /// iPhone older than 15 Pro, or an Android phone without Gemini Nano.
  deviceNotEligible,

  /// An eligible iPhone on iOS older than 26.
  osTooOld,

  /// Apple Intelligence is switched off in the iPhone's Settings.
  notEnabled,

  /// The model is still downloading or being set up by the system.
  notReady,

  /// The phone's language isn't one the model supports.
  languageUnsupported,

  /// Android older than 8.0, or the system said "unavailable".
  unsupported,
}

/// The `com.scansignsend/on_device_ai` channel: Apple's Foundation Models on
/// iOS 26+, Gemini Nano through ML Kit's Prompt API on Android 8+. Everything
/// runs on the phone; document text is never sent anywhere.
///
/// Every failure (no handler, timeout, error, an answer outside the list)
/// returns null so the caller falls back to keyword sorting.
class OnDeviceAiService {
  OnDeviceAiService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.scansignsend/on_device_ai');

  final MethodChannel _channel;

  static const timeout = Duration(seconds: 10);

  /// The model sees at most this much text: the title and the start of the
  /// document decide the category, and both models cap their input (Gemini
  /// Nano at 4,000 tokens).
  static const maxChars = 2000;

  OnDeviceAiStatus? _status;

  Future<OnDeviceAiStatus> status({bool refresh = false}) async {
    if (!refresh && _status != null) return _status!;
    try {
      final raw = await _channel
          .invokeMethod<String>('status')
          .timeout(const Duration(seconds: 3));
      _status = OnDeviceAiStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => OnDeviceAiStatus.unsupported,
      );
    } catch (_) {
      _status = OnDeviceAiStatus.unsupported;
    }
    return _status!;
  }

  /// The built-in category the model picks for the document, or null when
  /// it isn't sure, isn't available, or anything goes wrong.
  Future<BuiltInCategory?> classify(String title, String text) async {
    if (await status() != OnDeviceAiStatus.available) return null;
    try {
      final key = await _channel
          .invokeMethod<String>('classifyDocument', {
            'title': title,
            'text': text.length > maxChars ? text.substring(0, maxChars) : text,
            'categories': [for (final c in BuiltInCategory.values) c.key],
          })
          .timeout(timeout);
      return BuiltInCategory.fromKey(key);
    } catch (_) {
      return null;
    }
  }
}
