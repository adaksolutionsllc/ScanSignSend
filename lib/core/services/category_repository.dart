import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/document_category.dart';
import 'category_hints.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(categoryHintRepositoryProvider),
  ),
);

/// The user's own categories (the built-in ones live in code).
class CategoryRepository {
  CategoryRepository(this._db, this._hints);
  final AppDatabase _db;
  final CategoryHintRepository _hints;

  Stream<List<UserCategory>> watchUserCategories() => (_db.select(
    _db.userCategories,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// Creates a category and returns its key (`u:<id>`).
  Future<String> create(String name) async {
    final id = await _db
        .into(_db.userCategories)
        .insert(
          UserCategoriesCompanion.insert(
            name: name.trim(),
            createdAt: DateTime.now(),
          ),
        );
    return userCategoryKey(id);
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.userCategories)..where((t) => t.id.equals(id))).write(
        UserCategoriesCompanion(name: Value(name.trim())),
      );

  /// Removes the category. Its documents stay, Uncategorised; automatic
  /// sorting may file them again later. Never deletes a document.
  Future<void> delete(int id) async {
    final key = userCategoryKey(id);
    await _db.transaction(() async {
      await (_db.update(
        _db.documents,
      )..where((t) => t.category.equals(key))).write(
        const DocumentsCompanion(
          category: Value(null),
          categoryManual: Value(false),
        ),
      );
      await (_db.delete(
        _db.userCategories,
      )..where((t) => t.id.equals(id))).go();
    });
    await _hints.forgetCategory(key);
  }
}
