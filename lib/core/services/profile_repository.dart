import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(appDatabaseProvider));
});

class ProfileRepository {
  ProfileRepository(this._db);
  final AppDatabase _db;

  /// The profile is the lowest-id row. Several services ask for it at
  /// launch; the transaction serialises their check-then-insert so a first
  /// launch can't create two rows, and reading the lowest id (not "the single
  /// row") keeps a database that already has duplicates working.
  Future<UserProfileData> getOrCreate() => _db.transaction(() async {
        final existing = await _first().getSingleOrNull();
        if (existing != null) return existing;
        await _db.into(_db.userProfile).insert(UserProfileCompanion.insert());
        return _first().getSingle();
      });

  SimpleSelectStatement<$UserProfileTable, UserProfileData> _first() =>
      _db.select(_db.userProfile)
        ..orderBy([(t) => OrderingTerm.asc(t.id)])
        ..limit(1);

  /// Emits the profile row, ensuring one exists first. Selecting with limit(1)
  /// + filtering empty emissions means a missing/duplicate row never throws
  /// (unlike watchSingle, which errors on 0 or 2+ rows).
  Stream<UserProfileData> watch() async* {
    final seed = await getOrCreate();
    yield seed;
    yield* _first()
        .watch()
        .where((rows) => rows.isNotEmpty)
        .map((rows) => rows.first);
  }

  Future<void> update(UserProfileCompanion companion) async {
    // Don't assume id==1 — target whatever row getOrCreate established.
    final profile = await getOrCreate();
    await (_db.update(_db.userProfile)..where((t) => t.id.equals(profile.id)))
        .write(companion);
  }

}
