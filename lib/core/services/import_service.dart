import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'document_repository.dart';

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
  );
});

class ImportService {
  ImportService(this._docRepo, this._pageRepo);

  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final _uuid = const Uuid();

  /// Opens the system file picker and imports the selected file.
  /// Returns the created Document, or null if the user cancelled.
  Future<Document?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return null;

    final ext = p.extension(path).toLowerCase();
    if (ext == '.pdf') {
      return _importPdf(path, file.name);
    } else {
      return _importImage(path, file.name);
    }
  }

  Future<Document> _importImage(String imagePath, String name) async {
    final id = _uuid.v4();
    final dest = await _copyToAppDir(imagePath, id);
    final title = p.basenameWithoutExtension(name);
    final doc = await _docRepo.createDocument(title);
    await _pageRepo.addPage(
      documentId: doc.id,
      pageIndex: 0,
      imagePath: dest,
    );
    await _docRepo.updateDocument(DocumentsCompanion(
      id: Value(doc.id),
      pageCount: const Value(1),
      updatedAt: Value(DateTime.now()),
    ));
    return (await _docRepo.getById(doc.id))!;
  }

  /// Imports a PDF by copying it to app storage. Each page gets a DB row
  /// whose imagePath points to the PDF with a `#page=N` fragment so the
  /// viewer knows which page to display (0-indexed).
  Future<Document> _importPdf(String pdfPath, String name) async {
    final id = _uuid.v4();
    final dest = await _copyToAppDir(pdfPath, id);
    final title = p.basenameWithoutExtension(name);

    final bytes = await File(dest).readAsBytes();
    int pageCount;
    bool hasFormFields;
    try {
      final pdfDoc = PdfDocument(inputBytes: bytes);
      pageCount = pdfDoc.pages.count;
      // Check if the PDF already has AcroForm fields
      hasFormFields = pdfDoc.form.fields.count > 0;
      pdfDoc.dispose();
    } catch (e) {
      // Corrupt / encrypted / password-protected PDF — clean up the copy so we
      // don't leave an unreadable file behind, then surface a clear message.
      try {
        await Directory(p.dirname(dest)).delete(recursive: true);
      } catch (_) {}
      throw Exception(
          "This PDF couldn't be opened. It may be password-protected or damaged.");
    }
    if (pageCount == 0) {
      try {
        await Directory(p.dirname(dest)).delete(recursive: true);
      } catch (_) {}
      throw Exception('This PDF has no pages.');
    }

    final doc = await _docRepo.createDocument(title);
    for (var i = 0; i < pageCount; i++) {
      await _pageRepo.addPage(
        documentId: doc.id,
        pageIndex: i,
        imagePath: '$dest#page=$i',
      );
    }
    await _docRepo.updateDocument(DocumentsCompanion(
      id: Value(doc.id),
      pageCount: Value(pageCount),
      updatedAt: Value(DateTime.now()),
      // Use ocrText as a sentinel flag so field detection can skip auto-scan
      ocrText: hasFormFields ? const Value('__has_form_fields__') : const Value(''),
    ));
    return (await _docRepo.getById(doc.id))!;
  }

  Future<String> _copyToAppDir(String src, String id) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pages', id));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, p.basename(src));
    await File(src).copy(dest);
    return dest;
  }
}
