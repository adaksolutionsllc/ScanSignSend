import 'dart:ui' show Rect;


import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';

void main() {
  group('parseOcrAnswer', () {
    test('lines and words keep their text and pixel boxes', () {
      final r = parseOcrAnswer({
        'width': 1000,
        'height': 1400,
        'lines': [
          {
            'text': 'Name ______',
            'box': [100, 200, 600, 230],
            'words': [
              {
                'text': 'Name',
                'box': [100, 200, 220, 230],
              },
              {
                'text': '______',
                'box': [240, 200, 600, 230],
              },
            ],
          },
          {
            'text': 'Date',
            'box': [100.5, 300, 180, 330],
            'words': [],
          },
        ],
      });
      expect(r.imageWidth, 1000);
      expect(r.imageHeight, 1400);
      expect(r.fullText, 'Name ______\nDate');
      expect(r.blocks, hasLength(2));
      final line = r.blocks.first.lines.single;
      expect(line.boundingBox, const Rect.fromLTRB(100, 200, 600, 230));
      expect(line.elements.map((e) => e.text), ['Name', '______']);
      expect(
        line.elements.last.boundingBox,
        const Rect.fromLTRB(240, 200, 600, 230),
      );
      expect(r.blocks.last.boundingBox.left, 100.5);
    });

    test('no answer, or a broken part, reads as no text', () {
      final none = parseOcrAnswer(null);
      expect(none.fullText, '');
      expect(none.blocks, isEmpty);
      expect(none.imageWidth, 0);

      final broken = parseOcrAnswer({
        'lines': [
          {'text': 'no box'},
          {
            'text': 'short box',
            'box': [1, 2, 3],
          },
          {
            'text': 'ok',
            'box': [0, 0, 10, 10],
            'words': [
              {'text': 'ok'},
              'junk',
            ],
          },
        ],
      });
      expect(broken.fullText, 'ok');
      expect(broken.blocks.single.lines.single.elements, isEmpty);
    });
  });
}
