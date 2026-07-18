import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/signature_repository.dart';

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
                    minimumStrokeWidth: 1.5,
                    maximumStrokeWidth: 3.5,
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
      // Capture the pad as PNG via RepaintBoundary
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _saving = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _saving = false);
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();

      // Persist to disk
      final dir = await getApplicationDocumentsDirectory();
      final sigDir = Directory(p.join(dir.path, 'signatures'));
      await sigDir.create(recursive: true);
      final sigPath = p.join(sigDir.path, '${const Uuid().v4()}.png');
      await File(sigPath).writeAsBytes(pngBytes);

      // Save to Signatures table
      final sigRepo = ref.read(signatureRepositoryProvider);
      final sigId = await sigRepo.addSignature(
        imagePath: sigPath,
        label: 'My Signature',
        isDefault: _saveAsDefault,
      );

      // Link to the Field row (fieldId=0 means save-only from manager)
      if (widget.fieldId != 0) {
        await ref.read(fieldRepositoryProvider).updateField(
              FieldsCompanion(
                id: Value(widget.fieldId),
                value: Value(sigPath),
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
}
