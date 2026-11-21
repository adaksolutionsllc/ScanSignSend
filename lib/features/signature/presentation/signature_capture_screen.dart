import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/services/signature_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/l10n_ext.dart';

class SignatureCaptureScreen extends ConsumerStatefulWidget {
  const SignatureCaptureScreen({
    super.key,
    required this.docId,
    required this.fieldId,
    this.initials = false,
  });
  final int docId;
  final int fieldId;

  /// Capturing initials rather than a full signature: different title, and
  /// the result is saved as initials in the signatures library.
  final bool initials;

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

  /// Type instead of draw: the name is set in a handwriting font and saved
  /// as the same transparent PNG a drawing makes. It's also the way to sign
  /// with a screen reader or switch control, where drawing isn't possible.
  bool _typing = false;
  final _typed = TextEditingController();
  final _typedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Start from the name in My Details (or its initials).
    ref.read(profileRepositoryProvider).getOrCreate().then((p) {
      final words = [p.firstName, p.middleName, p.lastName]
          .expand((w) => w.trim().split(RegExp(r'\s+')))
          .where((w) => w.isNotEmpty)
          .toList();
      if (!mounted || words.isEmpty || _typed.text.isNotEmpty) return;
      setState(() {
        _typed.text = widget.initials
            ? words.map((w) => w.characters.first.toUpperCase()).join()
            : words.join(' ');
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initials
              ? context.l10n.signInitialsTitle
              : context.l10n.signTitle,
        ),
        actions: [
          // Ink colour toggle
          IconButton(
            icon: Icon(
              Icons.circle,
              color: _inkColor == Colors.black
                  ? Colors.black
                  : const Color(0xFF0D47A1),
            ),
            tooltip: context.l10n.signSwitchInk,
            onPressed: () => setState(() {
              _inkColor = _inkColor == Colors.black
                  ? const Color(0xFF0D47A1)
                  : Colors.black;
            }),
          ),
          TextButton(
            onPressed: () => _typing
                ? setState(_typed.clear)
                : _padKey.currentState?.clear(),
            child: Text(context.l10n.actionClear),
          ),
        ],
      ),
      // Android draws edge to edge: keep the button clear of the nav bar.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.gesture),
                    label: Text(context.l10n.signModeDraw),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.keyboard_outlined),
                    label: Text(context.l10n.signModeType),
                  ),
                ],
                selected: {_typing},
                onSelectionChanged: (v) => setState(() => _typing = v.first),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _typing ? _typeArea(context) : _drawArea(),
              ),
            ),
            // Save-as-default toggle
            SwitchListTile(
              title: Text(context.l10n.signSaveAsMine),
              subtitle: Text(context.l10n.signReuseSubtitle),
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
                  onPressed: _saving || (_typing && _typed.text.trim().isEmpty)
                      ? null
                      : _onSave,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _saving
                        ? context.l10n.signSaving
                        : context.l10n.signUseThis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawArea() => RepaintBoundary(
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
  );

  Widget _typeArea(BuildContext context) => Column(
    children: [
      TextField(
        key: const ValueKey('typed-signature'),
        controller: _typed,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: widget.initials
              ? context.l10n.signTypeInitialsHint
              : context.l10n.signTypeHint,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      // What gets saved: the name in the handwriting font, on white (the
      // white is made transparent on save, as for a drawing). Names in
      // Devanagari, Tamil or Telugu fall back to the system font for that
      // script — not cursive, but correct.
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: RepaintBoundary(
            key: _typedKey,
            child: ColoredBox(
              color: Colors.white,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _typed.text.trim(),
                  style: TextStyle(
                    fontFamily: 'DancingScript',
                    fontSize: 72,
                    color: _inkColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  /// A PNG of what's on screen: the drawing, or the typed name.
  Future<Uint8List?> _capture() async {
    final ui.Image rendered;
    if (_typing) {
      final boundary =
          _typedKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      rendered = await boundary.toImage(pixelRatio: 3.0);
    } else {
      final padState = _padKey.currentState;
      if (padState == null) return null;
      rendered = await padState.toImage(pixelRatio: 3.0);
    }
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    // Resolve before any await — `context` is unsafe past an async gap.
    final l10n = context.l10n;
    // Today's date in the user's format, for the date fields that go with
    // this signature (resolved now: `context` is unsafe after the awaits).
    final today = DateFormat(
      l10n.dateFormatInput,
      Localizations.localeOf(context).toString(),
    ).format(DateTime.now());
    try {
      // Capture at high resolution, then crop to the ink's bounding box and
      // knock out the white background so the signature fills its field on
      // the document instead of being a tiny mark on a big white canvas.
      final rawPng = await _capture();
      if (rawPng == null) {
        setState(() => _saving = false);
        return;
      }
      final pngBytes = await compute(_cropAndMakeTransparent, rawPng) ?? rawPng;
      if (pngBytes.isEmpty) {
        // Empty pad — nothing drawn.
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.signDrawFirst)));
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
        label: widget.initials ? l10n.fieldTypeInitials : l10n.signDefaultLabel,
        isDefault: _saveAsDefault,
        isInitials: widget.initials,
      );

      // Link to the Field row (fieldId=0 means save-only from manager)
      if (widget.fieldId != 0) {
        await ref
            .read(fieldRepositoryProvider)
            .updateField(
              FieldsCompanion(
                id: Value(widget.fieldId),
                value: Value(storablePath),
                signatureId: Value(sigId),
                isFilled: const Value(true),
              ),
            );
        // Signing dates the page: fill its signature-linked date fields.
        await ref
            .read(fieldRepositoryProvider)
            .fillTodayDatesFor(widget.fieldId, today);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.signSaveFailed('$e'))),
        );
      }
    }
  }
}

/// compute() entry — a per-pixel pass over a 3× capture, too slow for the UI
/// thread. Crops [rawPng] to the ink's bounding box and makes near-white pixels
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
      final isInk =
          px.r < whiteThreshold ||
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

  final cropped = img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

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
