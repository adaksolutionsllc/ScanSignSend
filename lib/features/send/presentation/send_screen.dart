import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/services/app_lock_provider.dart';
import '../../../core/services/review_prompt_service.dart';
import '../../../core/services/fillable_form_export_service.dart';
import '../../../core/services/pdf_password_service.dart';
import '../../../core/services/press_service.dart';
import '../../../core/services/send_formats_service.dart';
import '../../../core/services/text_export.dart';
import '../../../shared/utils/file_size.dart';
import '../../../shared/utils/share_pdf.dart';
import '../../../core/services/template_service.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  bool _sharing = false;
  bool _shared = false;

  /// Set once the form has been saved as a template, so it's saved once.
  bool _templateSaved = false;

  Future<void> _saveTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.sendTemplateSaved;
    setState(() => _templateSaved = true);
    try {
      await ref.read(templateServiceProvider).createTemplate(widget.docId);
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    } catch (_) {
      if (mounted) setState(() => _templateSaved = false);
    }
  }

  // Fetch the doc once. Toggling _sharing/_shared calls setState; a fresh
  // getById() future per build would reload and can flicker.
  late final Future<Document?> _docFuture = ref
      .read(documentRepositoryProvider)
      .getById(widget.docId);

  // A template is a form to fill again; a document without fields (a scan
  // saved as it is) has nothing to reuse, so it isn't offered.
  late final Future<bool> _hasFields = ref
      .read(fieldRepositoryProvider)
      .watchFields(widget.docId)
      .first
      .then((f) => f.isNotEmpty);

  // Only photos shrink: a document of imported PDF pages has nothing to gain.
  late final Future<bool> _canShrink = ref
      .read(pageRepositoryProvider)
      .pagesOf(widget.docId)
      .then((pages) => pages.any((pg) => !pg.imagePath.contains('#page=')));

  /// Send → "Smaller file": on, and the copy once it's made.
  bool _smaller = false;
  bool _makingSmaller = false;
  String? _smallerPath;

  /// (original, smaller) sizes in bytes, once the copy is made.
  (int, int)? _sizes;

  /// A smaller copy that saved too little to be worth sending instead.
  bool _alreadySmall = false;

  /// Makes the smaller copy the first time the switch is turned on. A
  /// completed document is re-pressed (same certificate date); a fillable
  /// one, or one saved without fields, is exported again.
  Future<void> _toggleSmaller(bool on, Document doc, String pdfPath) async {
    setState(() => _smaller = on);
    if (!on || _smallerPath != null || _makingSmaller) return;
    final l10n = context.l10n;
    final cert = PressCertificateStrings(
      title: l10n.certTitle,
      documentLabel: l10n.certDocument,
      signedOnLabel: l10n.certSignedOn,
      methodLabel: l10n.certMethod,
      methodValue: l10n.certMethodValue,
      noteLabel: l10n.certNote,
      noteValue: l10n.certNoteValue,
      dateFormat: l10n.certDateFormat,
      localeName: Localizations.localeOf(context).toString(),
    );
    final pressed = doc.pressedPdfPath;
    final viaPress = pressed != null && pressed != doc.fillablePdfPath;
    final press = ref.read(pressServiceProvider);
    final fillable = ref.read(fillableFormExportServiceProvider);
    setState(() => _makingSmaller = true);
    try {
      final copy = viaPress
          ? await press.smallerCopy(widget.docId, cert)
          : await fillable.smallerCopy(widget.docId);
      final before = File(pdfPath).lengthSync();
      final after = File(copy).lengthSync();
      if (!mounted) return;
      setState(() {
        _sizes = (before, after);
        // Under a tenth smaller isn't worth a blurrier file.
        _alreadySmall = after > before * 0.9;
        if (_alreadySmall) {
          _smaller = false;
        } else {
          _smallerPath = copy;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _smaller = false);
    } finally {
      if (mounted) setState(() => _makingSmaller = false);
    }
  }

  /// Send → "Password-protect": the password, kept in memory only while
  /// this screen is open; null when off.
  String? _password;

  /// Whether this document's PDF can be password-protected here (on iOS,
  /// not a fillable form with radio buttons; see PdfPasswordService).
  Future<bool>? _canProtect;
  Future<bool> _canProtectFor(Document doc) => _canProtect ??= ref
      .read(fieldRepositoryProvider)
      .watchFields(widget.docId)
      .first
      .then((fields) {
        final pressed = doc.pressedPdfPath;
        final flattened = pressed != null && pressed != doc.fillablePdfPath;
        return ref
            .read(pdfPasswordServiceProvider)
            .canProtect(
              fillable: !flattened,
              hasRadios: fields.any((f) => f.type == 'radio'),
            );
      });

  Future<void> _togglePassword(bool on) async {
    if (!on) {
      setState(() => _password = null);
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password != null && mounted) setState(() => _password = password);
  }

  Widget _passwordSwitch(BuildContext context) {
    final l10n = context.l10n;
    return SwitchListTile(
      key: const ValueKey('password-protect'),
      contentPadding: EdgeInsets.zero,
      secondary: Icon(_password == null ? Icons.lock_open : Icons.lock),
      title: Text(l10n.sendPasswordProtect),
      subtitle: Text(
        _password == null ? l10n.sendPasswordOffHint : l10n.sendPasswordOnHint,
      ),
      value: _password != null,
      onChanged: _sharing ? null : _togglePassword,
    );
  }

  /// Send → Format. Smaller file and Password-protect are PDF options.
  SendFormat _format = SendFormat.pdf;

  /// The file Share sends: the smaller copy when chosen and ready.
  String _toShare(String pdfPath) =>
      _smaller && _smallerPath != null && _format == SendFormat.pdf
      ? _smallerPath!
      : pdfPath;

  Widget _smallerSwitch(BuildContext context, Document doc, String pdfPath) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final sizes = _sizes;
    final subtitle = _makingSmaller
        ? l10n.sendMakingSmaller
        : _alreadySmall
        ? l10n.sendAlreadySmall
        : sizes != null
        ? l10n.sendSizeChange(
            formatFileSize(sizes.$1, locale),
            formatFileSize(sizes.$2, locale),
          )
        : l10n.sendSmallerFileHint;
    return SwitchListTile(
      key: const ValueKey('smaller-file'),
      contentPadding: EdgeInsets.zero,
      secondary: _makingSmaller
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.compress),
      title: Text(l10n.sendSmallerFile),
      subtitle: Text(subtitle),
      value: _smaller,
      onChanged: _makingSmaller || _alreadySmall || _sharing
          ? null
          : (on) => _toggleSmaller(on, doc, pdfPath),
    );
  }

  /// Send → Format: PDF, Images, Text or Word, with what the chosen one
  /// holds.
  Widget _formatChoice(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hint = switch (_format) {
      SendFormat.pdf => null,
      SendFormat.images => l10n.sendFormatImagesHint,
      SendFormat.text || SendFormat.word => l10n.sendFormatTextHint,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sendFormat, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final f in SendFormat.values)
                ChoiceChip(
                  key: ValueKey('format-${f.name}'),
                  label: Text(switch (f) {
                    SendFormat.pdf => l10n.sendFormatPdf,
                    SendFormat.images => l10n.sendFormatImages,
                    SendFormat.text => l10n.sendFormatText,
                    SendFormat.word => l10n.sendFormatWord,
                  }),
                  selected: _format == f,
                  onSelected: _sharing
                      ? null
                      : (_) => setState(() => _format = f),
                ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _shareLabel(AppLocalizations l10n) => switch (_format) {
    SendFormat.pdf => l10n.sendSharePressed,
    SendFormat.images => l10n.sendShareImages,
    SendFormat.text => l10n.sendShareText,
    SendFormat.word => l10n.sendShareWord,
  };

  /// The files for Send → Images, Text or Word, named after the document.
  static Future<List<(String, String)>> _otherFiles(
    SendFormatsService service,
    SendFormat format, {
    required int docId,
    required String pdfPath,
    required String title,
    required AppLocalizations l10n,
  }) async {
    final dir = await shareDir();
    final name =
        safeFileName(title) ?? safeFileName(l10n.documentFallbackTitle)!;
    switch (format) {
      case SendFormat.images:
        return [
          for (final f in await service.pageImages(pdfPath, dir, name))
            (f, 'image/jpeg'),
        ];
      case SendFormat.text || SendFormat.word:
        final pages = await service.textPages(docId);
        if (pages.every((pg) => pg.isEmpty)) throw const _NoText();
        if (format == SendFormat.text) {
          final file = File(p.join(dir.path, '$name.txt'));
          await file.writeAsString(buildTxt(pages, l10n.textPageN));
          return [(file.path, 'text/plain')];
        }
        final file = File(p.join(dir.path, '$name.docx'));
        await file.writeAsBytes(buildDocx(title, pages, l10n.textPageN));
        return [
          (
            file.path,
            'application/vnd.openxmlformats-officedocument.'
                'wordprocessingml.document',
          ),
        ];
      case SendFormat.pdf:
        throw StateError('PDF is shared as it is');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The document is already pressed and saved before we reach this screen,
    // so never trap the user here — back always returns to the Library.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.library);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.sendTitle),
          leading: IconButton(
            icon: Icon(_shared ? Icons.check : Icons.arrow_back),
            tooltip: context.l10n.sendBackToLibrary,
            onPressed: () => context.go(AppRoutes.library),
          ),
        ),
        body: FutureBuilder(
          future: _docFuture,
          builder: (context, snapshot) {
            final doc = snapshot.data;
            // Prefer the locked/flattened PDF; fall back to the fillable
            // export (this screen is reached from either "Flatten & Sign" or
            // "Save as Fillable").
            final storedPdf = doc?.pressedPdfPath ?? doc?.fillablePdfPath;
            final pdfPath = storedPdf == null
                ? null
                : PathResolver.resolve(storedPdf);

            // Scrolls when the options don't fit (a small phone, large
            // text); centred when they do.
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _shared
                          ? Icons.check_circle_outline
                          : Icons.send_outlined,
                      size: 80,
                      color: _shared ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _shared
                          ? context.l10n.sendDocumentSent
                          : context.l10n.sendReadyToSend,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shared
                          ? context.l10n.sendSharedBody
                          : context.l10n.sendReadyBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    if (!_shared && pdfPath != null) _formatChoice(context),

                    if (!_shared)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: (_sharing || pdfPath == null)
                              ? null
                              : () => _share(
                                  context,
                                  _toShare(pdfPath),
                                  doc?.title ??
                                      context.l10n.documentFallbackTitle,
                                ),
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _sharing
                                  ? context.l10n.sendOpeningShareSheet
                                  : _shareLabel(context.l10n),
                            ),
                          ),
                        ),
                      ),

                    if (!_shared &&
                        pdfPath != null &&
                        doc != null &&
                        _format == SendFormat.pdf)
                      FutureBuilder<bool>(
                        future: _canShrink,
                        builder: (context, can) => can.data == true
                            ? Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _smallerSwitch(context, doc, pdfPath),
                              )
                            : const SizedBox.shrink(),
                      ),

                    if (!_shared &&
                        pdfPath != null &&
                        doc != null &&
                        _format == SendFormat.pdf)
                      FutureBuilder<bool>(
                        future: _canProtectFor(doc),
                        builder: (context, can) => can.data == true
                            ? _passwordSwitch(context)
                            : const SizedBox.shrink(),
                      ),

                    if (!_shared && pdfPath != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.viewer.replaceAll(
                              ':docId',
                              '${widget.docId}',
                            ),
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(context.l10n.sendPreviewDocument),
                        ),
                      ),
                    ],

                    // Reuse this form next time: same pages and fields, empty.
                    if (pdfPath != null)
                      FutureBuilder<bool>(
                        future: _hasFields,
                        builder: (context, fields) {
                          if (fields.data != true) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TextButton.icon(
                                onPressed: _templateSaved
                                    ? null
                                    : _saveTemplate,
                                icon: Icon(
                                  _templateSaved
                                      ? Icons.check
                                      : Icons.layers_outlined,
                                ),
                                label: Text(
                                  _templateSaved
                                      ? context.l10n.sendTemplateSavedShort
                                      : context.l10n.sendSaveAsTemplate,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // Done here without sharing: straight to the Library.
                    if (!_shared) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton.icon(
                          onPressed: () => context.go(AppRoutes.library),
                          icon: const Icon(Icons.home_outlined),
                          label: Text(context.l10n.sendHome),
                        ),
                      ),
                    ],

                    if (_shared) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.library),
                          icon: const Icon(Icons.home),
                          label: Text(context.l10n.sendBackToLibrary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: pdfPath != null
                            ? () => _share(
                                context,
                                _toShare(pdfPath),
                                doc?.title ??
                                    context.l10n.documentFallbackTitle,
                              )
                            : null,
                        icon: const Icon(Icons.share),
                        label: Text(context.l10n.sendShareAgain),
                      ),
                    ],

                    if (pdfPath == null && !_sharing)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          context.l10n.sendNotYetPressed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    String pdfPath,
    String title,
  ) async {
    if (!File(pdfPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sendPressedPdfNotFound)),
      );
      return;
    }
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    // iPad (and iOS in general) requires a non-zero source rect to anchor the
    // share popover; without it share_plus throws a PlatformException.
    // Resolve strings before the await — `context` is unsafe past the gap.
    final l10n = context.l10n;
    // Read before the await too: `ref` is unusable once the screen is gone.
    final reviews = ref.read(reviewPromptServiceProvider);
    final lock = ref.read(appLockProvider.notifier);
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    if (_format != SendFormat.pdf) {
      final service = ref.read(sendFormatsServiceProvider);
      try {
        final files = await _otherFiles(
          service,
          _format,
          docId: widget.docId,
          pdfPath: pdfPath,
          title: title,
          l10n: l10n,
        );
        final sent = await shareDocumentFiles(
          lock: lock,
          files: files,
          title: title,
          origin: origin,
        );
        if (sent && !_shared) unawaited(_afterSend(reviews));
        if (mounted) {
          setState(() {
            _sharing = false;
            _shared = _shared || sent;
          });
        }
      } on _NoText {
        if (mounted) setState(() => _sharing = false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.sendNoText)));
      } catch (e) {
        if (mounted) setState(() => _sharing = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sendShareFailed('$e'))),
        );
      }
      return;
    }
    // The password-protected copy is made at share time, from the chosen
    // file (the smaller copy, when that's on).
    var toSend = pdfPath;
    final password = _password;
    if (password != null) {
      try {
        toSend = await ref
            .read(pdfPasswordServiceProvider)
            .protect(pdfPath, password);
      } catch (_) {
        if (mounted) setState(() => _sharing = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sendPasswordFailed)),
        );
        return;
      }
    }
    try {
      final sent = await shareDocumentPdf(
        lock: lock,
        pdfPath: toSend,
        title: title,
        message: l10n.sendShareMessage,
        origin: origin,
      );
      // Only "sent" if it was: dismissing the share sheet isn't sending.
      // "Share again" on the same document doesn't count as another send.
      if (sent && !_shared) unawaited(_afterSend(reviews));
      if (mounted) {
        setState(() {
          _sharing = false;
          _shared = _shared || sent;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sharing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sendShareFailed('$e'))),
      );
    }
  }

  /// Counts the send and, when it's time, asks for a store rating.
  Future<void> _afterSend(ReviewPromptService reviews) async {
    if (!await reviews.recordSend()) return;
    // Let the share sheet finish closing so the rating sheet doesn't cover it.
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    // Only over this screen, in the foreground: never over the lock screen,
    // the paywall, a dialog or anything else the user has moved on to.
    if (ref.read(appLockProvider)) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await reviews.requestReview();
  }
}

/// Asks for the password twice, with the rules and the warning that it
/// can't be recovered. Pops with the password, or null when cancelled.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final a = _first.text, b = _second.text;
    setState(() {
      _error = a.length < PdfPasswordService.minLength
          ? l10n.passwordTooShort(PdfPasswordService.minLength)
          : a != b
          ? l10n.passwordMismatch
          : null;
    });
    if (_error == null) Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.passwordDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('password-1'),
              controller: _first,
              obscureText: true,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.passwordField),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('password-2'),
              controller: _second,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.passwordConfirm,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.passwordNoRecovery,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('password-set'),
          onPressed: _submit,
          child: Text(l10n.passwordSet),
        ),
      ],
    );
  }
}

/// Text or Word was chosen, and no page has text or filled-in values.
class _NoText implements Exception {
  const _NoText();
}
