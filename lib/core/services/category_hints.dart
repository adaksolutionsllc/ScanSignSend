import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'keyword_categoriser.dart';

/// What the user's category changes have taught sorting, as evidence per
/// (title word, category). Like [LearnedHints] for fields: one odd move never
/// changes behaviour; a pattern seen twice does.
class LearnedCategoryHints {
  const LearnedCategoryHints(this._evidence);

  /// word → category key → (accepted, rejected)
  final Map<String, Map<String, (int, int)>> _evidence;

  static const none = LearnedCategoryHints({});

  static const _minEvidence = 2;

  bool get isEmpty => _evidence.isEmpty;

  /// The category the user has settled on for documents titled like [title],
  /// or null. When the title's words point at different categories, the one
  /// with more acceptances wins; a tie answers nothing.
  String? categoryFor(String title) {
    final votes = <String, int>{};
    for (final word in titleWords(title)) {
      final byCategory = _evidence[word];
      if (byCategory == null) continue;
      for (final e in byCategory.entries) {
        final (acc, rej) = e.value;
        if (acc < _minEvidence || acc <= rej) continue;
        votes[e.key] = (votes[e.key] ?? 0) + acc;
      }
    }
    if (votes.isEmpty) return null;
    final ranked = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.length > 1 && ranked[0].value == ranked[1].value) return null;
    return ranked.first.key;
  }
}

/// The words of a title worth learning from: normalised, at least four
/// letters, no digits, not a generic word like "form", and without the date
/// that automatic naming appends after " – ".
Set<String> titleWords(String title) {
  final dash = title.lastIndexOf(' – ');
  final core = dash > 0 ? title.substring(0, dash) : title;
  return {
    for (final w in KeywordCategoriser.normalise(core).split(' '))
      if (w.length >= 4 &&
          !RegExp(r'\d').hasMatch(w) &&
          !_genericWords.contains(w))
        w,
  };
}

const _genericWords = {
  'document', 'documento', 'documents', 'form', 'forms', 'formulaire',
  'formulario', 'application', 'demande', 'solicitud', 'pedido', 'ficha',
  'scan', 'copy', 'copie', 'copia', 'page', 'pagina', 'final', 'signed',
  'draft', 'with', 'from', 'pour', 'para', 'avec', 'sans', 'that', 'this',
};

final categoryHintRepositoryProvider = Provider<CategoryHintRepository>(
  (ref) => CategoryHintRepository(ref.watch(appDatabaseProvider)),
);

class CategoryHintRepository {
  CategoryHintRepository(this._db);
  final AppDatabase _db;

  Future<LearnedCategoryHints> load() async {
    final rows = await _db.select(_db.categoryHints).get();
    final map = <String, Map<String, (int, int)>>{};
    for (final r in rows) {
      (map[r.phrase] ??= {})[r.category] = (r.accepted, r.rejected);
    }
    return LearnedCategoryHints(map);
  }

  /// The user moved a document titled [title] from [from] (an automatic
  /// choice, or null) to [to] (or to Uncategorised, null).
  Future<void> recordMove(String title, {String? from, String? to}) async {
    final words = titleWords(title);
    if (words.isEmpty || from == to) return;
    await _db.transaction(() async {
      for (final w in words) {
        if (to != null) await _bump(w, to, accepted: true);
        if (from != null) await _bump(w, from, accepted: false);
      }
    });
  }

  Future<void> _bump(String word, String category, {required bool accepted}) async {
    final existing =
        await (_db.select(_db.categoryHints)..where(
              (t) => t.phrase.equals(word) & t.category.equals(category),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.categoryHints)
          .insert(
            CategoryHintsCompanion.insert(
              phrase: word,
              category: category,
              accepted: Value(accepted ? 1 : 0),
              rejected: Value(accepted ? 0 : 1),
              updatedAt: DateTime.now(),
            ),
          );
    } else {
      await (_db.update(
        _db.categoryHints,
      )..where((t) => t.id.equals(existing.id))).write(
        CategoryHintsCompanion(
          accepted: Value(existing.accepted + (accepted ? 1 : 0)),
          rejected: Value(existing.rejected + (accepted ? 0 : 1)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Forgets hints that point at a user category being deleted.
  Future<void> forgetCategory(String category) => (_db.delete(
    _db.categoryHints,
  )..where((t) => t.category.equals(category))).go();

  /// Settings → forget what the app has learned.
  Future<void> clear() => _db.delete(_db.categoryHints).go();
}
