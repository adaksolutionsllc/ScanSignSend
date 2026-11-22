import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/db/app_database.dart';
import '../../../core/services/app_lock_provider.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/receipt_csv.dart';
import '../../../core/services/receipt_parser.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/region.dart';
import '../../../shared/utils/share_pdf.dart';

/// Library → select receipts → Export to spreadsheet: each receipt's date,
/// merchant, total, tax and currency, read on the phone, to check and
/// correct, then shared as a .csv.
class ReceiptsScreen extends ConsumerStatefulWidget {
  const ReceiptsScreen({super.key, required this.docIds, this.region});
  final List<int> docIds;

  /// The phone's region; tests pass one.
  final Region? region;

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  late final Region _region = widget.region ?? Region.device();

  /// (document, details) in the order chosen; filled in as each is read.
  final _rows = <(Document, ReceiptDetail)>[];
  bool _reading = true;
  bool _exporting = false;
  final _exportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _read();
  }

  /// One receipt at a time, so the list fills in as OCR goes.
  Future<void> _read() async {
    final docs = ref.read(documentRepositoryProvider);
    final receipts = ref.read(receiptServiceProvider);
    for (final id in widget.docIds) {
      final doc = await docs.getById(id);
      if (doc == null) continue;
      final details = await receipts.detailsFor(id, _region);
      if (!mounted) return;
      setState(() => _rows.add((doc, details)));
    }
    if (mounted) setState(() => _reading = false);
  }

  Future<void> _edit(int i) async {
    final (doc, details) = _rows[i];
    final edited = await showModalBottomSheet<ReceiptDetail>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _EditSheet(details: details),
    );
    if (edited == null || !mounted) return;
    await ref.read(receiptServiceProvider).save(edited);
    if (!mounted) return;
    setState(() => _rows[i] = (doc, edited.copyWith(edited: true)));
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final lock = ref.read(appLockProvider.notifier);
    final box = _exportKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final csv = buildReceiptCsv(
      [
        for (final (doc, d) in _rows)
          ReceiptCsvRow(
            document: doc.title,
            date: d.date,
            merchant: d.merchant,
            total: d.total,
            tax: d.tax,
            currency: d.currency,
          ),
      ],
      headers: ReceiptCsvHeaders(
        date: l10n.receiptDate,
        merchant: l10n.receiptMerchant,
        total: l10n.receiptTotal,
        tax: l10n.receiptTax,
        currency: l10n.receiptCurrency,
        document: l10n.receiptDocument,
      ),
      decimalComma: _region.decimalComma,
    );
    setState(() => _exporting = true);
    try {
      final dir = await shareDir();
      final name =
          safeFileName(l10n.receiptsFileName(today)) ?? 'Receipts $today';
      final file = File(p.join(dir.path, '$name.csv'));
      await file.writeAsString(csv, flush: true);
      await shareDocumentFiles(
        lock: lock,
        files: [(file.path, 'text/csv')],
        title: name,
        origin: origin,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sendShareFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l10n.receiptsHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, (doc, d)) in _rows.indexed)
            _ReceiptCard(
              key: ValueKey('receipt-${doc.id}'),
              title: doc.title,
              details: d,
              onTap: () => _edit(i),
            ),
          if (_reading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.receiptsReading),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            key: _exportKey,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _reading || _exporting || _rows.isEmpty ? null : _export,
            icon: const Icon(Icons.table_view_outlined),
            label: Text(l10n.receiptsExportCsv),
          ),
        ),
      ),
    );
  }
}

/// [minor] units of [currency] in the app's language: "₹315.00",
/// "6,05 €".
String formatMoney(BuildContext context, int minor, String currency) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  try {
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: currency.isEmpty ? null : currency,
    ).format(minor / 100);
  } catch (_) {
    return '${(minor / 100).toStringAsFixed(2)} $currency'.trim();
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    super.key,
    required this.title,
    required this.details,
    required this.onTap,
  });

  final String title;
  final ReceiptDetail details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final missing = l10n.receiptMissing;
    final d = details;
    String date(DateTime? v) =>
        v == null ? missing : DateFormat.yMMMd(locale).format(v);
    String money(int? v) =>
        v == null ? missing : formatMoney(context, v, d.currency);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: muted, maxLines: 1),
                    const SizedBox(height: 2),
                    Text(
                      d.merchant.isEmpty ? missing : d.merchant,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.receiptDate}: ${date(d.date)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${l10n.receiptTotal}: ${money(d.total)}   '
                      '${l10n.receiptTax}: ${money(d.tax)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Correct one receipt; pops the corrected details, or nothing on Cancel.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.details});
  final ReceiptDetail details;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _merchant = TextEditingController(text: widget.details.merchant);
  late final _total = TextEditingController(text: _plain(widget.details.total));
  late final _tax = TextEditingController(text: _plain(widget.details.tax));
  late final _currency = TextEditingController(text: widget.details.currency);
  late DateTime? _date = widget.details.date;
  bool _tried = false;

  /// The amount as typed back: "315.00".
  static String _plain(int? minor) => minor == null
      ? ''
      : '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

  /// Empty is allowed (unknown); anything else must be an amount.
  static bool _valid(String s) =>
      s.trim().isEmpty || parseAmount(s.trim()) != null;

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    _tax.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    setState(() => _tried = true);
    if (!_valid(_total.text) || !_valid(_tax.text)) return;
    int? amount(String s) => s.trim().isEmpty ? null : parseAmount(s.trim());
    Navigator.pop(
      context,
      widget.details.copyWith(
        merchant: _merchant.text.trim(),
        date: Value(_date),
        total: Value(amount(_total.text)),
        tax: Value(amount(_tax.text)),
        currency: _currency.text.trim().toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String? amountError(TextEditingController c) =>
        _tried && !_valid(c.text) ? l10n.receiptAmountInvalid : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.receiptEditTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('receipt-merchant'),
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.receiptMerchant,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('receipt-date'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                alignment: AlignmentDirectional.centerStart,
              ),
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _date == null
                    ? l10n.receiptChooseDate
                    : '${l10n.receiptDate}: '
                          '${DateFormat.yMMMd(locale).format(_date!)}',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: const ValueKey('receipt-total'),
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.receiptTotal,
                      errorText: amountError(_total),
                      errorMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const ValueKey('receipt-currency'),
                    controller: _currency,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    decoration: InputDecoration(
                      labelText: l10n.receiptCurrency,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('receipt-tax'),
              controller: _tax,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.receiptTax,
                errorText: amountError(_tax),
                errorMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.actionCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('receipt-save'),
                    onPressed: _save,
                    child: Text(l10n.actionSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
