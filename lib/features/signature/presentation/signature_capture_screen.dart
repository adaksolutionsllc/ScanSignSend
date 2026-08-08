import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/signature_repository.dart';
import '../../../core/utils/path_resolver.dart';

class SignatureCaptureScreen extends ConsumerStatefulWidget {
  const SignatureCaptureScreen({
    super.key,
    required this.docId,
    required this.fieldId,
  });
  final int docId;
  final int fieldId;

  @override
  ConsumerState<SignatureCaptureScreen> createState() =>
      _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState
    extends ConsumerState<SignatureCaptureScreen> {
  final _padKey = GlobalKey<SfSignaturePadState>();
  final _repaintKey = GlobalKey();
  bool _saveAsDefault = true;
  bool _saving = false;
  Color _inkColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Here'),
        actions: [
          // Ink colour toggle
          IconButton(
            icon: Icon(Icons.circle,
                color: _inkColor == Colors.black
                    ? Colors.black
                    : const Color(0xFF0D47A1)),
            tooltip: 'Switch ink colour',
            onPressed: () => setState(() {
              _inkColor = _inkColor == Colors.black
                  ? const Color(0xFF0D47A1)
                  : Colors.black;
            }),
          ),
          TextButton(
            onPressed: () => _padKey.currentState?.clear(),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Draw canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SfSignaturePad(
                    key: _padKey,
                    backgroundColor: Colors.white,
                    strokeColor: _inkColor,
                    minimumStrokeWidth: 3.0,
                    maximumStrokeWidth: 7.0,
                  ),
                ),
              ),
            ),
          ),
          // Save-as-default toggle
          SwitchListTile(
            title: const Text('Save as my signature'),
            subtitle: const Text('Reuse across future documents'),
            value: _saveAsDefault,
            onChanged: (v) => setState(() => _saveAsDefault = v),
          ),
          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _onSave,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label:
                    Text(_saving ? 'Saving…' : 'Use This Signature'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    try {
      // Capture the pad directly (high-res), then crop to the ink's bounding box
      // and knock out the white background so the signature fills its field on
      // the document instead of being a tiny mark on a big white canvas.
      final padState = _padKey.currentState;
      if (padState == null) {
        setState(() => _saving = false);
        return;
      }
      final ui.Image rendered = await padState.toImage(pixelRatio: 3.0);
      final byteData =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _saving = false);
        return;
      }
      final rawPng = byteData.buffer.asUint8List();
      final pngBytes = _cropAndMakeTransparent(rawPng) ?? rawPng;
      if (pngBytes.isEmpty) {
        // Empty pad — nothing drawn.
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please draw your signature first.')),
          );
        }
        return;
      }

      // Persist to disk
      final dir = await getApplicationDocumentsDirectory();
      final sigDir = Directory(p.join(dir.path, 'signatures'));
      await sigDir.create(recursive: true);
      final sigPath = p.join(sigDir.path, '${const Uuid().v4()}.png');
      await File(sigPath).writeAsBytes(pngBytes);
      // Persist container-relative so it survives reinstalls (see PathResolver).
      final storablePath = PathResolver.toStorable(sigPath);

      // Save to Signatures table
      final sigRepo = ref.read(signatureRepositoryProvider);
      final sigId = await sigRepo.addSignature(
        imagePath: storablePath,
        label: 'My Signature',
        isDefault: _saveAsDefault,
      );

      // Link to the Field row (fieldId=0 means save-only from manager)
      if (widget.fieldId != 0) {
        await ref.read(fieldRepositoryProvider).updateField(
              FieldsCompanion(
                id: Value(widget.fieldId),
                value: Value(storablePath),
                signatureId: Value(sigId),
                isFilled: const Value(true),
              ),
            );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save signature: $e')),
        );
      }
    }
  }

  /// Crops [rawPng] to the ink's bounding box and makes near-white pixels
  /// transparent, so the signature fills its field on the document (no big white
  /// margin) and composites cleanly onto the page. Returns null on decode
  /// failure; an empty list if the pad had no ink.
  Uint8List? _cropAndMakeTransparent(Uint8List rawPng) {
    final src = img.decodeImage(rawPng);
    if (src == null) return null;

    const int whiteThreshold = 235; // pixels this bright count as background
    int minX = src.width, minY = src.height, maxX = -1, maxY = -1;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final isInk = px.r < whiteThreshold ||
            px.g < whiteThreshold ||
            px.b < whiteThreshold;
        if (isInk) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return Uint8List(0); // nothing drawn

    // Pad the crop slightly so strokes aren't clipped at the edge.
    const pad = 12;
    minX = (minX - pad).clamp(0, src.width - 1);
    minY = (minY - pad).clamp(0, src.height - 1);
    maxX = (maxX + pad).clamp(0, src.width - 1);
    maxY = (maxY + pad).clamp(0, src.height - 1);

    final cropped = img.copyCrop(src,
        x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);

    // Knock out the white background → transparent.
    final out = cropped.convert(numChannels: 4);
    for (final px in out) {
      if (px.r >= whiteThreshold &&
          px.g >= whiteThreshold &&
          px.b >= whiteThreshold) {
        px.a = 0;
      }
    }
    return Uint8List.fromList(img.encodePng(out));
  }
}
