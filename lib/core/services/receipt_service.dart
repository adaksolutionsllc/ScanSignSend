import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../utils/region.dart';
import 'document_repository.dart';
import 'page_layout_service.dart';
import 'receipt_parser.dart';

final receiptServiceProvider = Provider<ReceiptService>(
  (ref) => ReceiptService(
    ref.watch(appDatabaseProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(pageLayoutServiceProvider),
  ),
);

/// Receipt details for Export to spreadsheet: read from the pages on the
/// phone the first time they're needed, kept, and corrected by the user.
class ReceiptService {
  ReceiptService(this._db, this._pages, this._layouts);

  final AppDatabase _db;
  final PageRepository _pages;
  final PageLayoutService _layouts;

  /// The details kept for [docId], or read from its pages now and kept.
  /// [region] fills in the currency a receipt doesn't print, and how its
  /// dates are ordered. Never throws: an unreadable receipt comes back
  /// empty for the user to fill in.
  Future<ReceiptDetail> detailsFor(int docId, Region region) async {
    final kept = await (_db.select(
      _db.receiptDetails,
    )..where((t) => t.documentId.equals(docId))).getSingleOrNull();
    if (kept != null) return kept;

    var guess = const ReceiptGuess();
    try {
      final rows = <String>[];
      for (final page in await _pages.pagesOf(docId)) {
        rows.addAll(receiptRows((await _layouts.textOnly(page.imagePath)).$1));
      }
      guess = parseReceipt(rows, dayFirst: region.dayFirst);
    } catch (e) {
      debugPrint('ReceiptService: $e');
    }
    final row = ReceiptDetailsCompanion.insert(
      documentId: Value(docId),
      date: Value(guess.date),
      merchant: Value(guess.merchant ?? ''),
      total: Value(guess.total),
      tax: Value(guess.tax),
      currency: Value(guess.currency ?? region.currency),
    );
    return _db
        .into(_db.receiptDetails)
        .insertReturning(row, mode: InsertMode.insertOrReplace);
  }

  /// The user's corrections; never read over again.
  Future<void> save(ReceiptDetail details) => _db
      .into(_db.receiptDetails)
      .insertOnConflictUpdate(details.copyWith(edited: true));
}
