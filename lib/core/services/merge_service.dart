import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/document_model.dart';
import '../utils/path_resolver.dart';
import 'document_repository.dart';
import 'edge_check_service.dart';

final mergeServiceProvider = Provider<MergeService>(
  (ref) => MergeService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(fieldRepositoryProvider),
  ),
);

/// Renders pages of the PDF at [pdfPath] to JPEG files: page index → path.
typedef RenderPdfPages =
    Future<void> Function(String pdfPath, Map<int, String> destinations);

/// Merging documents into one, and copying or moving pages into a new one.
///
/// The new document gets its own copy of every page file, so it never
/// depends on the documents it came from: either can be edited, cropped or
/// deleted on its own. PDF pages become images (a document's pages are all
/// one kind, which is what the exports handle), and fields that came with
/// an imported PDF form become the app's own fields, still fillable.
class MergeService {
  MergeService(
    this._docRepo,
    this._pageRepo,
    this._fieldRepo, {
    RenderPdfPages? renderPdf,
  }) : _renderPdf = renderPdf ?? _renderWithPrinting;

  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;
  final FieldRepository _fieldRepo;
  final RenderPdfPages _renderPdf;

  /// A new draft with the pages of [docIds], in that order, and their
  /// fields (values kept) on the same pages. A completed document joins as
  /// the pages of its finished PDF, with no fields. The originals are left
  /// as they are. Returns the new document's id.
  Future<int> merge(List<int> docIds, {required String title}) async {
    final parts = <_Part>[];
    for (final (i, id) in docIds.indexed) {
      final doc = await _docRepo.getById(id);
      if (doc == null) continue;
      final pressed = doc.pressedPdfPath;
      if (doc.statusEnum == DocumentStatus.pressed &&
          pressed != null &&
          File(PathResolver.resolve(pressed)).existsSync()) {
        final count = await compute(
          _pdfPageCount,
          PathResolver.resolve(pressed),
        );
        parts.add(
          _Part(
            doc: doc,
            sources: [
              for (var n = 0; n < count; n++) _Source('$pressed#page=$n'),
            ],
            fields: const [],
            tag: 'm$i',
          ),
        );
        continue;
      }
      final pages = await _pageRepo.pagesOf(id);
      parts.add(
        _Part(
          doc: doc,
          sources: [
            for (final pg in pages)
              _Source(pg.imagePath, filter: pg.activeFilter),
          ],
          fields: await _fieldRepo.watchFields(id).first,
          tag: 'm$i',
        ),
      );
    }
    final firstText = parts.map((x) => x.doc.textSize).nonNulls.firstOrNull;
    final categories = parts.map((x) => x.doc.category).toSet();
    return _create(
      title: title,
      parts: parts,
      extra: DocumentsCompanion(
        ocrText: Value(
          parts.map((x) => x.doc.ocrText).where((t) => t.isNotEmpty).join('\n'),
        ),
        textSize: Value(firstText),
        // The same category everywhere carries over; a mix is for sorting.
        category: Value(categories.length == 1 ? categories.single : null),
      ),
    );
  }

  /// A new draft with the pages [pageIds] of document [docId], in page
  /// order, and the fields on them. [move] then removes them from [docId]
  /// (its other pages and their fields stay). Returns the new document's id.
  Future<int> extract(
    int docId,
    List<int> pageIds, {
    required String title,
    bool move = false,
  }) async {
    final doc = await _docRepo.getById(docId);
    if (doc == null) throw StateError('Document $docId not found');
    final pages = [
      for (final pg in await _pageRepo.pagesOf(docId))
        if (pageIds.contains(pg.id)) pg,
    ];
    if (pages.isEmpty) throw StateError('No pages to extract');
    final positions = {for (final pg in pages) pg.pageIndex};
    final fields = await _fieldRepo.watchFields(docId).first;
    final newId = await _create(
      title: title,
      parts: [
        _Part(
          doc: doc,
          sources: [
            for (final pg in pages)
              _Source(pg.imagePath, filter: pg.activeFilter),
          ],
          fields: [
            for (final f in fields)
              if (positions.contains(f.pageIndex)) f,
          ],
          // Positions renumber 0..n-1 in page order.
          pageMap: {for (final (i, pg) in pages.indexed) pg.pageIndex: i},
          tag: '',
        ),
      ],
      extra: DocumentsCompanion(
        textSize: Value(doc.textSize),
        category: Value(doc.category),
      ),
    );
    if (move) {
      for (final pg in pages) {
        await _pageRepo.deletePage(pg.id);
      }
    }
    return newId;
  }

