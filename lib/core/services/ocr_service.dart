import 'dart:io';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Reads the text on a page image, on the phone, through
/// `com.scansignsend/ocr`: Apple Vision on iOS (TextRecognitionPlugin.swift),
/// ML Kit text recognition on Android (TextRecognitionPlugin.kt). Neither
/// sends anything off the phone: iOS links no networking SDK, and the
/// Android app has no INTERNET permission.
///
/// Method "read" {path} → {width, height, lines: [{text, box, words: [{text,
/// box}]}]}, boxes as [left, top, right, bottom] in image pixels, origin
/// top-left. Lines come in reading order.
class OcrService {
  static const _channel = MethodChannel('com.scansignsend/ocr');

  Future<OcrResult> processPage(String imagePath) async {
    final answer = await _channel.invokeMapMethod<String, dynamic>('read', {
      'path': imagePath,
    });
    final read = parseOcrAnswer(answer);

    // Field bboxes are normalised against this width/height, then later
    // rendered against the real page/image widget size — the two MUST agree.
    // The union of OCR text boxes is not a substitute for the actual image
    // size: any page with margins, whitespace, or a header/footer the
    // recognizer didn't box makes that union smaller than the real page,
    // which drags every detected field off its true position once rendered.
    var imageWidth = read.imageWidth;
    var imageHeight = read.imageHeight;
    if (imageWidth <= 1 || imageHeight <= 1) {
      try {
        // Header-only read in a background isolate: decoding a 12 MP scan
        // on the UI thread just to learn its size froze the app.
        final size = await compute(_imageSize, imagePath);
        if (size != null && size.$1 > 0 && size.$2 > 0) {
          imageWidth = size.$1;
          imageHeight = size.$2;
        }
      } catch (_) {
        // Fall through to the text-extent fallback below.
      }
    }
    if (imageWidth <= 1 || imageHeight <= 1) {
      // No size at all — better an approximate one than none.
      double maxX = 1, maxY = 1;
      for (final b in read.blocks) {
        final r = b.boundingBox;
        if (r.right > maxX) maxX = r.right;
        if (r.bottom > maxY) maxY = r.bottom;
      }
      imageWidth = maxX.ceil();
      imageHeight = maxY.ceil();
    }
    return OcrResult(
      fullText: read.fullText,
      blocks: read.blocks,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  void dispose() {}
}

/// The channel's answer as an [OcrResult], one block per line. A missing or
/// malformed part reads as no text, never as an error: a page with no text
/// is a normal answer.
@visibleForTesting
OcrResult parseOcrAnswer(Map<String, dynamic>? answer) {
  Rect? box(Object? v) {
    if (v is! List || v.length != 4) return null;
    final n = [for (final x in v) (x as num).toDouble()];
    return Rect.fromLTRB(n[0], n[1], n[2], n[3]);
  }

  final lines = <OcrTextLine>[];
  for (final l in (answer?['lines'] as List?) ?? const []) {
    if (l is! Map) continue;
    final text = l['text'];
    final lineBox = box(l['box']);
    if (text is! String || lineBox == null) continue;
    lines.add(
      OcrTextLine(
        text: text,
        boundingBox: lineBox,
        elements: [
          for (final w in (l['words'] as List?) ?? const [])
            if (w is Map && w['text'] is String && box(w['box']) != null)
              OcrTextElement(
                text: w['text'] as String,
                boundingBox: box(w['box'])!,
              ),
        ],
      ),
    );
  }
  return OcrResult(
    fullText: lines.map((l) => l.text).join('\n'),
    blocks: [
      for (final l in lines)
        OcrTextBlock(text: l.text, boundingBox: l.boundingBox, lines: [l]),
    ],
    imageWidth: (answer?['width'] as num?)?.toInt() ?? 0,
    imageHeight: (answer?['height'] as num?)?.toInt() ?? 0,
  );
}

/// compute() entry: (width, height) of the image at [path], from its header.
(int, int)? _imageSize(String path) {
  final bytes = File(path).readAsBytesSync();
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info != null) return (info.width, info.height);
  final decoded = img.decodeImage(bytes);
  return decoded == null ? null : (decoded.width, decoded.height);
}
