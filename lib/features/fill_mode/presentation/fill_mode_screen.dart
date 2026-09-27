import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/models/field_model.dart';
import '../../../core/services/document_repository.dart';
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
              // both labelled — the old app-bar icon wasn't readable.
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => context.push(
                        AppRoutes.fieldDetection.replaceAll(
                          ':docId',
                          '${widget.docId}',
                        ),
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: Text(context.l10n.fillEditFields),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: () => context.push(
                          AppRoutes.press.replaceAll(
                            ':docId',
                            '${widget.docId}',
                          ),
                        ),
                        icon: const Icon(Icons.task_alt),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(context.l10n.fillReviewAndFinish),
                        ),
                      ),
                    ),
                  ],
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

              return StreamBuilder<List<db.Field>>(
                stream: _fieldsStream,
                builder: (context, fieldsSnap) {
                  final allFields = fieldsSnap.data ?? [];
                  final pageFields = allFields
                      .where((f) => f.pageIndex == safePage)
                      .toList();

                  return Column(
                    children: [
                      // ── Smart-fill chip bar ───────────────────────────────
                      _SmartFillBar(docId: widget.docId, fields: pageFields),
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _fillFieldBox(
    BuildContext context,
    db.Field field,
    Rect pageRect,
    double? textSize, {
    List<Rect> neighbours = const [],
  }) {
    final type = field.type.toFieldType();
    return FieldBox(
      key: ValueKey(field.id),
      bbox: BoundingBox.fromJsonString(field.boundingBoxJson),
      pageRect: pageRect,
      neighbours: neighbours,
      color: field.isFilled && !type.isToggle
          ? Colors.amber.shade700
          : colorFor(type),
      shape: shapeFor(type),
      // Real AcroForm fields keep the position the source form gave them;
      // they can still be resized (e.g. to fit a signature).
      movable: field.sourceKind == 'app',
      // Pinch resizes any field; the handle is shown only where resizing
      // after filling is common — a signature or initials that came out
      // too small — so the page isn't covered in handles.
      showHandles: type.isInk && field.isFilled,
      onTap: () => _openFieldInput(context, field),
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

  Future<void> _openFieldInput(BuildContext context, db.Field field) async {
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
        final result = await _showTextInput(context, field);
        if (result == null) return;
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

  Future<String?> _showTextInput(BuildContext context, db.Field field) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TextInputSheet(field: field),
    );
  }
}

// Owns its TextEditingController via normal State lifecycle so it's disposed
// only once the sheet's exit animation actually finishes removing it from the
// tree — disposing manually right after the pop future resolves races the
// still-animating TextField and corrupts the widget tree.
class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({required this.field});
  final db.Field field;

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
        MediaQuery.of(context).viewInsets.bottom + 16,
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

// ── Smart-fill chip bar ───────────────────────────────────────────────────────

class _SmartFillBar extends ConsumerWidget {
  const _SmartFillBar({required this.docId, required this.fields});
  final int docId;
  final List<db.Field> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<db.UserProfileData>(
      future: ref.read(profileRepositoryProvider).getOrCreate(),
      builder: (context, snap) {
        final profile = snap.data;
        if (profile == null) return const SizedBox.shrink();

        final today = DateFormat(
          context.l10n.dateFormatInput,
          Localizations.localeOf(context).toString(),
        ).format(DateTime.now());
        final chips = <_ChipData>[
          if (profile.fullName.isNotEmpty)
            _ChipData(
              context.l10n.fillChipName,
              profile.fullName,
              FieldType.text,
            ),
          if (profile.email.isNotEmpty)
            _ChipData(
              context.l10n.fillChipEmail,
              profile.email,
              FieldType.text,
            ),
          if (profile.phone.isNotEmpty)
            _ChipData(
              context.l10n.fillChipPhone,
              profile.phone,
              FieldType.text,
            ),
          if (profile.address.isNotEmpty)
            _ChipData(
              context.l10n.fillChipAddress,
              profile.address,
              FieldType.text,
            ),
          if (profile.company.isNotEmpty)
            _ChipData(
              context.l10n.fillChipCompany,
              profile.company,
              FieldType.text,
            ),
          _ChipData(context.l10n.fillChipToday, today, FieldType.date),
        ];

        if (chips.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: chips.length,
            separatorBuilder: (_, i) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final chip = chips[i];
              return ActionChip(
                label: Text(chip.label, style: const TextStyle(fontSize: 12)),
                onPressed: () => _fillMatchingFields(ref, chip),
                avatar: const Icon(Icons.auto_awesome, size: 14),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _fillMatchingFields(WidgetRef ref, _ChipData chip) async {
    final repo = ref.read(fieldRepositoryProvider);
    // Fill the first unfilled text/date field on the current page
    final candidates = fields
        .where((f) => f.type.toFieldType() == chip.type && !f.isFilled)
        .toList();
    if (candidates.isEmpty) return;
    final target = candidates.first;
    await repo.updateField(
      db.FieldsCompanion(
        id: Value(target.id),
        value: Value(chip.value),
        isFilled: const Value(true),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String value;
  final FieldType type;
  const _ChipData(this.label, this.value, this.type);
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
