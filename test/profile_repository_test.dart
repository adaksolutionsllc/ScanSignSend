// The profile is a single row that several services ask for at launch (IAP,
// backup setting, the library's purchase badge). Concurrent first calls used
// to insert one row each, after which every getSingleOrNull() threw — which
// silently broke field detection, autofill and the free-tier check.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository profiles;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profiles = ProfileRepository(db);
  });
  tearDown(() => db.close());

  test('concurrent first calls create exactly one profile row', () async {
    final results = await Future.wait([
      for (var i = 0; i < 5; i++) profiles.getOrCreate(),
      profiles.update(const UserProfileCompanion(fullName: Value('Priya'))),
    ]);
    expect(await db.select(db.userProfile).get(), hasLength(1));
    final ids = results.whereType<UserProfileData>().map((p) => p.id).toSet();
    expect(ids, hasLength(1));
    expect((await profiles.getOrCreate()).fullName, 'Priya');
  });

  test('a database that already has duplicate rows still works', () async {
    await db.into(db.userProfile).insert(
          const UserProfileCompanion(fullName: Value('first')),
        );
    await db.into(db.userProfile).insert(
          const UserProfileCompanion(fullName: Value('second')),
        );

    final p = await profiles.getOrCreate();
    expect(p.fullName, 'first');

    await profiles.update(const UserProfileCompanion(isPurchased: Value(true)));
    expect((await profiles.getOrCreate()).isPurchased, isTrue);
    expect((await profiles.watch().first).isPurchased, isTrue);
  });
}
