import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/models/my_details_ext.dart';
import '../../../core/services/prefill_matcher.dart';
import '../../../core/services/profile_repository.dart';
import '../../../core/utils/path_resolver.dart';
import '../../../core/utils/router.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/field_box.dart';
import '../../../shared/widgets/field_type_labels.dart';
import '../../../shared/widgets/page_canvas.dart';

class FillModeScreen extends ConsumerStatefulWidget {
  const FillModeScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<FillModeScreen> createState() => _FillModeScreenState();
}

class _FillModeScreenState extends ConsumerState<FillModeScreen> {
  int _currentPage = 0;

  // Streams are created ONCE here — not in build(). Rebuilding a StreamBuilder
  // with a freshly-allocated stream on every build re-subscribes each frame and
  // spins an infinite rebuild loop (the "flicker" seen when opening a doc).
  late final Stream<List<db.Page>> _pagesStream = ref
      .read(pageRepositoryProvider)
      .watchPages(widget.docId);
  late final Stream<List<db.Field>> _fieldsStream = ref
      .read(fieldRepositoryProvider)
      .watchFields(widget.docId);
  late final Stream<db.UserProfileData> _profileStream = ref
      .read(profileRepositoryProvider)
      .watch();

  // PreFill, for this visit to the form: fields it filled (tinted until the
  // user edits them), and whether its bars were closed.
  final Set<int> _prefilled = {};
  bool _offerClosed = false;
  bool _filling = false;
  bool _setupClosed = false;

  /// The latest PreFill state, for a field opened from Review & Finish.
  _Prefill? _lastPrefill;

  /// The same, for the bottom bar, which is built outside the streams that
  /// compute it. Set after each frame so the bar never lags behind.
  final _prefillNote = ValueNotifier<_Prefill?>(null);

  @override
  void dispose() {
    _prefillNote.dispose();
    super.dispose();
  }

