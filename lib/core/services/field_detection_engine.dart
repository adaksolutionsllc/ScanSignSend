import 'dart:math' as math;

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_model.dart';
import 'ocr_service.dart';

final fieldDetectionEngineProvider =
    Provider<FieldDetectionEngine>((ref) => FieldDetectionEngine());

/// A field candidate produced by the heuristic classifier.
class DetectedField {
  final FieldType type;
  final BoundingBox bbox; // normalised 0..1
  final String label;

  const DetectedField({
    required this.type,
    required this.bbox,
    required this.label,
  });
}

/// Pure-Dart, offline heuristic classifier.
///
/// Heuristic rules (applied in priority order):
///   1. Signature  — line text matches /signature|sign here|initial/i
///   2. Date       — line text matches /date/i  OR  follows a date-pattern label
///   3. Checkbox   — line text is a bracket/box glyph pattern (□ ☐ [ ] etc.)
///                   OR a very short wide-or-square element near a label
///   4. Text field — long underline sequences (___+) OR a line whose aspect
///                   ratio is very wide and thin relative to the page
class FieldDetectionEngine {
  // Regex constants
  static final _sigRe = RegExp(
      r'(signature|sign\s*here|initial|initials|authorized\s*by|signed\s*by)',
      caseSensitive: false);
  static final _dateRe =
      RegExp(r'\bdate\b', caseSensitive: false);
  static final _underscoreRe = RegExp(r'_{3,}');
  static final _checkboxGlyph = RegExp(r'^[□☐\[\]()oO○]+$');

  // How wide a bbox must be (relative to page width) to be a text-input line
  static const _minTextFieldWidthRatio = 0.15;
  // Max height ratio for a text-input line
  static const _maxTextFieldHeightRatio = 0.035;
  // A checkbox is roughly square and small
  static const _maxCheckboxWidthRatio = 0.06;
  static const _maxCheckboxHeightRatio = 0.04;

  List<DetectedField> detect(OcrResult ocr) {
    final W = ocr.imageWidth.toDouble();
    final H = ocr.imageHeight.toDouble();
    if (W == 0 || H == 0) return [];

    final results = <DetectedField>[];
    final seen = <Rect>{}; // dedup overlapping detections

    for (final block in ocr.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final box = line.boundingBox;
        if (box.width <= 0 || box.height <= 0) continue;

        final wRatio = box.width / W;
        final hRatio = box.height / H;
        final aspectRatio = box.width / box.height;

        // ── 1. Signature ─────────────────────────────────────────────────────
        if (_sigRe.hasMatch(text)) {
          final field = _makeField(FieldType.signature, box, W, H, text);
          if (_notSeen(seen, box)) {
            results.add(field);
            seen.add(box);
          }
          continue;
        }

        // ── 2. Date ───────────────────────────────────────────────────────────
        if (_dateRe.hasMatch(text)) {
          // Treat the blank to the right of the label as the date field
          final fieldBox = _rightOf(box, W, H);
          if (_notSeen(seen, fieldBox)) {
            results.add(DetectedField(
              type: FieldType.date,
              bbox: _norm(fieldBox, W, H),
              label: text,
            ));
            seen.add(fieldBox);
          }
          continue;
        }

        // ── 3. Checkbox ──────────────────────────────────────────────────────
        if (_checkboxGlyph.hasMatch(text) ||
            (wRatio < _maxCheckboxWidthRatio &&
                hRatio < _maxCheckboxHeightRatio &&
                aspectRatio < 2.5 &&
                aspectRatio > 0.4)) {
          if (_notSeen(seen, box)) {
            results.add(_makeField(FieldType.checkbox, box, W, H, ''));
            seen.add(box);
          }
          continue;
        }

        // ── 4. Underscore / blank line → text field ───────────────────────────
        if (_underscoreRe.hasMatch(text) ||
            (wRatio >= _minTextFieldWidthRatio &&
                hRatio <= _maxTextFieldHeightRatio &&
                aspectRatio > 6)) {
          if (_notSeen(seen, box)) {
            // Look for a nearby label above/left to annotate the field
            final label = _nearbyLabel(line.text, ocr, box);
            results.add(_makeField(FieldType.text, box, W, H, label));
            seen.add(box);
          }
          continue;
        }
      }
    }

