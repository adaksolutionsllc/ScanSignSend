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

  Stream<UserProfileData> watch() =>
      (_db.select(_db.userProfile)).watchSingle();

  Future<void> update(UserProfileCompanion companion) =>
      (_db.update(_db.userProfile)..where((t) => t.id.equals(1)))
          .write(companion);

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
