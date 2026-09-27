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
  // Path to the pressed/flattened PDF; null until pressed. Setting this is
  // what locks the document (status becomes 'pressed') — it must never be
  // reused for the fillable export below, or exporting a shareable copy would
  // also (wrongly) freeze the live document out of further editing.
  TextColumn get pressedPdfPath => text().nullable()();
  // Path to the last "Save as Fillable" AcroForm export (schema v3). Purely a
  // shareable snapshot — writing this does NOT change `status` or lock the
  // document; the original stays editable through further fill/sign/press.
  TextColumn get fillablePdfPath => text().nullable()();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();
  // Schema v5. The document's body text size as a fraction of page height,
  // measured when fields are detected. New fields are sized to it and filled
  // text is drawn at it, so what the user types matches the printed form.
  // Null until measured (or for a page with no text).
  RealColumn get textSize => real().nullable()();
  // Schema v7. This document has used one of the free allowance's finished
  // documents, so flattening or exporting it again doesn't use another.
  BoolColumn get countedFree => boolean().withDefault(const Constant(false))();
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

  // ── AcroForm workbench (schema v2) ──────────────────────────────────────────
  // Fully-qualified AcroForm field name when this row mirrors a real widget in
  // an imported PDF. Null for app-authored fields. This is the round-trip key.
  TextColumn get pdfFieldName => text().nullable()();
  // Whether the source form marked this field required.
  BoolColumn get isRequired => boolean().withDefault(const Constant(false))();
  // 'acroform' = read from an imported PDF's form; 'app' = user/heuristic made.
  // Only 'app' fields are movable in the editor; 'acroform' fields are fill-only
  // until authoring (Phase C) can safely re-geometry a real widget.
  TextColumn get sourceKind => text().withDefault(const Constant('app'))();
  // JSON list of choices for combo/radio/list fields, e.g. ["Yes","No"]. Null
  // for text/checkbox/date/signature.
  TextColumn get optionsJson => text().nullable()();
}

class Signatures extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().withDefault(const Constant('My Signature'))();
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
  // Schema v4. Whether documents, signatures and this database are included in
  // the OS device backup (iCloud Backup on iOS, Google Auto Backup and
  // device-to-device transfer on Android). Off by default: the app's promise is
  // that documents stay on the device unless the user opts in.
  BoolColumn get includeInDeviceBackup =>
      boolean().withDefault(const Constant(false))();
}

/// Schema v6. What the user's own edits have taught field detection, per
/// phrase: e.g. after "father's name" they add a text field (accepted), or
/// keep deleting the date detected after "on" (rejected). On-device only —
/// it never leaves the phone and is cleared from Settings.
class FieldHints extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Normalised label phrase: lowercase, no punctuation, at most three words.
  TextColumn get phrase => text()();
  // A FieldType name.
  TextColumn get type => text()();
  IntColumn get accepted => integer().withDefault(const Constant(0))();
  IntColumn get rejected => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {phrase, type},
  ];
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Documents, Pages, Fields, Signatures, UserProfile, FieldHints],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor: run the database over a caller-supplied executor
  /// (e.g. an in-memory SQLite) so migrations can be exercised without touching
  /// the on-device file.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 → v2: AcroForm workbench columns. Purely additive — all new
      // columns are nullable or have defaults, so existing rows are safe.
      if (from < 2) {
        await m.addColumn(fields, fields.pdfFieldName);
        await m.addColumn(fields, fields.isRequired);
        await m.addColumn(fields, fields.sourceKind);
        await m.addColumn(fields, fields.optionsJson);
      }
      // v2 → v3: separate column for the "Save as Fillable" export path,
      // previously (wrongly) sharing pressedPdfPath with the flatten/lock
      // artifact. Existing rows with status='fillable' keep that path in
      // pressedPdfPath — it still resolves fine as a fillable-export
      // viewer fallback — new exports land in the new column instead.
      if (from < 3) {
        await m.addColumn(documents, documents.fillablePdfPath);
      }
      // v3 → v4: opt-in device backup. Defaults to off, which matches the
      // behaviour every earlier build shipped with.
      if (from < 4) {
        await m.addColumn(userProfile, userProfile.includeInDeviceBackup);
      }
      // v4 → v5: measured body text size. Nullable — unknown until the
      // document's fields are next detected.
      if (from < 5) {
        await m.addColumn(documents, documents.textSize);
      }
      // v5 → v6: on-device learning from the user's field edits.
      if (from < 6) {
        await m.createTable(fieldHints);
      }
      // v6 → v7: per-document free-allowance flag.
      if (from < 7) {
        await m.addColumn(documents, documents.countedFree);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'scan_sign_send.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
