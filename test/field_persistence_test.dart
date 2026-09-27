// Closing and reopening the app must bring back every field exactly where
// the user left it: same page, same position, same pinch-resized size. The
// editor now writes each edit through to SQLite as it happens, so these tests
// reopen the database file from scratch, as a fresh app launch would.

import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/ai_enhancer_service.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/field_hints.dart';
import 'package:scan_sign_send/core/services/ocr_service.dart';
import 'package:scan_sign_send/core/services/page_layout_service.dart';
import 'package:scan_sign_send/core/services/page_raster_service.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/features/field_detection/presentation/field_detection_notifier.dart';
import 'package:scan_sign_send/shared/widgets/page_canvas.dart';

FieldDetectionNotifier _editor(AppDatabase db, int docId) =>
    FieldDetectionNotifier(
      docId: docId,
      layouts: PageLayoutService(OcrService(), PageRasterService()),
      hintRepo: FieldHintRepository(db),
      aiEnhancer: AiEnhancerService(ProfileRepository(db)),
      docRepo: DocumentRepository(db),
      pageRepo: PageRepository(db),
      fieldRepo: FieldRepository(db),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('edits survive an app restart: page, position and pinched size', () async {
    final file = File(
      '${Directory.systemTemp.path}/sss_persist_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    var db = AppDatabase.forTesting(NativeDatabase(file));
    final doc = await DocumentRepository(db).createDocument('Form');
    final pages = PageRepository(db);
    for (var i = 0; i < 3; i++) {
      await pages.addPage(
        documentId: doc.id,
        pageIndex: i,
        imagePath: 'pages/u/page_$i.jpg',
      );
    }

    final editor = _editor(db, doc.id);
    await editor.loadExisting();
    editor.addManualField(
      type: FieldType.text,
      pageIndex: 0,
      bbox: const BoundingBox(x: 0.1, y: 0.1, w: 0.4, h: 0.035),
    );
    editor.addManualField(
      type: FieldType.signature,
      pageIndex: 2,
      bbox: const BoundingBox(x: 0.5, y: 0.8, w: 0.35, h: 0.07),
    );
    editor.addManualField(
      type: FieldType.checkbox,
      pageIndex: 1,
      bbox: const BoundingBox(x: 0.2, y: 0.2, w: 0.04, h: 0.03),
    );
    // Move + pinch the signature straight after adding it — before its insert
    // has necessarily landed — and delete the checkbox.
    const pinched = BoundingBox(x: 0.45, y: 0.75, w: 0.5, h: 0.12);
    editor.updateBbox(1, pinched);
    editor.updateLabel(0, 'Full name');
    editor.deleteField(2);
    await editor.flush();
    await editor.flush(); // a second flush (double tap) must not duplicate
    editor.dispose();
    await db.close();

    // ── "Reopen the app" ──────────────────────────────────────────────────────
    db = AppDatabase.forTesting(NativeDatabase(file));
    final saved = await FieldRepository(db).watchFields(doc.id).first;
    expect(saved, hasLength(2));
    final name = saved.firstWhere((f) => f.type == 'text');
    final sig = saved.firstWhere((f) => f.type == 'signature');
    expect(name.pageIndex, 0);
    expect(name.label, 'Full name');
    expect(name.pdfFieldName, 'Full name');
    expect(sig.pageIndex, 2);
    expect(
      BoundingBox.fromJsonString(sig.boundingBoxJson).toJson(),
      pinched.toJson(),
    );

    // Re-entering the editor loads them instead of re-running detection.
    final reopened = _editor(db, doc.id);
    late FieldDetectionState seen;
    reopened.addListener((s) => seen = s);
    await reopened.loadExisting();
    expect(seen.fields.map((f) => f.pageIndex).toList()..sort(), [0, 2]);
    reopened.dispose();
    await db.close();
    file.deleteSync();
  });

  group('page geometry', () {
    test('the page rect is the letterboxed content, not the container', () {
      // A4-ish scan in a tall phone viewport: full width, centred vertically.
      final r = pageRectFor(const Size(1240, 1754), const Size(390, 700));
      expect(r.width, closeTo(390, 0.01));
      expect(r.height, closeTo(390 * 1754 / 1240, 0.01));
      expect(r.top, closeTo((700 - r.height) / 2, 0.01));
      // The same field lands on the same spot of the page in two differently
      // shaped containers (editor vs fill mode).
      const box = BoundingBox(x: 0.25, y: 0.5, w: 0.5, h: 0.05);
      for (final container in [const Size(390, 520), const Size(390, 640)]) {
        final page = pageRectFor(const Size(1240, 1754), container);
        final f = box.inPageRect(page);
        expect((f.left - page.left) / page.width, closeTo(0.25, 1e-9));
        expect((f.top - page.top) / page.height, closeTo(0.5, 1e-9));
      }
    });

    test('four clockwise rotations are the identity', () {
      const b = BoundingBox(x: 0.1, y: 0.2, w: 0.3, h: 0.05);
      final r = b
          .rotatedClockwise()
          .rotatedClockwise()
          .rotatedClockwise()
          .rotatedClockwise();
      expect(r.x, closeTo(b.x, 1e-12));
      expect(r.y, closeTo(b.y, 1e-12));
      expect(r.w, closeTo(b.w, 1e-12));
      expect(r.h, closeTo(b.h, 1e-12));
    });

    test('new fields start inside the page, and checkboxes are square', () {
      const aspect = 1240 / 1754;
      for (final t in FieldType.values) {
        final b = defaultFieldBox(t, const Offset(0.99, 0.99), aspect);
        expect(b.x + b.w, lessThanOrEqualTo(1.0 + 1e-9), reason: '$t');
        expect(b.y + b.h, lessThanOrEqualTo(1.0 + 1e-9), reason: '$t');
      }
      final cb = defaultFieldBox(
        FieldType.checkbox,
        const Offset(0.5, 0.5),
        aspect,
      );
      const page = Size(1240, 1754);
      expect(cb.w * page.width, closeTo(cb.h * page.height, 0.01));
    });
  });

  test(
    'reopening keeps every field option, and edits don\'t erase them',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final doc = await DocumentRepository(db).createDocument('Form');
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: 0, imagePath: 'pages/u/p.jpg');
      final fields = FieldRepository(db);
      final id = await fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: FieldType.date.name,
          boundingBoxJson: const BoundingBox(
            x: 0.1,
            y: 0.1,
            w: 0.2,
            h: 0.02,
          ).toJsonString(),
          optionsJson: Value(fieldOptionsJson(autoToday: true)),
        ),
      );

      final editor = _editor(db, doc.id);
      await editor.loadExisting();
      editor.updateBbox(
        0,
        const BoundingBox(x: 0.3, y: 0.1, w: 0.2, h: 0.02),
      ); // an edit
      await editor.flush();
      editor.dispose();

      final row = (await fields.watchFields(doc.id).first).single;
      expect(row.id, id);
      expect(
        autoTodayOf(row.optionsJson),
        isTrue,
        reason: 'the signature-date link must survive reopen + edit',
      );
      await db.close();
    },
  );

  test(
    'editor sessions teach detection: kept, deleted, retyped, placed',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final doc = await DocumentRepository(db).createDocument('Form');
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: 0, imagePath: 'pages/u/p.jpg');
      final hints = FieldHintRepository(db);
      final editor = _editor(db, doc.id);
      await editor.loadExisting();

      // Simulate a detection session's results.
      EditableField det(FieldType t, String label) => editor.addManualField(
        type: t,
        pageIndex: 0,
        bbox: const BoundingBox(x: 0.1, y: 0.1, w: 0.2, h: 0.02),
        label: label,
      )..detected = true;
      det(FieldType.text, 'residing at'); // kept
      final wrong = det(FieldType.date, 'aged'); // retyped to text
      final junk = det(FieldType.text, 'clause'); // deleted
      editor.changeType(editor.debugFields.indexOf(wrong), FieldType.text);
      editor.removeField(junk);
      editor.commitLearning();
      editor.commitLearning(); // idempotent
      await editor.flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      editor.dispose();

      final learned = await hints.load();
      final rows = {
        for (final r in await db.select(db.fieldHints).get())
          '${r.phrase}/${r.type}': (r.accepted, r.rejected),
      };
      expect(rows['residing at/text'], (1, 0));
      expect(rows['aged/date'], (0, 1));
      expect(rows['aged/text'], (1, 0));
      expect(rows['clause/text'], (0, 1));
      expect(
        learned.preferredType('aged'),
        isNull,
        reason: 'one lesson is not enough to change behaviour',
      );
      await db.close();
    },
  );

  test('a field\'s saved options carry every setting', () {
    final date = EditableField(
      type: FieldType.date,
      bbox: const BoundingBox(x: 0, y: 0, w: 0.1, h: 0.02),
      label: 'Date',
      pageIndex: 0,
      autoToday: true,
    );
    expect(
      autoTodayOf(date.optionsJson),
      isTrue,
      reason: 'detected signature dates must be stored as auto-today',
    );
    final radio = EditableField(
      type: FieldType.radio,
      bbox: const BoundingBox(x: 0, y: 0, w: 0.02, h: 0.02),
      label: '',
      pageIndex: 0,
      radioGroup: 'g1',
    );
    expect(radioGroupOf(radio.optionsJson), 'g1');
  });
}
