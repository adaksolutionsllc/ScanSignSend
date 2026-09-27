// End-to-end: the real "Save as Fillable" export. Filled values must read as
// text on the form — no border box around them — while staying editable.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/fillable_form_export_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docsDir;
  late AppDatabase db;

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('sss_export_');
    PathResolver.debugSetDocsDir(docsDir);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docsDir.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    await docsDir.delete(recursive: true);
  });

  test('exported text fields have no border and keep their value', () async {
    final docs = DocumentRepository(db);
    final pages = PageRepository(db);
    final fields = FieldRepository(db);

    final pageDir = Directory(p.join(docsDir.path, 'pages', 'u'))
      ..createSync(recursive: true);
    final image = File(p.join(pageDir.path, 'page_0.jpg'))
      ..writeAsBytesSync(
        img.encodeJpg(
          img.Image(width: 620, height: 877)
            ..clear(img.ColorRgb8(255, 255, 255)),
        ),
      );

    final doc = await docs.createDocument('Form');
    await pages.addPage(
      documentId: doc.id,
      pageIndex: 0,
      imagePath: image.path,
    );
    for (final (label, type, value) in [
      ('residing at', FieldType.text, 'Virudhunagar'),
      ('born on', FieldType.date, '09/09/1985'),
    ]) {
      await fields.addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: type.name,
          boundingBoxJson: const BoundingBox(
            x: 0.2,
            y: 0.3,
            w: 0.4,
            h: 0.03,
          ).toJsonString(),
          label: Value(label),
          pdfFieldName: Value(label),
          value: Value(value),
          isFilled: const Value(true),
        ),
      );
    }
    await fields.addField(
      FieldsCompanion.insert(
        documentId: doc.id,
        pageIndex: 0,
        type: FieldType.checkbox.name,
        boundingBoxJson: const BoundingBox(
          x: 0.2,
          y: 0.5,
          w: 0.03,
          h: 0.02,
        ).toJsonString(),
      ),
    );

    final out = await FillableFormExportService(
      docs,
      pages,
      fields,
    ).export(doc.id);

    final pdf = PdfDocument(inputBytes: File(out).readAsBytesSync());
    final byName = {
      for (var i = 0; i < pdf.form.fields.count; i++)
        pdf.form.fields[i].name!: pdf.form.fields[i],
    };
    for (final (name, value) in [
      ('residing at', 'Virudhunagar'),
      ('born on', '09/09/1985'),
    ]) {
      final tb = byName[name] as PdfTextBoxField;
      expect(tb.text, value, reason: 'still a live, filled field');
      expect(tb.borderWidth, 0, reason: 'no border box around $name');
    }
    final cb = byName.values.whereType<PdfCheckBoxField>().single;
    expect(
      cb.borderWidth,
      greaterThan(0),
      reason: 'a checkbox keeps its outline so it can be seen',
    );
    pdf.dispose();
  });
}
