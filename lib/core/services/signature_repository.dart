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

  Stream<List<Signature>> watchAll() =>
      (_db.select(_db.signatures)
            ..orderBy([(t) => OrderingTerm.desc(t.isDefault)]))
          .watch();

  Future<int> addSignature({
    required String imagePath,
    required String label,
    bool isDefault = false,
    bool isInitials = false,
  }) async {
    if (isDefault) {
      await (_db.update(_db.signatures))
          .write(const SignaturesCompanion(isDefault: Value(false)));
    }
    return _db.into(_db.signatures).insert(
          SignaturesCompanion.insert(
            imagePath: imagePath,
            label: Value(label),
            isDefault: Value(isDefault),
            isInitials: Value(isInitials),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> setDefault(int id) async {
    await (_db.update(_db.signatures))
        .write(const SignaturesCompanion(isDefault: Value(false)));
    await (_db.update(_db.signatures)..where((t) => t.id.equals(id)))
        .write(const SignaturesCompanion(isDefault: Value(true)));
  }

  Future<void> deleteSignature(int id) =>
      (_db.delete(_db.signatures)..where((t) => t.id.equals(id))).go();

  Future<Signature?> getDefault() =>
      (_db.select(_db.signatures)..where((t) => t.isDefault.equals(true)))
          .getSingleOrNull();
}
