// Capture-only stand-in: same surface as the subset OcrService uses, and it
// recognises nothing. Store-capture demo documents are born-digital PDFs, whose
// text comes from the PDF text layer, not OCR.
import 'dart:ui' show Rect;

enum TextRecognitionScript { latin }

class InputImage {
  InputImage.fromFilePath(this.filePath);
  final String filePath;
}

class TextElement {
  const TextElement(this.text, this.boundingBox);
  final String text;
  final Rect boundingBox;
}

class TextLine {
  const TextLine(this.text, this.boundingBox, this.elements);
  final String text;
  final Rect boundingBox;
  final List<TextElement> elements;
}

class TextBlock {
  const TextBlock(this.text, this.boundingBox, this.lines);
  final String text;
  final Rect boundingBox;
  final List<TextLine> lines;
}

class RecognizedText {
  const RecognizedText(this.text, this.blocks);
  final String text;
  final List<TextBlock> blocks;
}

class TextRecognizer {
  TextRecognizer({this.script = TextRecognitionScript.latin});
  final TextRecognitionScript script;

  Future<RecognizedText> processImage(InputImage image) async =>
      const RecognizedText('', []);

  Future<void> close() async {}
}