  /// Documents that have already shown "Save your details once": the nudge
  /// appears at most once per document.
  static const _setupShownKey = 'prefill_setup_shown_docs';
  bool _setupShownBefore = true; // until read; avoids a flash

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final shown = prefs.getStringList(_setupShownKey) ?? const [];
      if (!mounted) return;
      setState(() => _setupShownBefore = shown.contains('${widget.docId}'));
      if (!shown.contains('${widget.docId}')) {
        prefs.setStringList(_setupShownKey, [...shown, '${widget.docId}']);
      }
    });
  }

  late final Stream<db.Document?> _docStream = ref
      .read(documentRepositoryProvider)
      .watchAll()
      .map(
        (docs) => docs.fold<db.Document?>(
          null,
          (found, d) => found ?? (d.id == widget.docId ? d : null),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<db.Document?>(
      stream: _docStream,
      builder: (context, docSnap) {
        final doc = docSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(doc?.title ?? context.l10n.fillFallbackTitle),
          ),
          // Primary next-step action: prominent, bottom-centre, always reachable.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              // Secondary "Edit fields" beside the primary "Review & Finish",
              // both labelled — the old app-bar icon wasn't readable. While
              // PreFill has fields to fill, its button sits between them.
              child: SizedBox(
                height: 52,
                child: ValueListenableBuilder<_Prefill?>(
                  valueListenable: _prefillNote,
                  builder: (context, prefill, _) {
                    final toFill =
                        prefill == null || prefill.details.isEmpty || _filling
                        ? 0
                        : prefill.toFill.length;
                    final narrow = toFill > 0;
                    return Row(
                      children: [
                        Flexible(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              padding: EdgeInsets.symmetric(
                                horizontal: narrow ? 12 : 16,
                              ),
                            ),
                            onPressed: () => context.push(
                              AppRoutes.fieldDetection.replaceAll(
                                ':docId',
                                '${widget.docId}',
                              ),
                            ),
                            icon: const Icon(Icons.edit_note),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(context.l10n.fillEditFields),
                            ),
                          ),
                        ),
                        if (toFill > 0) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: FilledButton.icon(
                              key: const ValueKey('prefill-fill-bottom'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                backgroundColor: Colors.teal.shade600,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _fillFromMyDetails(context, prefill!),
                              icon: Badge(
                                label: Text('$toFill'),
                                backgroundColor: Colors.white,
                                textColor: Colors.teal.shade800,
                                child: const Icon(Icons.auto_awesome),
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(context.l10n.prefillFill),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(width: narrow ? 8 : 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52),
                            ),
                            onPressed: () => _openReview(context),
                            icon: const Icon(Icons.task_alt),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(context.l10n.fillReviewAndFinish),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          body: StreamBuilder<List<db.Page>>(
            stream: _pagesStream,
            builder: (context, pagesSnap) {
              final pages = pagesSnap.data ?? [];
              if (pages.isEmpty) {
                if (pagesSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Doc has no pages (e.g. all deleted) — don't spin forever.
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      context.l10n.fillNoPages,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              // Keep the active page in range so field/page views never diverge.
              final safePage = _currentPage.clamp(0, pages.length - 1);
              final page = pages[safePage];

              return StreamBuilder<db.UserProfileData>(
                stream: _profileStream,
                builder: (context, profileSnap) => StreamBuilder<List<db.Field>>(
                  stream: _fieldsStream,
                  builder: (context, fieldsSnap) {
                    final allFields = fieldsSnap.data ?? [];
                    final pageFields = allFields
                        .where((f) => f.pageIndex == safePage)
                        .toList();
                    final prefill = _prefillFor(
                      context,
                      allFields,
                      profileSnap.data,
                    );

                    return Column(
                      children: [
                        // ── PreFill: offer, or set up My Details ──────────────
                        _prefillBar(context, prefill),
                        // ── Page image + overlay ──────────────────────────────
                        Expanded(
                          child: PageCanvas(
                            key: ValueKey(page.id),
                            storedPath: page.imagePath,
                            overlayBuilder: (context, pageRect) => [
                              for (final field in pageFields)
                                _fillFieldBox(
                                  context,
                                  field,
                                  pageRect,
                                  doc?.textSize,
                                  prefill: prefill,
                                  neighbours: [
                                    for (final other in pageFields)
                                      if (other.id != field.id)
                                        BoundingBox.fromJsonString(
                                          other.boundingBoxJson,
                                        ).inPageRect(pageRect),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        // ── Page picker ───────────────────────────────────────
                        if (pages.length > 1)
                          _PagePicker(
                            pageCount: pages.length,
                            currentIndex: safePage,
                            onSelect: (i) => setState(() => _currentPage = i),
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── PreFill ────────────────────────────────────────────────────────────────

  _Prefill _prefillFor(
    BuildContext context,
    List<db.Field> fields,
    db.UserProfileData? profile,
  ) {
    final forms = [
      for (final f in fields)
        PrefillField(id: f.id, label: f.label, type: f.type.toFieldType()),
    ];
    final slots = PrefillMatcher.matchForm(forms);
    final details = profile?.myDetails ?? const MyDetails();
    final dateFormat = DateFormat(
      context.l10n.dateFormatInput,
      Localizations.localeOf(context).toString(),
    );
    final values = <int, String>{};
    for (final id in slots.keys) {
      final v = PrefillMatcher.valueForField(
        forms,
        slots,
        id,
        details,
        dateFormat: dateFormat,
      );
      if (v != null) values[id] = v;
    }
    final empty = {
      for (final f in fields)
        if (!f.isFilled && !_prefilled.contains(f.id)) f.id,
    };
    final result = _Prefill(
      loaded: profile != null,
      details: details,
      dateFormat: dateFormat,
      values: values,
      toFill: [
        for (final f in fields)
          if (empty.contains(f.id) && values.containsKey(f.id)) f,
      ],
      anyMatch: slots.isNotEmpty,
    );
    _lastPrefill = result;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefillNote.value = result;
    });
    return result;
  }

  Widget _prefillBar(BuildContext context, _Prefill prefill) {
    if (!prefill.loaded) return const SizedBox.shrink();
    final l10n = context.l10n;
    if (prefill.details.isEmpty) {
      // Nothing saved yet: a gentle pointer to My Details, at most once per
      // document and only on a form PreFill could help with.
      if (_setupShownBefore || _setupClosed || !prefill.anyMatch) {
        return const SizedBox.shrink();
      }
      return _PrefillBanner(
        icon: Icons.badge_outlined,
        text: l10n.prefillSetup,
        action: l10n.prefillSetupAction,
        onAction: () => context.push(AppRoutes.myDetails),
        onClose: () => setState(() => _setupClosed = true),
      );
    }
    if (_offerClosed || _filling || prefill.toFill.isEmpty) {
      return const SizedBox.shrink();
    }
    return _PrefillBanner(
      key: const ValueKey('prefill-offer'),
      actionKey: const ValueKey('prefill-fill-bar'),
      emphasis: true,
      icon: Icons.auto_awesome,
      text: l10n.prefillOffer(prefill.toFill.length),
      action: l10n.prefillFill,
      onAction: () => _fillFromMyDetails(context, prefill),
      onClose: () => setState(() => _offerClosed = true),
    );
  }

  /// Fills the empty fields that match a saved detail. Never touches a field
  /// that has a value. Undo empties exactly those fields again, unless the
  /// user has since changed one.
  Future<void> _fillFromMyDetails(
    BuildContext context,
    _Prefill prefill,
  ) async {
    // A second tap while filling does nothing; both Fill buttons hide at
    // once rather than when the writes land.
    if (_filling) return;
    setState(() => _filling = true);
    final repo = ref.read(fieldRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final filled = <int, String>{
      for (final f in prefill.toFill) f.id: prefill.values[f.id]!,
    };
    var done = false;
    try {
      // One transaction: the fields update together, in one redraw.
      await ref.read(documentRepositoryProvider).transaction(() async {
        for (final e in filled.entries) {
          await repo.updateField(
            db.FieldsCompanion(
              id: Value(e.key),
              value: Value(e.value),
              isFilled: const Value(true),
            ),
          );
        }
      });
      done = true;
    } finally {
      // Marked prefilled in the same frame the guard lifts, so the Fill
      // buttons can't flash back before the field stream catches up.
      if (mounted) {
        setState(() {
          if (done) _prefilled.addAll(filled.keys);
          _filling = false;
        });
      }
    }
    if (!mounted || !done) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.prefillFilled(filled.length)),
        action: SnackBarAction(
          label: l10n.actionUndo,
          onPressed: () async {
            // Together, like the fill; a field the user changed since stays.
            await ref.read(documentRepositoryProvider).transaction(() async {
              final now = await repo.watchFields(widget.docId).first;
              for (final f in now) {
                if (filled[f.id] != null && f.value == filled[f.id]) {
                  await repo.updateField(
                    db.FieldsCompanion(
                      id: Value(f.id),
                      value: const Value(''),
                      isFilled: const Value(false),
                    ),
                  );
                }
              }
            });
            if (mounted) {
              setState(() => _prefilled.removeAll(filled.keys));
            }
          },
        ),
      ),
    );
  }

  /// Opens Review & Finish. Tapping a field there comes back with its id:
  /// show that field's page and open its input, as if tapped on the page.
  Future<void> _openReview(BuildContext context) async {
    final fieldId = await context.push<int>(
      AppRoutes.press.replaceAll(':docId', '${widget.docId}'),
    );
    if (fieldId == null || !mounted) return;
    final fields = await ref
        .read(fieldRepositoryProvider)
        .watchFields(widget.docId)
        .first;
    final field = fields.where((f) => f.id == fieldId).firstOrNull;
    if (field == null || !mounted) return;
    setState(() => _currentPage = field.pageIndex);
    if (!context.mounted) return;
    await _openFieldInput(context, field, prefill: _lastPrefill);
  }

  Widget _fillFieldBox(
    BuildContext context,
    db.Field field,
    Rect pageRect,
    double? textSize, {
    required _Prefill prefill,
    List<Rect> neighbours = const [],
  }) {
    final type = field.type.toFieldType();
    final prefilled = field.isFilled && _prefilled.contains(field.id);
    return FieldBox(
      key: ValueKey(field.id),
      bbox: BoundingBox.fromJsonString(field.boundingBoxJson),
      pageRect: pageRect,
      neighbours: neighbours,
      // Filled by PreFill: its own tint until the user edits the field.
      color: prefilled
          ? Colors.teal.shade600
          : field.isFilled && !type.isToggle
          ? Colors.amber.shade700
          : colorFor(type),
      shape: shapeFor(type),
      // Fill mode is for filling: a field's position and size are frozen
      // here (move or resize it in Edit Fields), so a tap or a scroll can
      // never shift it by accident.
      movable: false,
      resizable: false,
      showHandles: false,
      onTap: () => _openFieldInput(context, field, prefill: prefill),
      onChanged: (bbox) => ref
          .read(fieldRepositoryProvider)
          .updateField(
            db.FieldsCompanion(
              id: Value(field.id),
              boundingBoxJson: Value(bbox.toJsonString()),
            ),
          ),
      // Filled text at the document's own text size, in on-screen pixels.
      child: _FilledContent(
        field: field,
        fontPx: textSize == null ? null : textSize * pageRect.height,
      ),
    );
  }

  /// Labels of birth-date fields, in the app's languages.
  static final _birthLabel = RegExp(
    r'birth|\bd\.?\s?o\.?\s?b\b|\bborn\b|naissance|nacimiento|nascimento|'
    r'जन्म|பிறந்த|పుట్టిన',
    caseSensitive: false,
    unicode: true,
  );

  Future<void> _openFieldInput(
    BuildContext context,
    db.Field field, {
    _Prefill? prefill,
  }) async {
    final type = field.type.toFieldType();
    switch (type) {
      case FieldType.signature:
      case FieldType.initials:
        final route = AppRoutes.signatureCapture
            .replaceAll(':docId', '${widget.docId}')
            .replaceAll(':fieldId', '${field.id}');
        await context.push(
          type == FieldType.initials ? '$route?initials=1' : route,
        );
        return;

      case FieldType.radio:
        await ref.read(fieldRepositoryProvider).chooseRadio(field);
        return;

      case FieldType.checkbox:
        await ref
            .read(fieldRepositoryProvider)
            .updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                isChecked: Value(!field.isChecked),
                isFilled: const Value(true),
                value: Value(field.isChecked ? '' : '✓'),
              ),
            );
        return;

      case FieldType.date:
        // Capture the pattern + locale before awaiting the picker.
        final datePattern = context.l10n.dateFormatInput;
        final dateLocale = Localizations.localeOf(context).toString();
        // A birth date is decades back: open on the year grid around 30
        // years ago instead of on today, which meant paging back month by
        // month.
        final now = DateTime.now();
        final isBirth = _birthLabel.hasMatch(field.label);
        final picked = await showDatePicker(
          context: context,
          initialDate: isBirth ? DateTime(now.year - 30, now.month) : now,
          initialDatePickerMode: isBirth
              ? DatePickerMode.year
              : DatePickerMode.day,
          firstDate: DateTime(1900),
          lastDate: isBirth ? now : DateTime(2100),
        );
        if (picked == null) return;
        final formatted = DateFormat(datePattern, dateLocale).format(picked);
        await ref
            .read(fieldRepositoryProvider)
            .updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                value: Value(formatted),
                isFilled: const Value(true),
              ),
            );
        return;

      case FieldType.text:
        final result = await _showTextInput(
          context,
          field,
          _suggestionsFor(field, prefill),
        );
        if (result == null) return;
        _prefilled.remove(field.id);
        await ref
            .read(fieldRepositoryProvider)
            .updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                value: Value(result),
                isFilled: Value(result.isNotEmpty),
              ),
            );
    }
  }

  Future<String?> _showTextInput(
    BuildContext context,
    db.Field field,
    List<String> suggestions,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TextInputSheet(field: field, suggestions: suggestions),
    );
  }

  /// Saved details to offer in a text field's sheet: the one matching its
  /// label first, then the rest.
  List<String> _suggestionsFor(db.Field field, _Prefill? prefill) {
    if (prefill == null) return const [];
    final d = prefill.details;
    final all = [
      prefill.values[field.id],
      for (final slot in const [
        PrefillSlot.fullName,
        PrefillSlot.firstName,
        PrefillSlot.lastName,
        PrefillSlot.email,
        PrefillSlot.phone,
        PrefillSlot.address,
        PrefillSlot.city,
        PrefillSlot.state,
        PrefillSlot.zip,
        PrefillSlot.cityStateZip,
        PrefillSlot.country,
        PrefillSlot.company,
        PrefillSlot.jobTitle,
        PrefillSlot.dateOfBirth,
      ])
        d.valueFor(slot, dateFormat: prefill.dateFormat),
    ];
    final seen = <String>{};
    return [
      for (final v in all)
        if (v != null && seen.add(v)) v,
    ];
  }
}

// Owns its TextEditingController via normal State lifecycle so it's disposed
// only once the sheet's exit animation actually finishes removing it from the
// tree — disposing manually right after the pop future resolves races the
// still-animating TextField and corrupts the widget tree.
class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({required this.field, this.suggestions = const []});
  final db.Field field;

  /// Saved My Details values, best match first; tapping one fills the box.
  final List<String> suggestions;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.field.value,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        // Keyboard height, plus the navigation bar when the keyboard is
        // closed (padding is zero while the keyboard covers it). Sheets get
        // no automatic bottom inset, so the buttons sat behind the bar.
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.field.label.isNotEmpty
                ? widget.field.label
                : switch (widget.field.type.toFieldType()) {
                    FieldType.text => context.l10n.fillTextFieldFallback,
                    final t => fieldTypeName(context, t),
                  },
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: context.l10n.fillEnterValueHint,
            ),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              context.l10n.prefillSuggestions,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final v = widget.suggestions[i];
                  return ActionChip(
                    avatar: i == 0
                        ? const Icon(Icons.auto_awesome, size: 14)
                        : null,
                    label: Text(v, overflow: TextOverflow.ellipsis),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _ctrl.text = v;
                      _ctrl.selection = TextSelection.collapsed(
                        offset: v.length,
                      );
                    }),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.actionCancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _ctrl.text),
                child: Text(context.l10n.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── PreFill ───────────────────────────────────────────────────────────────────

/// What PreFill can do on this form right now.
class _Prefill {
  const _Prefill({
    required this.loaded,
    required this.details,
    required this.dateFormat,
    required this.values,
    required this.toFill,
    required this.anyMatch,
  });

  /// The profile has been read (bars stay hidden until then).
  final bool loaded;
  final MyDetails details;
  final DateFormat dateFormat;

  /// Field id → the saved detail for it.
  final Map<int, String> values;

  /// Empty fields that have a saved detail: what Fill would fill.
  final List<db.Field> toFill;

  /// Some field on the form asks for something My Details can hold.
  final bool anyMatch;
}

class _PrefillBanner extends StatelessWidget {
  const _PrefillBanner({
    super.key,
    this.actionKey,
    this.emphasis = false,
    required this.icon,
    required this.text,
    required this.action,
    required this.onAction,
    required this.onClose,
  });
  final Key? actionKey;

  /// The PreFill offer: solid teal (the prefilled-field colour) with a white
  /// button, sliding in, so it can't be missed. The set-up nudge stays quiet.
  final bool emphasis;
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = emphasis ? Colors.teal.shade600 : scheme.secondaryContainer;
    final fg = emphasis ? Colors.white : scheme.onSecondaryContainer;
    final banner = Material(
      color: bg,
      elevation: emphasis ? 2 : 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, emphasis ? 8 : 4, 4, emphasis ? 8 : 4),
        child: Row(
          children: [
            Icon(icon, size: emphasis ? 22 : 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: emphasis ? FontWeight.w600 : null,
                ),
              ),
            ),
            emphasis
                ? FilledButton(
                    key: actionKey,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal.shade800,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: onAction,
                    child: Text(action),
                  )
                : FilledButton.tonal(
                    key: actionKey,
                    onPressed: onAction,
                    child: Text(action),
                  ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icon(Icons.close, size: 18, color: fg),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
    if (!emphasis) return banner;
    // Slides down into place the first time it appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: t.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: banner,
    );
  }
}

// ── Fill overlay ──────────────────────────────────────────────────────────────

class _FilledContent extends StatelessWidget {
  const _FilledContent({required this.field, this.fontPx});
  final db.Field field;

  /// The document's text size on screen; null when not measured, in which
  /// case the value is sized to the field.
  final double? fontPx;

  @override
  Widget build(BuildContext context) {
    final type = field.type.toFieldType();

    // Checkbox / radio: an empty control until chosen, then a tick or a dot
    // scaled to the box — no placeholder text squeezed into a tiny square.
    if (type == FieldType.checkbox) {
      return field.isChecked
          ? FittedBox(child: Icon(Icons.check, color: colorFor(type)))
          : const SizedBox.expand();
    }
    if (type == FieldType.radio) {
      return field.isChecked
          ? FractionallySizedBox(
              widthFactor: 0.55,
              heightFactor: 0.55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorFor(type),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : const SizedBox.expand();
    }

    if (!field.isFilled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            switch (type) {
              FieldType.date => context.l10n.fillTapForDate,
              FieldType.initials => context.l10n.fillTapToInitial,
              FieldType.signature => context.l10n.fillTapToSign,
              _ => context.l10n.fillTapToFill,
            },
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    if (type.isInk && field.value.isNotEmpty) {
      final sigFile = File(PathResolver.resolve(field.value));
      if (sigFile.existsSync()) {
        // The PNG is pre-cropped to the ink, so it fills the field box.
        return Image.file(sigFile, fit: BoxFit.contain);
      }
    }
    // The document's own text size when known (so typed text matches the
    // printed form); otherwise sized to the box. Either way a long value
    // shrinks to fit rather than being cut off.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          field.value,
          style: TextStyle(
            fontSize: fontPx ?? 22,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ── Page picker ───────────────────────────────────────────────────────────────

class _PagePicker extends StatelessWidget {
  const _PagePicker({
    required this.pageCount,
    required this.currentIndex,
    required this.onSelect,
  });
  final int pageCount;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: pageCount,
        separatorBuilder: (context, i) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) => ChoiceChip(
          label: Text('${i + 1}'),
          selected: currentIndex == i,
          onSelected: (_) => onSelect(i),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
