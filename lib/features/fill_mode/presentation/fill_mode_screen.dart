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
import '../../../core/utils/router.dart';

class FillModeScreen extends ConsumerStatefulWidget {
  const FillModeScreen({super.key, required this.docId});
  final int docId;

  @override
  ConsumerState<FillModeScreen> createState() => _FillModeScreenState();
}

class _FillModeScreenState extends ConsumerState<FillModeScreen> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final pagesStream =
        ref.watch(pageRepositoryProvider).watchPages(widget.docId);
    final fieldsStream =
        ref.watch(fieldRepositoryProvider).watchFields(widget.docId);
    final docStream = ref.watch(documentRepositoryProvider).watchAll().map(
          (docs) => docs.firstWhere((d) => d.id == widget.docId,
              orElse: () => throw StateError('doc not found')),
        );

    return StreamBuilder<db.Document>(
      stream: docStream,
      builder: (context, docSnap) {
        final doc = docSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(doc?.title ?? 'Fill Document'),
            actions: [
              TextButton(
                onPressed: () => context.push(
                  AppRoutes.press.replaceAll(':docId', '${widget.docId}'),
                ),
                child: const Text('Review & Press →'),
              ),
            ],
          ),
          body: StreamBuilder<List<db.Page>>(
            stream: pagesStream,
            builder: (context, pagesSnap) {
              final pages = pagesSnap.data ?? [];
              if (pages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final page = pages[_currentPage.clamp(0, pages.length - 1)];

              return StreamBuilder<List<db.Field>>(
                stream: fieldsStream,
                builder: (context, fieldsSnap) {
                  final allFields = fieldsSnap.data ?? [];
                  final pageFields = allFields
                      .where((f) => f.pageIndex == _currentPage)
                      .toList();

                  return Column(
                    children: [
                      // ── Smart-fill chip bar ───────────────────────────────
                      _SmartFillBar(
                        docId: widget.docId,
                        fields: pageFields,
                      ),
                      // ── Page image + overlay ──────────────────────────────
                      Expanded(
                        child: _FillOverlay(
                          page: page,
                          fields: pageFields,
                          onFieldTap: (field) =>
                              _openFieldInput(context, field),
                        ),
                      ),
                      // ── Page picker ───────────────────────────────────────
                      if (pages.length > 1)
                        _PagePicker(
                          pageCount: pages.length,
                          currentIndex: _currentPage,
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

  Future<void> _openFieldInput(BuildContext context, db.Field field) async {
    final type = field.type.toFieldType();
    switch (type) {
      case FieldType.signature:
        await context.push(
          AppRoutes.signatureCapture
              .replaceAll(':docId', '${widget.docId}')
              .replaceAll(':fieldId', '${field.id}'),
        );
        return;

      case FieldType.checkbox:
        await ref.read(fieldRepositoryProvider).updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                isChecked: Value(!field.isChecked),
                isFilled: const Value(true),
                value: Value(field.isChecked ? '' : '✓'),
              ),
            );
        return;

      case FieldType.date:
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        final formatted = DateFormat('MM/dd/yyyy').format(picked);
        await ref.read(fieldRepositoryProvider).updateField(
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
        await ref.read(fieldRepositoryProvider).updateField(
              db.FieldsCompanion(
                id: Value(field.id),
                value: Value(result),
                isFilled: Value(result.isNotEmpty),
              ),
            );
    }
  }

  Future<String?> _showTextInput(BuildContext context, db.Field field) {
    final ctrl = TextEditingController(text: field.value);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label.isNotEmpty ? field.label : 'Text Field',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter value…',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
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

        final today = DateFormat('MM/dd/yyyy').format(DateTime.now());
        final chips = <_ChipData>[
          if (profile.fullName.isNotEmpty)
            _ChipData('Name', profile.fullName, FieldType.text),
          if (profile.email.isNotEmpty)
            _ChipData('Email', profile.email, FieldType.text),
          if (profile.phone.isNotEmpty)
            _ChipData('Phone', profile.phone, FieldType.text),
          if (profile.address.isNotEmpty)
            _ChipData('Address', profile.address, FieldType.text),
          if (profile.company.isNotEmpty)
            _ChipData('Company', profile.company, FieldType.text),
          _ChipData('Today', today, FieldType.date),
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
                label: Text(chip.label,
                    style: const TextStyle(fontSize: 12)),
                onPressed: () =>
                    _fillMatchingFields(ref, chip),
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
        .where((f) =>
            f.type.toFieldType() == chip.type && !f.isFilled)
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

class _FillOverlay extends StatelessWidget {
  const _FillOverlay({
    required this.page,
    required this.fields,
    required this.onFieldTap,
  });

  final db.Page page;
  final List<db.Field> fields;
  final ValueChanged<db.Field> onFieldTap;

  static const _typeColors = {
    FieldType.text: Color(0xFF1565C0),
    FieldType.date: Color(0xFF6A1B9A),
    FieldType.checkbox: Color(0xFF2E7D32),
    FieldType.signature: Color(0xFFBF360C),
  };

  @override
  Widget build(BuildContext context) {
    final isPdf = page.imagePath.contains('#page=');

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        fit: StackFit.expand,
        children: [
          isPdf
              ? Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                      child: Icon(Icons.picture_as_pdf_outlined,
                          size: 64, color: Colors.grey)),
                )
              : Image.file(File(page.imagePath), fit: BoxFit.contain),

          ...fields.map((field) {
            final bbox = BoundingBox.fromJsonString(field.boundingBoxJson);
            final type = field.type.toFieldType();
            final color = _typeColors[type] ?? Colors.blue;
            final isFilled = field.isFilled;

            return Positioned(
              left: bbox.x * constraints.maxWidth,
              top: bbox.y * constraints.maxHeight,
              width: bbox.w * constraints.maxWidth,
              height: bbox.h * constraints.maxHeight,
              child: GestureDetector(
                onTap: () => onFieldTap(field),
                child: Container(
                  decoration: BoxDecoration(
                    color: isFilled
                        ? Colors.yellow.withValues(alpha: 0.35)
                        : color.withValues(alpha: 0.12),
                    border: Border.all(
                      color: isFilled ? Colors.amber.shade700 : color,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 1),
                  child: _fieldContent(field, type),
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _fieldContent(db.Field field, FieldType type) {
    if (!field.isFilled) {
      return Text(
        _placeholder(type),
        style: const TextStyle(
            color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
        overflow: TextOverflow.ellipsis,
      );
    }
    if (type == FieldType.signature && field.value.isNotEmpty) {
      final sigFile = File(field.value);
      if (sigFile.existsSync()) {
        return Image.file(sigFile, fit: BoxFit.contain);
      }
    }
    return Text(
      field.value,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _placeholder(FieldType type) => switch (type) {
        FieldType.text => 'Tap to fill…',
        FieldType.date => 'Tap for date…',
        FieldType.checkbox => 'Tap to check',
        FieldType.signature => 'Tap to sign…',
      };
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
