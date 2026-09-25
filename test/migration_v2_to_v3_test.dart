// Verifies the v2 → v3 migration is additive and preserves existing data —
// adding `fillablePdfPath` must not disturb documents that already carry a
// `pressedPdfPath` (including pre-fix rows with status='fillable', which used
// to store their export there before FillableFormExportService switched to
// the new column).

import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';

void main() {
  test('v2 → v3 migration preserves data and adds fillablePdfPath', () async {
    final dbFile = File(
        '${Directory.systemTemp.path}/sss_migration_v3_${DateTime.now().microsecondsSinceEpoch}.db');
    if (dbFile.existsSync()) dbFile.deleteSync();

    // ── Phase 1: fake the v2 schema + seed a row, then close fully ────────────
    final v2 = _RawDb(NativeDatabase(dbFile));
    await v2.customStatement('''
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
    await v2.customStatement('''
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
        signature_id INTEGER,
        pdf_field_name TEXT,
        is_required INTEGER NOT NULL DEFAULT 0,
        source_kind TEXT NOT NULL DEFAULT 'app',
        options_json TEXT
      )
    ''');
    // A pre-fix "fillable" export: status/pressedPdfPath set the old way.
    await v2.customStatement(
        "INSERT INTO documents (id, uuid, title, status, pressed_pdf_path, created_at, updated_at) "
        "VALUES (1, 'u1', 'Old Fillable Doc', 'fillable', '/old/export.pdf', 0, 0)");
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    // ── Phase 2: open real AppDatabase on the same file → onUpgrade(2 → 3) ────
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final rows = await db.select(db.documents).get();

    expect(rows, hasLength(1), reason: 'legacy row must survive the migration');
    final row = rows.single;
    expect(row.status, 'fillable');
    expect(row.pressedPdfPath, '/old/export.pdf',
        reason: 'pre-fix export path must stay put for the viewer fallback');
    expect(row.fillablePdfPath, isNull,
        reason: 'new column must be nullable and default to null');

    await db.close();
    if (dbFile.existsSync()) dbFile.deleteSync();
  });
}

/// Drift instance over a shared executor with no declared tables — used only to
/// run raw SQL that fakes the v2 schema. Its close() is never called, so the
/// underlying connection stays open for the real AppDatabase to reopen.
class _RawDb extends drift.GeneratedDatabase {
  _RawDb(super.e);
  @override
  Iterable<drift.TableInfo> get allTables => const [];
  @override
  int get schemaVersion => 2;
}
