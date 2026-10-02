import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_model.dart';
import 'field_detection_engine.dart';
import 'field_hints.dart';
import 'page_layout.dart';
import 'profile_repository.dart';

final aiEnhancerServiceProvider = Provider<AiEnhancerService>((ref) {
  return AiEnhancerService(ref.watch(profileRepositoryProvider));
});

/// Wraps the on-device AI channel.
/// Intended for iOS 26+ Foundation Models: ask the model to semantically label
/// form fields from the OCR text, returning structured DetectedField results.
/// The native side is currently a stub that returns no fields, and Android has
/// no handler, so detection always falls back to the heuristic engine.
class AiEnhancerService {
  AiEnhancerService(this._profileRepo);
  final ProfileRepository _profileRepo;

  static const _channel = MethodChannel('com.scansignsend/ai_enhancer');
  static final _engine = FieldDetectionEngine();

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Detects fields on one page. Uses the on-device model when the toggle is
  /// on and the platform supports it, and the layout heuristics otherwise —
  /// including whenever the model returns nothing or errors. The page's text
  /// size always comes from the layout.
  Future<DetectionResult> detect(
    PageLayout layout, {
    LearnedHints hints = LearnedHints.none,
  }) async {
    final heuristic = _engine.detect(layout, hints: hints);
    final profile = await _profileRepo.getOrCreate();
    if (!profile.aiEnhancedDetection || !await isAvailable()) return heuristic;

    try {
      final raw = await _channel.invokeListMethod<Map>('enhance', {
        'ocrText': layout.lines.map((l) => l.text).join('\n'),
      });
      if (raw == null || raw.isEmpty) return heuristic;

      return DetectionResult([
        for (final m in raw)
          DetectedField(
            type: (m['type'] as String? ?? 'text').toFieldType(),
            bbox: BoundingBox(
              x: (m['x'] as num).toDouble(),
              y: (m['y'] as num).toDouble(),
              w: (m['w'] as num).toDouble(),
              h: (m['h'] as num).toDouble(),
            ),
            label: m['label'] as String? ?? '',
          ),
      ], heuristic.textSize);
    } catch (_) {
      // Any platform error → fall back to heuristics
      return heuristic;
    }
  }
}
