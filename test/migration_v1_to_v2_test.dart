// Verifies the v1 → v2 migration is additive and preserves existing data —
// the guarantee that shipping the AcroForm schema won't wipe current users.

import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';

void main() {
  test('v1 → v2 migration preserves data and adds columns', () async {
    // Use a real temp FILE (not :memory:) so the two opens below each perform a
    // genuine SQLite open + user_version check — that handshake is what drives
    // drift's onUpgrade. A shared in-memory handle would bypass it.
    final dbFile = File(
        '${Directory.systemTemp.path}/sss_migration_${DateTime.now().microsecondsSinceEpoch}.db');
    if (dbFile.existsSync()) dbFile.deleteSync();

    // ── Phase 1: fake the v1 schema + seed a row, then close fully ────────────
    final v1 = _RawDb(NativeDatabase(dbFile));
    // Minimal v1-shaped tables (only what the seed touches). The `fields` table
    // deliberately omits the v2 AcroForm columns.
    await v1.customStatement('''
      CREATE TABLE documents (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL, title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        page_count INTEGER NOT NULL DEFAULT 0,
        ocr_text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        pressed_pdf_path TEXT, is_template INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await v1.customStatement('''
      CREATE TABLE fields (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        page_index INTEGER NOT NULL,
        type TEXT NOT NULL,
        bounding_box_json TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        value TEXT NOT NULL DEFAULT '',
        is_checked INTEGER NOT NULL DEFAULT 0,
        is_filled INTEGER NOT NULL DEFAULT 0,
        signature_id INTEGER
      )
    ''');
    await v1.customStatement(
        "INSERT INTO documents (id, uuid, title, created_at, updated_at) "
        "VALUES (1, 'u1', 'Old Doc', 0, 0)");
    await v1.customStatement(
        "INSERT INTO fields (document_id, page_index, type, bounding_box_json, value, is_filled) "
        "VALUES (1, 0, 'text', '{\"x\":0.1}', 'legacy value', 1)");
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close(); // flush + release the file so the next open is genuine

    // ── Phase 2: open real AppDatabase on the same file → onUpgrade(1 → 2) ─────
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final rows = await db.select(db.fields).get();

    expect(rows, hasLength(1), reason: 'legacy row must survive the migration');
    final row = rows.single;
    expect(row.value, 'legacy value');
    expect(row.isFilled, isTrue);
    // New v2 columns present with their defaults / nullable values.
    expect(row.sourceKind, 'app');
    expect(row.isRequired, isFalse);
    expect(row.pdfFieldName, isNull);
    expect(row.optionsJson, isNull);

    await db.close();
    if (dbFile.existsSync()) dbFile.deleteSync();
  });
}

/// Drift instance over a shared executor with no declared tables — used only to
/// run raw SQL that fakes the v1 schema. Its close() is never called, so the
/// underlying connection stays open for the real AppDatabase to reopen.
class _RawDb extends drift.GeneratedDatabase {
  _RawDb(super.e);
  @override
  Iterable<drift.TableInfo> get allTables => const [];
  @override
  int get schemaVersion => 1;
}
