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

  Future<UserProfileData> getOrCreate() async {
    final existing = await (_db.select(_db.userProfile)).getSingleOrNull();
    if (existing != null) return existing;
    final id = await _db.into(_db.userProfile).insert(
          UserProfileCompanion.insert(),
        );
    return (_db.select(_db.userProfile)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Emits the profile row, ensuring one exists first. Selecting with limit(1)
  /// + filtering empty emissions means a missing/duplicate row never throws
  /// (unlike watchSingle, which errors on 0 or 2+ rows).
  Stream<UserProfileData> watch() async* {
    final seed = await getOrCreate();
    yield seed;
    yield* (_db.select(_db.userProfile)..limit(1))
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

  Future<void> incrementScanCount() async {
    final profile = await getOrCreate();
    await update(UserProfileCompanion(
      scanCount: Value(profile.scanCount + 1),
    ));
  }

  Future<bool> canScan() async {
    final profile = await getOrCreate();
    return profile.isPurchased || profile.scanCount < 3;
  }
}
