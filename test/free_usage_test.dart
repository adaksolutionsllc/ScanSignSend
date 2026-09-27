// The free tier: 2 finished documents of up to 2 pages each; creating and
// filling are free; a document counts once; Full Access lifts everything; and
// reinstalling (a fresh database) doesn't reset the allowance, because the
// count also lives in reinstall-proof storage (Keychain / Block Store).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/free_usage_service.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';

/// Stands in for the Keychain / Block Store: survives "reinstalls" because
/// it outlives any one database.
class _FakeCounter implements PersistentCounter {
  int value = 0;
  @override
  Future<int> read() async => value;
  @override
  Future<void> write(int v) async => value = v;
}

void main() {
  late AppDatabase db;
  late DocumentRepository docs;
  late FreeUsageService usage;
  final counter = _FakeCounter();

  FreeUsageService serviceFor(AppDatabase db) =>
      FreeUsageService(ProfileRepository(db), DocumentRepository(db), counter);

  setUp(() {
    counter.value = 0;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    usage = serviceFor(db);
  });
  tearDown(() => db.close());

  Future<Document> newDoc() async => docs.createDocument('Doc');
  Future<FinishCheck> check(Document d, {int pages = 1}) async =>
      usage.checkFinish((await docs.getById(d.id))!, pageCount: pages);

  test('two free documents, then the paywall', () async {
    final a = await newDoc(), b = await newDoc(), c = await newDoc();
    expect(await check(a), FinishCheck.allowed);
    await usage.recordFinish(a.id);
    expect(await check(b), FinishCheck.allowed);
    await usage.recordFinish(b.id);
    expect(await usage.remaining(), 0);
    expect(await check(c), FinishCheck.allowanceUsed);
  });

  test('finishing the same document again never uses another slot', () async {
    final a = await newDoc();
    await usage.recordFinish(a.id); // Save as Fillable
    await usage.recordFinish(a.id); // …then Flatten & Sign
    expect(await usage.usedCount(), 1);
    // Even with the allowance used up, an already-counted document finishes.
    final b = await newDoc();
    await usage.recordFinish(b.id);
    expect(await check(a), FinishCheck.allowed);
  });

  test('free documents are limited to two pages', () async {
    final a = await newDoc();
    expect(await check(a, pages: 2), FinishCheck.allowed);
    expect(await check(a, pages: 3), FinishCheck.tooManyPages);
    expect(await usage.pagesAllowed(3), isFalse);
  });

  test('Full Access lifts every limit and records nothing', () async {
    await ProfileRepository(
      db,
    ).update(const UserProfileCompanion(isPurchased: Value(true)));
    for (var i = 0; i < 4; i++) {
      final d = await newDoc();
      expect(await check(d, pages: 30), FinishCheck.allowed);
      await usage.recordFinish(d.id);
    }
    expect(counter.value, 0);
  });

  test('reinstalling does not reset the free allowance', () async {
    await usage.recordFinish((await newDoc()).id);
    await usage.recordFinish((await newDoc()).id);
    await db.close();

    // "Reinstall": a brand-new, empty database; only the Keychain/Block
    // Store counter survives.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    usage = serviceFor(db);
    expect(await usage.usedCount(), 2);
    expect(await check(await newDoc()), FinishCheck.allowanceUsed);
    expect(
      (await ProfileRepository(db).getOrCreate()).scanCount,
      2,
      reason: 'the database copy is healed from the persistent one',
    );
  });
}