    return _mergeOverlapping(results);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  DetectedField _makeField(
      FieldType type, Rect box, double W, double H, String label) {
    return DetectedField(
      type: type,
      bbox: _norm(box, W, H),
      label: label,
    );
  }

  BoundingBox _norm(Rect box, double W, double H) => BoundingBox(
        x: (box.left / W).clamp(0.0, 1.0),
        y: (box.top / H).clamp(0.0, 1.0),
        w: (box.width / W).clamp(0.001, 1.0),
        h: (box.height / H).clamp(0.001, 1.0),
      );

  /// Synthesise a box to the right of a label (date / blank after colon).
  Rect _rightOf(Rect label, double W, double H) {
    final left = label.right + label.height * 0.5;
    final top = label.top;
    final width = math.min(W * 0.35, W - left - 4);
    final height = label.height;
    return Rect.fromLTWH(left, top, width, height);
  }

  bool _notSeen(Set<Rect> seen, Rect box) {
    for (final s in seen) {
      if (_iou(s, box) > 0.3) return false;
    }
    return true;
  }

  double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.isEmpty) return 0;
    final interArea = inter.width * inter.height;
    final unionArea =
        a.width * a.height + b.width * b.height - interArea;
    return unionArea > 0 ? interArea / unionArea : 0;
  }

  /// Find the closest preceding line in the same block that reads like a label
  /// (short, ends with colon or is a known keyword).
  String _nearbyLabel(String lineText, OcrResult ocr, Rect box) {
    // Already have text — if it's not an underscore-only line, use it
    if (!_underscoreRe.hasMatch(lineText.trim())) return lineText.trim();

    String best = '';
    double bestDist = double.infinity;
    for (final block in ocr.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isEmpty || _underscoreRe.hasMatch(t)) continue;
        final lb = line.boundingBox;
        // Label must be above or to the left of the field box
        final isAbove = lb.bottom <= box.top + box.height * 0.5;
        final isLeft = lb.right <= box.left + box.width * 0.2;
        if (!isAbove && !isLeft) continue;
        final dist = (lb.center - box.center).distance;
        if (dist < bestDist && dist < box.height * 10) {
          bestDist = dist;
          best = t.endsWith(':') ? t.substring(0, t.length - 1).trim() : t;
        }
      }
    }
    return best;
  }

  /// Merge overlapping detections (IOU > 0.5) — keep the higher-priority type.
  List<DetectedField> _mergeOverlapping(List<DetectedField> fields) {
    final priority = {
      FieldType.signature: 0,
      FieldType.date: 1,
      FieldType.checkbox: 2,
      FieldType.text: 3,
    };
    final out = <DetectedField>[];
    final used = List.filled(fields.length, false);

    for (var i = 0; i < fields.length; i++) {
      if (used[i]) continue;
      var best = fields[i];
      for (var j = i + 1; j < fields.length; j++) {
        if (used[j]) continue;
        final bboxA = fields[i].bbox;
        final bboxB = fields[j].bbox;
        final rectA = Rect.fromLTWH(bboxA.x, bboxA.y, bboxA.w, bboxA.h);
        final rectB = Rect.fromLTWH(bboxB.x, bboxB.y, bboxB.w, bboxB.h);
        if (_iou(rectA, rectB) > 0.5) {
          used[j] = true;
          if ((priority[fields[j].type] ?? 99) <
              (priority[best.type] ?? 99)) {
            best = fields[j];
          }
        }
      }
      out.add(best);
    }
    return out;
  }
}
