import 'dart:math' as math;

import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_model.dart';
import 'ocr_service.dart';

final fieldDetectionEngineProvider =
    Provider<FieldDetectionEngine>((ref) => FieldDetectionEngine());

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

/// Conservative heuristic classifier — prefers false negatives over false
/// positives. Users can always add fields manually.
///
/// Rules (applied in priority order):
///   1. Signature  — line text exactly matches known signature keywords
///   2. Date       — line text is exactly "Date:" or "Date" with nothing else
///   3. Checkbox   — explicit glyph only (□ ☐), not shape heuristics
///   4. Text field — underscore sequences only (___+), never plain text lines
///
/// Additional guards:
///   - Candidate bbox must not substantially overlap any OCR text block
///   - Total output capped at 8 fields
class FieldDetectionEngine {
  static final _sigRe = RegExp(
      r'^(x\s*)?(signature|sign\s*here|initial[s]?|authorized\s*by|signed\s*by)\s*[:\-_]?\s*$',
      caseSensitive: false);

  static final _dateRe =
      RegExp(r'^date\s*[:\-]?\s*$', caseSensitive: false);

  static final _underscoreRe = RegExp(r'_{4,}');

  // Only explicit box glyphs — no shape heuristics
  static final _checkboxGlyph = RegExp(r'^[□☐]\s*$');

  static const _maxFields = 8;

  // A detected field bbox must not overlap more than this fraction of any
  // existing OCR text block (avoids placing fields over printed text).
  static const _maxOverlapWithText = 0.25;

  List<DetectedField> detect(OcrResult ocr) {
    final W = ocr.imageWidth.toDouble();
    final H = ocr.imageHeight.toDouble();
    if (W == 0 || H == 0) return [];

    // Collect all OCR text rects for overlap checking
    final textRects = <Rect>[];
    for (final block in ocr.blocks) {
      for (final line in block.lines) {
        if (line.boundingBox.width > 0 && line.boundingBox.height > 0) {
          textRects.add(line.boundingBox);
        }
      }
    }

    final results = <DetectedField>[];
    final seen = <Rect>{};

    for (final block in ocr.blocks) {
      for (final line in block.lines) {
        if (results.length >= _maxFields) break;

        final text = line.text.trim();
        final box = line.boundingBox;
        if (box.width <= 0 || box.height <= 0) continue;

        // ── 1. Signature ────────────────────────────────────────────────────
        if (_sigRe.hasMatch(text)) {
          final fieldBox = _rightOrBelow(box, W, H);
          if (_notSeen(seen, fieldBox) &&
              !_overlapsText(fieldBox, textRects, box)) {
            results.add(DetectedField(
              type: FieldType.signature,
              bbox: _norm(fieldBox, W, H),
              label: text,
            ));
            seen.add(fieldBox);
          }
          continue;
        }

        // ── 2. Date ─────────────────────────────────────────────────────────
        if (_dateRe.hasMatch(text)) {
          final fieldBox = _rightOf(box, W, H);
          if (_notSeen(seen, fieldBox) &&
              !_overlapsText(fieldBox, textRects, box)) {
            results.add(DetectedField(
              type: FieldType.date,
              bbox: _norm(fieldBox, W, H),
              // No synthetic label: a stored English word would show
              // untranslated forever. The UI names untitled fields by type.
              label: '',
            ));
            seen.add(fieldBox);
          }
          continue;
        }

        // ── 3. Checkbox glyph ───────────────────────────────────────────────
        if (_checkboxGlyph.hasMatch(text)) {
          if (_notSeen(seen, box)) {
            results.add(DetectedField(
              type: FieldType.checkbox,
              bbox: _norm(box, W, H),
              label: '',
            ));
            seen.add(box);
          }
          continue;
        }

        // ── 4. Underscore blank line → text field ───────────────────────────
        // Only trigger on lines that are *entirely* underscores — this is a
        // deliberate blank fill-in line on the form.
        if (_underscoreRe.hasMatch(text) &&
            text.replaceAll('_', '').replaceAll(' ', '').isEmpty) {
          if (_notSeen(seen, box) &&
              !_overlapsText(box, textRects, box)) {
            final label = _nearbyLabel(ocr, box);
            results.add(DetectedField(
              type: FieldType.text,
              bbox: _norm(box, W, H),
              label: label,
            ));
            seen.add(box);
          }
          continue;
        }
      }
    }

    return results;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  BoundingBox _norm(Rect box, double W, double H) => BoundingBox(
        x: (box.left / W).clamp(0.0, 1.0),
        y: (box.top / H).clamp(0.0, 1.0),
        w: (box.width / W).clamp(0.001, 1.0),
        h: (box.height / H).clamp(0.001, 1.0),
      );

  /// Box to the right of a label (for date / name fields).
  Rect _rightOf(Rect label, double W, double H) {
    final left = label.right + label.height * 0.3;
    final width = math.min(W * 0.3, W - left - 4);
    if (width < 20) return label; // no space to the right
    return Rect.fromLTWH(left, label.top, width, label.height);
  }

  /// For signature: prefer space below the label, fall back to right.
  Rect _rightOrBelow(Rect label, double W, double H) {
    final below = Rect.fromLTWH(
      label.left,
      label.bottom + 2,
      math.min(W * 0.5, label.width * 1.5),
      label.height * 2.5,
    );
    return below;
  }

  bool _notSeen(Set<Rect> seen, Rect box) {
    for (final s in seen) {
      if (_iou(s, box) > 0.3) return false;
    }
    return true;
  }

  /// Returns true if [candidate] overlaps significantly with any text rect
  /// other than [exclude] (the source line itself).
  bool _overlapsText(Rect candidate, List<Rect> textRects, Rect exclude) {
    for (final tr in textRects) {
      if (tr == exclude) continue;
      final inter = candidate.intersect(tr);
      if (inter.isEmpty) continue;
      final interArea = inter.width * inter.height;
      final candidateArea = candidate.width * candidate.height;
      if (candidateArea > 0 && interArea / candidateArea > _maxOverlapWithText) {
        return true;
      }
    }
    return false;
  }

  double _iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.isEmpty) return 0;
    final interArea = inter.width * inter.height;
    final unionArea = a.width * a.height + b.width * b.height - interArea;
    return unionArea > 0 ? interArea / unionArea : 0;
  }

  String _nearbyLabel(OcrResult ocr, Rect box) {
    String best = '';
    double bestDist = double.infinity;
    for (final block in ocr.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isEmpty || _underscoreRe.hasMatch(t)) continue;
        final lb = line.boundingBox;
        final isAbove = lb.bottom <= box.top + box.height * 0.5;
        final isLeft = lb.right <= box.left + box.width * 0.2;
        if (!isAbove && !isLeft) continue;
        final dist = (lb.center - box.center).distance;
        if (dist < bestDist && dist < box.height * 8) {
          bestDist = dist;
          best = t.endsWith(':') ? t.substring(0, t.length - 1).trim() : t;
        }
      }
    }
    return best;
  }
}
