// Send → "Password-protect": a copy that needs the password to open, made
// with the OS on iOS (PDFKit, over a channel) and AES-256 elsewhere. The
// original stays open; a short password is refused; on iOS a fillable form
// with radio buttons isn't offered (PDFKit breaks radio groups).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/pdf_password_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String form;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('sss_pw_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    // A one-page form with a filled text field.
    final doc = PdfDocument();
    final page = doc.pages.add();
    doc.form.fields.add(
      PdfTextBoxField(
        page,
        'name',
        const Rect.fromLTWH(50, 50, 200, 20),
        text: 'Priya Raman',
      ),
    );
    form = '${root.path}/form.pdf';
    File(form).writeAsBytesSync(await doc.save());
    doc.dispose();
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('AES-256 copy: the password opens it, fields kept', () async {
    final out = await PdfPasswordService(
      useOsEncryption: false,
    ).protect(form, 'secret1');
    final bytes = File(out).readAsBytesSync();
    expect(
      () => PdfDocument(inputBytes: bytes),
      throwsA(anything),
      reason: 'no password, no entry',
    );
    final opened = PdfDocument(inputBytes: bytes, password: 'secret1');
    expect(
      opened.security.algorithm,
      PdfEncryptionAlgorithm.aesx256BitRevision6,
    );
    final field = opened.form.fields[0] as PdfTextBoxField;
    expect(field.text, 'Priya Raman');
    opened.dispose();
    // The original is untouched.
    PdfDocument(inputBytes: File(form).readAsBytesSync()).dispose();
  });

  test('iOS: PDFKit does the writing, over the channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.scansignsend/pdf_password'),
          (call) async {
            calls.add(call);
            File(call.arguments['output'] as String).writeAsStringSync('x');
            return true;
          },
        );
    final out = await PdfPasswordService(
      useOsEncryption: true,
    ).protect(form, 'secret1');
    expect(calls.single.method, 'protect');
    expect(calls.single.arguments, {
      'input': form,
      'output': out,
      'password': 'secret1',
    });
  });

  test('a short password is refused', () {
    expect(
      PdfPasswordService(useOsEncryption: false).protect(form, '12345'),
      throwsArgumentError,
    );
  });

  test('iOS leaves out fillable forms with radio buttons only', () {
    final ios = PdfPasswordService(useOsEncryption: true);
    final other = PdfPasswordService(useOsEncryption: false);
    expect(ios.canProtect(fillable: true, hasRadios: true), isFalse);
    expect(ios.canProtect(fillable: true, hasRadios: false), isTrue);
    expect(ios.canProtect(fillable: false, hasRadios: true), isTrue);
    expect(other.canProtect(fillable: true, hasRadios: true), isTrue);
  });
}
