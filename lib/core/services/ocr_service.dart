import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

    // Derive image size from the union of all block bounding boxes
    // (InputImage metadata not always available without decoding the bitmap).
    double maxX = 1, maxY = 1;
    for (final b in recognized.blocks) {
      final r = b.boundingBox;
      if (r.right > maxX) maxX = r.right;
      if (r.bottom > maxY) maxY = r.bottom;
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
      imageWidth: maxX.ceil(),
      imageHeight: maxY.ceil(),
    );
  }

  void dispose() => _recognizer.close();
}
