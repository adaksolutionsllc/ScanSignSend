import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

final pdfPasswordServiceProvider = Provider<PdfPasswordService>(
  (ref) => PdfPasswordService(),
);

/// Send → "Password-protect": a copy of the PDF that asks for a password to
/// open. The copy is for sharing only; the document's own PDF stays as it
/// is, and the password is never stored.
///
/// iOS uses PDFKit, so the encryption is the operating system's. Android
/// uses Syncfusion (AES-256, revision 6, the ISO 32000-2 form).
class PdfPasswordService {
  PdfPasswordService({bool? useOsEncryption})
    : _useOs = useOsEncryption ?? (!kIsWeb && Platform.isIOS);

  final bool _useOs;

  static const _channel = MethodChannel('com.scansignsend/pdf_password');

  /// The shortest password accepted.
  static const minLength = 6;

  /// Whether a PDF can be protected here. PDFKit breaks radio-button groups
  /// when it writes a form, so on iOS a fillable PDF with radio buttons
  /// isn't offered.
  bool canProtect({required bool fillable, required bool hasRadios}) =>
      !(_useOs && fillable && hasRadios);

  /// Writes a password-protected copy of [pdfPath] to the OS cache and
  /// returns its path. Throws when it can't.
  Future<String> protect(String pdfPath, String password) async {
    if (password.length < minLength) {
      throw ArgumentError('Password too short');
    }
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'protected'));
    // Only the latest protected copy is kept.
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final out = p.join(dir.path, '${const Uuid().v4()}.pdf');
    if (_useOs) {
      final ok = await _channel.invokeMethod<bool>('protect', {
        'input': pdfPath,
        'output': out,
        'password': password,
      });
      if (ok != true) throw StateError('PDFKit could not write the PDF');
    } else {
      await compute(_encrypt, (pdfPath, out, password));
    }
    return out;
  }
}

Future<void> _encrypt((String, String, String) args) async {
  final (input, output, password) = args;
  final doc = PdfDocument(inputBytes: File(input).readAsBytesSync());
  try {
    doc.security
      ..algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6
      ..userPassword = password
      ..ownerPassword = password;
    File(output).writeAsBytesSync(await doc.save());
  } finally {
    doc.dispose();
  }
}
