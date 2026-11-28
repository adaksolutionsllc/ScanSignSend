// OCR gate (plan 1.3.2, J7): does field detection find the same fields when
// it reads a form through OCR as when it reads the form's own text layer?
//
// Each test form is a born-digital PDF. Its text layer gives the "truth"
// fields. Each page is then rendered like a scan (a JPEG, no text layer) and
// read by the platform OCR: Apple Vision on iOS, ML Kit on Android. Run it
// on both and compare the GATE_TOTAL lines.
//
//   tool/verify/device_check.sh <device> --ocr-gate
//
// The script copies the forms into the app's temp folder on NEED:gate.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/services/field_detection_engine.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';

const gateForms = [
  'Rental_Application',
  'Demande_de_location',
  'Solicitud_de_alquiler',
  'Ficha_de_locacao',
  'fw4',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR finds the fields the text layer finds', (tester) async {
    final tmp = await getTemporaryDirectory();
    final files = [
      for (final f in gateForms) File(p.join(tmp.path, 'gate_$f.pdf')),
    ];
    // ignore: avoid_print
    print('NEED:gate');
    await tester.runAsync(() async {
      final until = DateTime.now().add(const Duration(seconds: 60));
      while (!files.every((f) => f.existsSync() && f.lengthSync() > 0)) {
        if (DateTime.now().isAfter(until)) fail('gate forms were not provided');
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });

    final layouts = PageLayoutService(OcrService(), PageRasterService());
    final engine = FieldDetectionEngine();
    var truthAll = 0, ocrAll = 0, matchedAll = 0;
    final clock = Stopwatch();
    var pagesAll = 0;

    for (final (i, file) in files.indexed) {
      await tester.runAsync(() async {
        final bytes = await file.readAsBytes();
        var pageIndex = -1;
        await for (final page in Printing.raster(
          bytes,
          dpi: EdgeCheckService.pdfPageDpi,
        )) {
          pageIndex++;
          pagesAll++;
          final scan = p.join(tmp.path, 'gate_${gateForms[i]}_$pageIndex.jpg');
          saveRender((page.pixels, page.width, page.height, null, scan));
          final (truthLayout, _) = await layouts.analyse(
            '${file.path}#page=$pageIndex',
          );
          clock.start();
          final (ocrLayout, _) = await layouts.analyse(scan);
          clock.stop();
          final truth = engine.detect(truthLayout).fields;
          final ocr = engine.detect(ocrLayout).fields;
          final matched = _matches(truth, ocr);
          truthAll += truth.length;
          ocrAll += ocr.length;
          matchedAll += matched;
          // ignore: avoid_print
          print(
            'GATE:${gateForms[i]}:p$pageIndex:truth=${truth.length}'
            ':ocr=${ocr.length}:matched=$matched'
            ':words=${ocrLayout.lines.fold<int>(0, (a, l) => a + l.words.length)}',
          );
        }
      });
    }
    final recall = truthAll == 0 ? 0 : matchedAll / truthAll;
    final precision = ocrAll == 0 ? 0 : matchedAll / ocrAll;
    // ignore: avoid_print
    print(
      'GATE_TOTAL truth=$truthAll ocr=$ocrAll matched=$matchedAll '
      'recall=${recall.toStringAsFixed(3)} precision=${precision.toStringAsFixed(3)} '
      'ocr_ms_per_page=${(clock.elapsedMilliseconds / math.max(pagesAll, 1)).round()}',
    );
    expect(truthAll, greaterThan(0));
  });
}

/// Truth fields that an OCR field overlaps (IoU over 0.3), each used once.
int _matches(List<DetectedField> truth, List<DetectedField> ocr) {
  final left = [...ocr];
  var n = 0;
  for (final t in truth) {
    final hit = left.indexWhere((o) => _iou(t.bbox, o.bbox) > 0.3);
    if (hit >= 0) {
      left.removeAt(hit);
      n++;
    }
  }
  return n;
}

double _iou(BoundingBox a, BoundingBox b) {
  final x1 = math.max(a.x, b.x), y1 = math.max(a.y, b.y);
  final x2 = math.min(a.x + a.w, b.x + b.w),
      y2 = math.min(a.y + a.h, b.y + b.h);
  if (x2 <= x1 || y2 <= y1) return 0;
  final inter = (x2 - x1) * (y2 - y1);
  return inter / (a.w * a.h + b.w * b.h - inter);
}
