import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'
    show Share, ShareResultStatus, XFile;

import '../../core/services/app_lock_provider.dart';

/// Opens the share sheet for the PDF at [pdfPath], named after the document.
///
/// The stored file's name is an internal id, which is what recipients used to
/// receive ("904aa0a1-833a-….pdf"); a copy named "[title].pdf" is shared
/// instead. Runs under [AppLockNotifier.whileExternal] so the share sheet
/// doesn't lock the app behind the user.
///
/// Returns false only when the user dismissed the sheet (Android can't tell
/// and always reports it as shared).
Future<bool> shareDocumentPdf({
  required AppLockNotifier lock,
  required String pdfPath,
  required String title,
  required String message,
  Rect? origin,
}) async {
  final named = await _namedCopy(pdfPath, title);
  final result = await lock.whileExternal(
    () => Share.shareXFiles(
      [XFile(named, mimeType: 'application/pdf')],
      subject: title,
      text: message,
      sharePositionOrigin: origin,
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}

/// A copy of [pdfPath] in the OS cache (never backed up) named after the
/// document. Only the latest shared copy is kept. Falls back to the original.
Future<String> _namedCopy(String pdfPath, String title) async {
  try {
    final safe = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty) return pdfPath;
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'share'));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final name = safe.length > 80 ? safe.substring(0, 80) : safe;
    return (await File(pdfPath).copy(p.join(dir.path, '$name.pdf'))).path;
  } catch (_) {
    return pdfPath;
  }
}