  /// Writes every part's pages into a new `pages/<uuid>/` folder, then
  /// creates the document, its pages and fields in one transaction.
  Future<int> _create({
    required String title,
    required List<_Part> parts,
    required DocumentsCompanion extra,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pages', const Uuid().v4()));
    await dir.create(recursive: true);
    final all = [for (final part in parts) ...part.sources];
    final dests = [
      for (var i = 0; i < all.length; i++) p.join(dir.path, 'page_$i.jpg'),
    ];
    try {
      final byPdf = <String, Map<int, String>>{};
      for (final (i, src) in all.indexed) {
        final stored = src.stored;
        if (stored.contains('#page=')) {
          final pdf = PathResolver.resolve(stored.split('#page=').first);
          final n = int.tryParse(stored.split('#page=').last) ?? 0;
          (byPdf[pdf] ??= {})[n] = dests[i];
        } else {
          await File(PathResolver.resolve(stored)).copy(dests[i]);
        }
      }
      for (final e in byPdf.entries) {
        await _renderPdf(e.key, e.value);
      }
    } catch (_) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }

    return _docRepo.transaction(() async {
      final doc = await _docRepo.createDocument(title);
      await _docRepo.updateDocument(
        extra.copyWith(
          id: Value(doc.id),
          pageCount: Value(all.length),
          updatedAt: Value(DateTime.now()),
        ),
      );
      var offset = 0;
      for (final part in parts) {
        for (final (i, src) in part.sources.indexed) {
          final id = await _pageRepo.addPage(
            documentId: doc.id,
            pageIndex: offset + i,
            imagePath: dests[offset + i],
          );
          await _pageRepo.updatePage(
            PagesCompanion(id: Value(id), activeFilter: Value(src.filter)),
          );
        }
        for (final f in part.fields) {
          final at = part.pageMap?[f.pageIndex] ?? f.pageIndex;
          await _fieldRepo.addField(
            FieldsCompanion.insert(
              documentId: doc.id,
              pageIndex: offset + at,
              type: f.type,
              boundingBoxJson: f.boundingBoxJson,
              label: Value(f.label),
              value: Value(f.value),
              isChecked: Value(f.isChecked),
              isFilled: Value(f.isFilled),
              signatureId: Value(f.signatureId),
              isRequired: Value(f.isRequired),
              // The page is now an image: the form's field is the app's own.
              sourceKind: const Value('app'),
              optionsJson: Value(_retag(f.optionsJson, part.tag)),
            ),
          );
        }
        offset += part.sources.length;
      }
      return doc.id;
    });
  }

  /// Radio groups from different documents could share a name, and the
  /// fillable export would join them into one: give each part's its own.
  static String? _retag(String? optionsJson, String tag) {
    if (tag.isEmpty || optionsJson == null) return optionsJson;
    try {
      final m = Map<String, Object?>.from(jsonDecode(optionsJson) as Map);
      final group = m['group'];
      if (group is! String) return optionsJson;
      m['group'] = '$group·$tag';
      return jsonEncode(m);
    } catch (_) {
      return optionsJson;
    }
  }
}

class _Part {
  _Part({
    required this.doc,
    required this.sources,
    required this.fields,
    required this.tag,
    this.pageMap,
  });
  final Document doc;
  final List<_Source> sources;
  final List<Field> fields;

  /// Suffix for this part's radio groups ('' keeps them).
  final String tag;

  /// Old page position → position within this part, when not all pages
  /// come along.
  final Map<int, int>? pageMap;
}

class _Source {
  _Source(this.stored, {this.filter = 'original'});

  /// A stored page path: an image, or `<pdf>#page=N`.
  final String stored;

  /// The page's Review filter. A finished PDF already has it applied.
  final String filter;
}

Future<void> _renderWithPrinting(
  String pdfPath,
  Map<int, String> destinations,
) async {
  final bytes = await File(pdfPath).readAsBytes();
  final wanted = destinations.keys.toList()..sort();
  var i = 0;
  await for (final raster in Printing.raster(
    bytes,
    pages: wanted,
    dpi: EdgeCheckService.pdfPageDpi,
  )) {
    final png = await raster.toPng();
    await compute(_pngToJpeg, (png, destinations[wanted[i]]!));
    i++;
  }
  if (i != wanted.length) {
    throw StateError('PDF rendered $i of ${wanted.length} pages');
  }
}

int _pdfPageCount(String path) {
  final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

void _pngToJpeg((Uint8List, String) args) {
  final (png, dest) = args;
  final image = img.decodePng(png);
  if (image == null) throw const FormatException('Undecodable page');
  File(dest).writeAsBytesSync(img.encodeJpg(image, quality: 90));
}
