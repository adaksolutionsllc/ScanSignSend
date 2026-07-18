import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_model.dart';
import 'field_detection_engine.dart';
import 'ocr_service.dart';
import 'profile_repository.dart';

final aiEnhancerServiceProvider =
    Provider<AiEnhancerService>((ref) {
  return AiEnhancerService(ref.watch(profileRepositoryProvider));
});

/// Wraps the on-device AI channel.
/// On iOS 26+ with Foundation Models: asks the model to semantically label
/// form fields from the OCR text, returning structured DetectedField results.
/// Falls back to the heuristic engine on older OS or Android without Gemini Nano.
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

  /// Returns AI-enhanced fields if the toggle is on AND the platform supports it;
  /// otherwise falls back to heuristic detection.
  Future<List<DetectedField>> detect(OcrResult ocr) async {
    final profile = await _profileRepo.getOrCreate();
    if (!profile.aiEnhancedDetection) {
      return _engine.detect(ocr);
    }

    final available = await isAvailable();
    if (!available) return _engine.detect(ocr);

    try {
      final raw = await _channel.invokeListMethod<Map>(
        'enhance',
        {'ocrText': ocr.fullText},
      );
      if (raw == null || raw.isEmpty) return _engine.detect(ocr);

      return raw.map((m) {
        final type = switch (m['type'] as String? ?? 'text') {
          'date' => FieldType.date,
          'checkbox' => FieldType.checkbox,
          'signature' => FieldType.signature,
          _ => FieldType.text,
        };
        return DetectedField(
          type: type,
          bbox: BoundingBox(
            x: (m['x'] as num).toDouble(),
            y: (m['y'] as num).toDouble(),
            w: (m['w'] as num).toDouble(),
            h: (m['h'] as num).toDouble(),
          ),
          label: m['label'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      // Any platform error → fall back to heuristics
      return _engine.detect(ocr);
    }
  }
}
