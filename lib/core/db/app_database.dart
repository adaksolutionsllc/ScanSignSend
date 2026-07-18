import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get title => text()();
  // 'draft' | 'pressed' | 'template'
  TextColumn get status => text().withDefault(const Constant('draft'))();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  TextColumn get ocrText => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  // Path to the pressed/flattened PDF; null until pressed
  TextColumn get pressedPdfPath => text().nullable()();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();
}

class Pages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().references(Documents, #id)();
  IntColumn get pageIndex => integer()();
  TextColumn get imagePath => text()();
  // 'original' | 'enhanced' | 'bw'
  TextColumn get activeFilter =>
      text().withDefault(const Constant('enhanced'))();
  TextColumn get ocrText => text().withDefault(const Constant(''))();
}

class Fields extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId => integer().references(Documents, #id)();
  IntColumn get pageIndex => integer()();
  // 'text' | 'date' | 'checkbox' | 'signature'
  TextColumn get type => text()();
  // JSON: {"x": 0.1, "y": 0.2, "w": 0.5, "h": 0.05} — normalised 0..1
  TextColumn get boundingBoxJson => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
  TextColumn get value => text().withDefault(const Constant(''))();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  BoolColumn get isFilled => boolean().withDefault(const Constant(false))();
  IntColumn get signatureId => integer().nullable()();
}

class Signatures extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label =>
      text().withDefault(const Constant('My Signature'))();
  TextColumn get imagePath => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isInitials => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class UserProfile extends Table {
  // Single-row table; always upsert id=1
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get state => text().withDefault(const Constant(''))();
  TextColumn get zip => text().withDefault(const Constant(''))();
  TextColumn get company => text().withDefault(const Constant(''))();
  BoolColumn get biometricLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get aiEnhancedDetection =>
      boolean().withDefault(const Constant(false))();
  IntColumn get scanCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Documents, Pages, Fields, Signatures, UserProfile],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'scan_sign_send.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
