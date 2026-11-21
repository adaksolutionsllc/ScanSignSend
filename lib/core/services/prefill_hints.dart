import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'prefill_matcher.dart';

export 'prefill_matcher.dart' show LearnedPrefill;

final prefillHintRepositoryProvider = Provider<PrefillHintRepository>(
  (ref) => PrefillHintRepository(ref.watch(appDatabaseProvider)),
);

class PrefillHintRepository {
  PrefillHintRepository(this._db);
  final AppDatabase _db;

  Future<LearnedPrefill> load() async {
    final rows = await _db.select(_db.prefillHints).get();
    final map = <String, Map<String, (int, int)>>{};
    for (final r in rows) {
      (map[r.phrase] ??= {})[r.slot] = (r.accepted, r.rejected);
    }
    return LearnedPrefill(map);
  }

  /// Adds one piece of evidence. Labels PreFill can't learn from (blank,
  /// about someone else, or a whole sentence) are ignored.
  Future<void> record(
    String label,
    PrefillSlot slot, {
    required bool accepted,
  }) async {
    final key = PrefillMatcher.learnKey(label);
    if (key == null) return;
    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.prefillHints)
                ..where((t) => t.phrase.equals(key) & t.slot.equals(slot.name)))
              .getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.prefillHints)
            .insert(
              PrefillHintsCompanion.insert(
                phrase: key,
                slot: slot.name,
                accepted: Value(accepted ? 1 : 0),
                rejected: Value(accepted ? 0 : 1),
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await (_db.update(
          _db.prefillHints,
        )..where((t) => t.id.equals(existing.id))).write(
          PrefillHintsCompanion(
            accepted: Value(existing.accepted + (accepted ? 1 : 0)),
            rejected: Value(existing.rejected + (accepted ? 0 : 1)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// Settings → "Forget what the app has learned", and "Delete my details".
  Future<void> clear() => _db.delete(_db.prefillHints).go();
}
