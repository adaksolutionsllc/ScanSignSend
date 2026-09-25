import 'dart:io';

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

class OcrTextBlock {
  final String text;
  final Rect boundingBox;
  final List<OcrTextLine> lines;
  const OcrTextBlock({
    required this.text,
    required this.boundingBox,
    required this.lines,
  });
}

class OcrTextLine {
  final String text;
  final Rect boundingBox;
  const OcrTextLine({required this.text, required this.boundingBox});
}

class OcrResult {
  final String fullText;
  final List<OcrTextBlock> blocks;
  /// Image pixel dimensions returned by the recogniser
  final int imageWidth;
  final int imageHeight;
  const OcrResult({
    required this.fullText,
    required this.blocks,
    required this.imageWidth,
    required this.imageHeight,
  });
}

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> processPage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);

    // Field bboxes are normalised against this width/height, then later
    // rendered against the real page/image widget size — the two MUST agree.
    // The union of OCR text-block boxes is not a substitute for the actual
    // image size: any page with margins, whitespace, or a header/footer the
    // recognizer didn't box makes that union smaller than the real page,
    // which drags every detected field off its true position once rendered.
    var imageWidth = 1;
    var imageHeight = 1;
    try {
      final decoded = img.decodeImage(await File(imagePath).readAsBytes());
      if (decoded != null && decoded.width > 0 && decoded.height > 0) {
        imageWidth = decoded.width;
        imageHeight = decoded.height;
      }
    } catch (_) {
      // Fall through to the text-extent fallback below.
    }
    if (imageWidth <= 1 || imageHeight <= 1) {
      // Decode failed — better an approximate size than none.
      double maxX = 1, maxY = 1;
      for (final b in recognized.blocks) {
        final r = b.boundingBox;
        if (r.right > maxX) maxX = r.right;
        if (r.bottom > maxY) maxY = r.bottom;
      }
      imageWidth = maxX.ceil();
      imageHeight = maxY.ceil();
    }

    final blocks = recognized.blocks.map((b) {
      final lines = b.lines.map((l) => OcrTextLine(
            text: l.text,
            boundingBox: l.boundingBox,
          )).toList();
      return OcrTextBlock(
        text: b.text,
        boundingBox: b.boundingBox,
        lines: lines,
      );
    }).toList();

    return OcrResult(
      fullText: recognized.text,
      blocks: blocks,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  void dispose() => _recognizer.close();
}
