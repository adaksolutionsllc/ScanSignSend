import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';

final signatureRepositoryProvider = Provider<SignatureRepository>((ref) {
  return SignatureRepository(ref.watch(appDatabaseProvider));
});

class SignatureRepository {
  SignatureRepository(this._db);
  final AppDatabase _db;

  Stream<List<Signature>> watchAll() => (_db.select(
    _db.signatures,
  )..orderBy([(t) => OrderingTerm.desc(t.isDefault)])).watch();

  Future<int> addSignature({
    required String imagePath,
    required String label,
    bool isDefault = false,
    bool isInitials = false,
  }) async {
    if (isDefault) {
      // One default per kind: a new default set of initials must not
      // un-default the user's signature, and vice versa.
      await (_db.update(_db.signatures)
            ..where((t) => t.isInitials.equals(isInitials)))
          .write(const SignaturesCompanion(isDefault: Value(false)));
    }
    return _db
        .into(_db.signatures)
        .insert(
          SignaturesCompanion.insert(
            imagePath: imagePath,
            label: Value(label),
            isDefault: Value(isDefault),
            isInitials: Value(isInitials),
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Makes [id] the default of its kind (signature or initials).
  Future<void> setDefault(int id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.signatures,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.signatures)
          ..where((t) => t.isInitials.equals(row.isInitials)))
        .write(const SignaturesCompanion(isDefault: Value(false)));
    await (_db.update(_db.signatures)..where((t) => t.id.equals(id))).write(
      const SignaturesCompanion(isDefault: Value(true)),
    );
  });

  Future<void> deleteSignature(int id) =>
      (_db.delete(_db.signatures)..where((t) => t.id.equals(id))).go();

  /// The default signature, or with [initials] the default initials. There's
  /// one default per kind, so both can exist at once.
  Future<Signature?> getDefault({bool initials = false}) =>
      (_db.select(_db.signatures)
            ..where(
              (t) => t.isDefault.equals(true) & t.isInitials.equals(initials),
            )
            ..limit(1))
          .getSingleOrNull();
}
