import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'document_repository.dart';
import 'profile_repository.dart';

/// The free tier: [freeDocuments] finished documents of up to [freePageLimit]
/// pages each, then Full Access.
///
/// Creating, detecting, filling and signing are always free. A document is
/// counted when it is *finished* — flattened (Flatten & Sign) or exported
/// (Save as Fillable) — and only once, however many times it's finished.
///
/// The used count is kept twice: in the app database, and in storage that
/// survives uninstalling the app (iOS Keychain; Android Block Store, which
/// persists across reinstall while the user's Google Backup is on). The
/// higher of the two wins, so reinstalling doesn't reset the allowance. No
/// server, no account, no device fingerprinting: it's one number on the
/// device.
class FreeUsageService {
  FreeUsageService(this._profiles, this._docs, [PersistentCounter? counter])
    : _counter = counter ?? const PersistentCounter();

  static const freeDocuments = 2;
  static const freePageLimit = 2;

  final ProfileRepository _profiles;
  final DocumentRepository _docs;
  final PersistentCounter _counter;

  Future<bool> isPremium() async => (await _profiles.getOrCreate()).isPurchased;

  /// Free documents already used on this device.
  Future<int> usedCount() async {
    final profile = await _profiles.getOrCreate();
    final persisted = await _counter.read();
    final used = math.max(profile.scanCount, persisted);
    // Heal whichever copy is behind (e.g. the database after a reinstall).
    if (profile.scanCount < used) {
      await _profiles.update(UserProfileCompanion(scanCount: Value(used)));
    }
    return used;
  }

  Future<int> remaining() async =>
      math.max(0, freeDocuments - await usedCount());

  /// Whether [doc] may be finished now, and if not, why.
  Future<FinishCheck> checkFinish(
    Document doc, {
    required int pageCount,
  }) async {
    if (await isPremium()) return FinishCheck.allowed;
    if (pageCount > freePageLimit) return FinishCheck.tooManyPages;
    if (doc.countedFree) return FinishCheck.allowed; // already paid for
    if (await usedCount() >= freeDocuments) return FinishCheck.allowanceUsed;
    return FinishCheck.allowed;
  }

  /// Records that [docId] was finished. Idempotent per document; no-op for
  /// Full Access.
  Future<void> recordFinish(int docId) async {
    if (await isPremium()) return;
    final doc = await _docs.getById(docId);
    if (doc == null || doc.countedFree) return;
    final used = await usedCount() + 1;
    await _docs.updateDocument(
      DocumentsCompanion(id: Value(docId), countedFree: const Value(true)),
    );
    await _profiles.update(UserProfileCompanion(scanCount: Value(used)));
    await _counter.write(used);
  }

  /// Whether a document of [pageCount] pages is within the free page limit
  /// (always true with Full Access).
  Future<bool> pagesAllowed(int pageCount) async =>
      pageCount <= freePageLimit || await isPremium();
}

enum FinishCheck { allowed, allowanceUsed, tooManyPages }

/// The reinstall-proof copy of the used count (iOS Keychain / Android Block
/// Store). Never throws: storage that's unavailable reads as 0 and the
/// database copy still applies.
class PersistentCounter {
  const PersistentCounter();
  static const _channel = MethodChannel('com.scansignsend/entitlement');

  Future<int> read() async {
    try {
      return await _channel.invokeMethod<int>('getFreeUsed') ?? 0;
    } catch (e) {
      debugPrint('Free allowance not read from secure storage: $e');
      return 0;
    }
  }

  Future<void> write(int value) async {
    try {
      await _channel.invokeMethod<bool>('setFreeUsed', {'value': value});
    } catch (e) {
      debugPrint('Free allowance not written to secure storage: $e');
    }
  }
}

final freeUsageServiceProvider = Provider<FreeUsageService>(
  (ref) => FreeUsageService(
    ref.watch(profileRepositoryProvider),
    ref.watch(documentRepositoryProvider),
  ),
);
