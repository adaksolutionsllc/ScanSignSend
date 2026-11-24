// Makes the data of a real user on an OLD version, for the upgrade check.
//
// tool/verify/upgrade_seed.sh copies this file into a worktree of an old tag
// (v1.0.0-build8, v1.2.0-build18, …) and runs it there, so it is compiled
// against that version's code. It uses only APIs that are the same from 1.0.0
// on: the import service (through a fake file picker), the repositories, the
// press and fillable-export services, and the template service. The script
// then saves the app's data folder as the fixture for that version.
//
// Everything is fictional. The W-4 is a blank IRS form from test/fixtures.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/fillable_form_export_service.dart';
import 'package:scan_sign_send/core/services/import_service.dart';
import 'package:scan_sign_send/core/services/press_service.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/core/services/signature_repository.dart';
import 'package:scan_sign_send/core/services/template_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Hands the import service one file, as the system picker would.
class _Picker extends FilePicker with MockPlatformInterfaceMixin {
  String? next;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final path = next!;
    return FilePickerResult([
      PlatformFile(
        path: path,
        name: p.basename(path),
        size: File(path).lengthSync(),
      ),
    ]);
  }

  @override
  Future<bool?> clearTemporaryFiles() async => true;
}

const _cert = PressCertificateStrings(
  title: 'Signing record',
  documentLabel: 'Document',
  signedOnLabel: 'Signed on',
  methodLabel: 'Method',
  methodValue: 'Drawn on device',
  noteLabel: 'Note',
  noteValue: 'Upgrade fixture',
  dateFormat: 'yyyy-MM-dd',
  localeName: 'en',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed an old version', (tester) async {
    // A user who finished the first-run pages long ago.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    // The root, not the Library: from 1.2.0 "What's new" can show first.
    app.main();
    await _waitFor(tester, find.byType(app.ScanSignSendApp));
    await tester.pump(const Duration(seconds: 2));
    final c = ProviderScope.containerOf(
      tester.element(find.byType(app.ScanSignSendApp)),
    );

    await c
        .read(profileRepositoryProvider)
        .update(
          const UserProfileCompanion(
            fullName: Value('Asha K Rao'),
            email: Value('asha@example.com'),
            phone: Value('555-0100'),
            address: Value('12 Elm Street'),
            city: Value('Springfield'),
            state: Value('IL'),
            zip: Value('62701'),
            isPurchased: Value(true),
          ),
        );

    final docsDir = await getApplicationDocumentsDirectory();
    final sigDir = Directory(p.join(docsDir.path, 'signatures'));
    await sigDir.create(recursive: true);
    final sigFile = File(p.join(sigDir.path, 'seed-signature.png'));
    await sigFile.writeAsBytes(await _signaturePng());
    final sigPath = PathResolver.toStorable(sigFile.path);
    final sigId = await c
        .read(signatureRepositoryProvider)
        .addSignature(imagePath: sigPath, label: 'Signature', isDefault: true);

    // The script puts the blank W-4 in the temp folder on request.
    final tmp = await getTemporaryDirectory();
    final w4 = File(p.join(tmp.path, 'fw4.pdf'));
    print('NEED:w4');
    final until = DateTime.now().add(const Duration(seconds: 60));
    while (!w4.existsSync() || w4.lengthSync() == 0) {
      if (DateTime.now().isAfter(until)) fail('fw4.pdf was not provided');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );

    final picker = _Picker();
    FilePicker.platform = picker;
    final importer = c.read(importServiceProvider);
    final fields = c.read(fieldRepositoryProvider);

    Future<Document> import(String name, {String from = ''}) async {
      final src = from.isEmpty ? w4.path : from;
      final copy = File(p.join(tmp.path, name));
      await File(src).copy(copy.path);
      picker.next = copy.path;
      final doc = await tester.runAsync(importer.pickAndImport);
      return doc!;
    }

    // Fill the first text fields and the first checkbox, like a user.
    Future<void> fill(int docId, List<String> values) async {
      final all = await fields.watchFields(docId).first;
      final texts = all.where((f) => f.type == 'text').toList();
      for (var i = 0; i < values.length && i < texts.length; i++) {
        await fields.updateField(
          FieldsCompanion(
            id: Value(texts[i].id),
            value: Value(values[i]),
            isFilled: const Value(true),
          ),
        );
      }
      final box = all.where((f) => f.type == 'checkbox').firstOrNull;
      if (box != null) {
        await fields.updateField(
          FieldsCompanion(
            id: Value(box.id),
            isChecked: const Value(true),
            isFilled: const Value(true),
          ),
        );
      }
    }

    Future<void> sign(int docId) => fields.addField(
      FieldsCompanion.insert(
        documentId: docId,
        pageIndex: 0,
        type: 'signature',
        boundingBoxJson: '{"x":0.1,"y":0.85,"w":0.3,"h":0.05}',
        label: const Value('Signature'),
        value: Value(sigPath),
        signatureId: Value(sigId),
        isFilled: const Value(true),
      ),
    );

    // 1. Signed and flattened (locked).
    final pressed = await import('Upgrade W4 pressed.pdf');
    await fill(pressed.id, ['Asha K', 'Rao', '12 Elm Street']);
    await sign(pressed.id);
    await tester.runAsync(
      () => c.read(pressServiceProvider).press(pressed.id, _cert),
    );

    // 2. A draft, part filled, with Tamil text.
    final draft = await import('Upgrade W4 draft.pdf');
    await fill(draft.id, ['ஆஷா', 'Rao']);

    // 3. Saved as a fillable PDF (stays editable).
    final fillable = await import('Upgrade W4 fillable.pdf');
    await fill(fillable.id, ['Asha K', 'Rao']);
    await tester.runAsync(
      () => c.read(fillableFormExportServiceProvider).export(fillable.id),
    );

    // 4. A photo page with fields the user drew, signed.
    final photo = File(p.join(tmp.path, 'Upgrade receipt photo.png'));
    await photo.writeAsBytes(await _pagePng());
    final scan = await import('Upgrade receipt photo.png', from: photo.path);
    await fields.addField(
      FieldsCompanion.insert(
        documentId: scan.id,
        pageIndex: 0,
        type: 'text',
        boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.5,"h":0.05}',
        label: const Value('Name'),
        value: const Value('Asha K Rao — ஆஷா'),
        isFilled: const Value(true),
      ),
    );
    await fields.addField(
      FieldsCompanion.insert(
        documentId: scan.id,
        pageIndex: 0,
        type: 'date',
        boundingBoxJson: '{"x":0.6,"y":0.1,"w":0.3,"h":0.05}',
        label: const Value('Date'),
        value: const Value('2026-01-15'),
        isFilled: const Value(true),
      ),
    );
    await sign(scan.id);

    // 5. A template made from the draft.
    await tester.runAsync(
      () => c.read(templateServiceProvider).createTemplate(draft.id),
    );

    print('SEED:done');
  });
}

Future<Uint8List> _signaturePng() => _png(400, 120, (canvas) {
  final paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke;
  final path = Path()..moveTo(10, 90);
  for (var x = 10.0; x < 390; x += 20) {
    path.quadraticBezierTo(x + 5, x.toInt().isEven ? 20 : 100, x + 20, 60);
  }
  canvas.drawPath(path, paint);
});

Future<Uint8List> _pagePng() => _png(850, 1100, (canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 850, 1100),
    Paint()..color = Colors.white,
  );
  final line = Paint()
    ..color = Colors.black
    ..strokeWidth = 2;
  for (var y = 150.0; y < 1000; y += 60) {
    canvas.drawLine(Offset(80, y), Offset(770, y), line);
  }
});

Future<Uint8List> _png(int w, int h, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<void> _waitFor(WidgetTester tester, Finder f, {int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}
