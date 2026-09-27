import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/field_model.dart';

/// What the user's own edits have taught detection, as evidence per
/// (phrase, field type). Pure data, so the detection engine can take it as a
/// plain argument and stay testable.
///
/// The thresholds are deliberately conservative: one odd edit never changes
/// behaviour; a pattern seen twice does.
class LearnedHints {
  const LearnedHints(this._evidence);

  /// phrase → type name → (accepted, rejected)
  final Map<String, Map<String, (int, int)>> _evidence;

  static const none = LearnedHints({});

  static const _minEvidence = 2;

  bool get isEmpty => _evidence.isEmpty;

  /// The type the user has settled on after [phrase], if any: the most
  /// accepted type with at least two acceptances and more acceptances than
  /// rejections.
  FieldType? preferredType(String phrase) {
    final byType = _evidence[normalizePhrase(phrase)];
    if (byType == null) return null;
    MapEntry<String, (int, int)>? best;
    for (final e in byType.entries) {
      final (acc, rej) = e.value;
      if (acc < _minEvidence || acc <= rej) continue;
      if (best == null || acc > best.value.$1) best = e;
    }
    return best?.key.toFieldType();
  }

  /// True when the user keeps deleting a detected [type] after [phrase]:
  /// at least two rejections and twice as many rejections as acceptances.
  bool suppressed(String phrase, FieldType type) {
    final e = _evidence[normalizePhrase(phrase)]?[type.name];
    if (e == null) return false;
    final (acc, rej) = e;
    return rej >= _minEvidence && rej >= acc * 2;
  }

  /// Phrases after which the user reliably adds a field, with that type —
  /// used to propose fields where no line or gap marks a blank.
  Iterable<(String, FieldType)> get learnedPlacements sync* {
    for (final phrase in _evidence.keys) {
      if (phrase.isEmpty) continue;
      final type = preferredType(phrase);
      if (type != null) yield (phrase, type);
    }
  }
}

/// Lowercase, punctuation stripped, whitespace collapsed, last three words —
/// so "Father's Name :" and "father's name" count as the same phrase.
String normalizePhrase(String s) {
  final words = s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  return words.sublist(words.length > 3 ? words.length - 3 : 0).join(' ');
}

final fieldHintRepositoryProvider = Provider<FieldHintRepository>(
  (ref) => FieldHintRepository(ref.watch(appDatabaseProvider)),
);

class FieldHintRepository {
  FieldHintRepository(this._db);
  final AppDatabase _db;

  Future<LearnedHints> load() async {
    final rows = await _db.select(_db.fieldHints).get();
    final map = <String, Map<String, (int, int)>>{};
    for (final r in rows) {
      (map[r.phrase] ??= {})[r.type] = (r.accepted, r.rejected);
    }
    return LearnedHints(map);
  }

  /// Adds one piece of evidence. Blank phrases carry no signal and are
  /// ignored.
  Future<void> record(
    String phrase,
    FieldType type, {
    required bool accepted,
  }) async {
    final key = normalizePhrase(phrase);
    if (key.isEmpty) return;
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.fieldHints)
                ..where((t) => t.phrase.equals(key) & t.type.equals(type.name)))
              .getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.fieldHints)
            .insert(
              FieldHintsCompanion.insert(
                phrase: key,
                type: type.name,
                accepted: Value(accepted ? 1 : 0),
                rejected: Value(accepted ? 0 : 1),
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await (_db.update(
          _db.fieldHints,
        )..where((t) => t.id.equals(existing.id))).write(
          FieldHintsCompanion(
            accepted: Value(existing.accepted + (accepted ? 1 : 0)),
            rejected: Value(existing.rejected + (accepted ? 0 : 1)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// Settings → "Forget learned field patterns".
  Future<void> clear() => _db.delete(_db.fieldHints).go();
}
