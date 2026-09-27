import 'dart:typed_data';
import 'dart:ui' as ui;

/// Text the PDF library can't draw correctly, rendered by Flutter instead.
///
/// Syncfusion's PDF text only covers Latin-1 with its built-in fonts, and it
/// does no complex-script shaping even with an embedded TrueType font, so
/// Hindi, Tamil and Telugu came out blank or with vowel signs in the wrong
/// place. Flutter's text engine shapes every script correctly with the
/// phone's own fonts; for a flattened PDF, drawing that as a high-resolution
/// image is exactly right (the output isn't editable anyway).
///
/// Rendering needs the UI isolate, so values are prepared here before the
/// PDF is built in a background isolate, and travel with the job as PNGs.

/// True when [text] has characters the PDF's standard font can't show.
bool needsShaping(String text) => text.runes.any((r) => r > 0xFF);

/// A PNG of [text] set in the system font, [fontSize] logical px tall at
/// [scale]× resolution, trimmed to the text's own width.
Future<ShapedText> renderShapedText(
  String text, {
  double fontSize = 40,
  double scale = 3,
  ui.Color color = const ui.Color(0xFF000000),
  bool bold = false,
}) async {
  final style = ui.TextStyle(
    color: color,
    fontSize: fontSize * scale,
    fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
  );
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(maxLines: 1))
    ..pushStyle(style)
    ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: double.infinity));
  final w = paragraph.maxIntrinsicWidth.ceil().clamp(1, 16000);
  final h = paragraph.height.ceil().clamp(1, 4000);

  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return ShapedText(png!.buffer.asUint8List(), w.toDouble(), h.toDouble());
  } finally {
    image.dispose();
    paragraph.dispose();
  }
}

/// A rendered line of text: PNG bytes plus its pixel size (the aspect ratio
/// is what matters when it's placed in the PDF).
class ShapedText {
  const ShapedText(this.png, this.width, this.height);
  final Uint8List png;
  final double width;
  final double height;
}
