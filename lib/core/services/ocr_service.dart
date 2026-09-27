import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
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

  /// The line's words, each with its own box.
  final List<OcrTextElement> elements;
  const OcrTextLine({
    required this.text,
    required this.boundingBox,
    this.elements = const [],
  });
}

class OcrTextElement {
  final String text;
  final Rect boundingBox;
  const OcrTextElement({required this.text, required this.boundingBox});
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
      // Header-only read in a background isolate: decoding a 12 MP scan on
      // the UI thread just to learn its size froze the app during detection.
      final size = await compute(_imageSize, imagePath);
      if (size != null && size.$1 > 0 && size.$2 > 0) {
        imageWidth = size.$1;
        imageHeight = size.$2;
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
      final lines = b.lines
          .map(
            (l) => OcrTextLine(
              text: l.text,
              boundingBox: l.boundingBox,
              elements: [
                for (final e in l.elements)
                  OcrTextElement(text: e.text, boundingBox: e.boundingBox),
              ],
            ),
          )
          .toList();
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

/// compute() entry: (width, height) of the image at [path], from its header.
(int, int)? _imageSize(String path) {
  final bytes = File(path).readAsBytesSync();
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info != null) return (info.width, info.height);
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}
