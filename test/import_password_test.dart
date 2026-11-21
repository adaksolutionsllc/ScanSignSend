// Opening a password-protected PDF: the app asks for the password (again
// after a wrong one), keeps its copy without the password, and the form's
// fields come in ready to fill. A file protected on an iPhone (PDFKit,
// AES-128) and one protected on Android (AES-256) both open. Cancel leaves
// nothing behind.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/import_service.dart';
import 'package:scan_sign_send/core/services/opened_file_service.dart';
import 'package:scan_sign_send/core/services/pdf_password_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase db;
  late DocumentRepository docs;
  late ImportService importer;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sss_import_pw_');
    PathResolver.debugSetDocsDir(root);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = DocumentRepository(db);
    importer = ImportService(docs, PageRepository(db), FieldRepository(db));
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  /// [source] as a file opened from another app: in its own temporary
  /// folder, which the import deletes.
  OpenedFile opened(String source) {
    final dir = Directory(p.join(root.path, 'inbox', '${source.hashCode}'))
      ..createSync(recursive: true);
    final copy = File(source).copySync(p.join(dir.path, 'form.pdf'));
    return OpenedFile(path: copy.path, name: 'W-4.pdf');
  }

  /// Answers the prompts in turn and records whether each was a retry.
  PasswordPrompt answers(List<String?> replies, List<bool> retries) =>
      ({required bool retry}) async {
        retries.add(retry);
        return replies.removeAt(0);
      };

  test('protected on an iPhone: wrong, then right password', () async {
    final retries = <bool>[];
    final doc = await importer.importOpened([
      opened('test/fixtures/pdfkit_protected_form.pdf'),
    ], askPassword: answers(['nope', 'secret1'], retries));

    expect(retries, [false, true]);
    expect(doc!.hasFormFields, isTrue);
    final fields = await FieldRepository(db).watchFields(doc.id).first;
    expect(
      fields.map((f) => f.value),
      containsAll(['Priya Raman', '21/11/2026']),
    );
    // PDFKit's widgets don't name their page; they still land where they
    // were: "Full name" was drawn at 10% from the top, 10% from the left.
    final name = BoundingBox.fromJsonString(
      fields.firstWhere((f) => f.value == 'Priya Raman').boundingBoxJson,
    );
    expect(name.x, closeTo(0.1, 0.01));
    expect(name.y, closeTo(0.1, 0.01));
    // The app's copy opens without the password.
    final page = (await PageRepository(db).pagesOf(doc.id)).first;
    final stored = PathResolver.resolve(page.imagePath.split('#page=').first);
    PdfDocument(inputBytes: File(stored).readAsBytesSync()).dispose();
  });

  test('protected on Android (AES-256) opens too', () async {
    final source = PdfDocument();
    source.pages.add();
    final plain = p.join(root.path, 'plain.pdf');
    File(plain).writeAsBytesSync(await source.save());
    source.dispose();
    final locked = await PdfPasswordService(
      useOsEncryption: false,
    ).protect(plain, 'secret1');

    final doc = await importer.importOpened([
      opened(locked),
    ], askPassword: answers(['secret1'], []));
    expect(doc!.pageCount, 1);
  });

  test('cancel: no document, no copy left', () async {
    final doc = await importer.importOpened([
      opened('test/fixtures/pdfkit_protected_form.pdf'),
    ], askPassword: answers([null], []));
    expect(doc, isNull);
    expect(await docs.watchAll().first, isEmpty);
    final copies = Directory(p.join(root.path, 'pages'));
    expect(
      copies.existsSync() ? copies.listSync(recursive: true) : const [],
      isEmpty,
    );
  });

  test('an unprotected PDF never asks', () async {
    final source = PdfDocument();
    source.pages.add();
    final plain = p.join(root.path, 'plain.pdf');
    File(plain).writeAsBytesSync(await source.save());
    source.dispose();
    final retries = <bool>[];
    final doc = await importer.importOpened([
      opened(plain),
    ], askPassword: answers([], retries));
    expect(doc, isNotNull);
    expect(retries, isEmpty);
  });
}
