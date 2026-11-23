import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../utils/path_resolver.dart';
import 'document_edges.dart';
import 'document_repository.dart';
import 'import_service.dart';
import 'page_layout_service.dart';
import 'page_raster_service.dart';

final edgeCheckServiceProvider = Provider<EdgeCheckService>(
  (ref) => EdgeCheckService(
    ref.watch(documentRepositoryProvider),
    ref.watch(pageRepositoryProvider),
    ref.watch(pageRasterServiceProvider),
  ),
);

/// A page whose document edges can be improved, with the corners found.
class EdgeCandidate {
  const EdgeCandidate({
    required this.pageId,
    required this.imagePath,
    required this.quad,
  });

  final int pageId;

  /// Absolute path of an image of the page, for showing and cropping.
  final String imagePath;

  final EdgeQuad quad;
}

/// Reports work done on a long job: [done] of [total] pages.
typedef PageProgress = void Function(int done, int total);

/// True once the user has tapped Skip on a long job.
typedef ShouldStop = bool Function();

/// A page is about to start, or has finished (checkpoints, plan 1.3.2).
typedef PageEvent = Future<void> Function(int pageId);

/// Thrown inside a job the user skipped.
class _Stopped implements Exception {
  const _Stopped();
}

/// Thrown inside a job the user paused: unlike [_Stopped], the pages
/// written so far stay for the resume.
class _Held implements Exception {
  const _Held();
}

/// Edge and corner correction for pages that did not come from the camera
/// scanner (which crops by itself): picked or opened photos, and PDFs that
/// are only photos of paper.
///
/// It stays out of the way when nothing needs fixing. A page is offered only
/// when a document was found in it and it doesn't already fill the image. A
/// PDF is looked at only when every page is a bare image (no text layer, no
/// form fields): a typed or exported PDF is already clean, and turning it
/// into images would lose its text.
///
/// Corners come from Apple's Vision framework on iOS
/// (`com.scansignsend/edges`, EdgeDetectionPlugin.swift) and from
/// [detectDocumentEdges] everywhere else, or when Vision fails.
class EdgeCheckService {
  EdgeCheckService(this._docRepo, this._pageRepo, this._raster);

  final DocumentRepository _docRepo;
  final PageRepository _pageRepo;

  /// The app's one renderer: sorting renders the same new page at the same
  /// moment, and only a shared instance renders it once.
  final PageRasterService _raster;

  static const _channel = MethodChannel('com.scansignsend/edges');

  /// PDF pages turned into images are rendered at this resolution: sharper
  /// than the on-screen preview, since the result is the page itself.
  static const pdfPageDpi = 200.0;

  /// How long one page takes on this phone, learned from past checks
  /// (SharedPreferences, milliseconds). Until then, a first guess.
  static const checkMsKey = 'edge_check_ms_per_page';
  static const straightenMsKey = 'edge_straighten_ms_per_page';
  static const _firstGuessMs = {checkMsKey: 1500.0, straightenMsKey: 4000.0};

  /// The time the app needs to check and straighten [pages] (the user's own
  /// time on each page not included). Rough: it comes from this phone's
  /// past checks, or a first guess before any.
  Future<Duration> estimateFor(List<Page> pages) async {
    final check = await _msPerPage(checkMsKey);
    final straighten = await _msPerPage(straightenMsKey);
    return Duration(
      milliseconds: (pages.length * (check + straighten)).round(),
    );
  }

  static Future<double> _msPerPage(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(key) ?? _firstGuessMs[key]!;
    } catch (_) {
      return _firstGuessMs[key]!;
    }
  }

  /// Keeps a running average, so one slow or fast run doesn't swing it.
  static Future<void> _learn(String key, Duration took, int pages) async {
    if (pages < 1) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = took.inMilliseconds / pages;
      final before = prefs.getDouble(key);
      await prefs.setDouble(key, before == null ? now : (before + now) / 2);
    } catch (_) {}
  }

  /// Image-only answers per PDF path: [checkablePages] and [candidatesFor]
  /// both need it, and on a long PDF it reads every page.
  final _imageOnly = <String, Future<bool>>{};

  /// The pages of document [docId] that the check would look at: all of
  /// them for photos and photo-only PDFs, none for anything else. The user
  /// is asked first when there are several, since each one takes time.
  /// Never throws.
  Future<List<Page>> checkablePages(int docId) async {
    try {
      final doc = await _docRepo.getById(docId);
      final pages = await _pageRepo.pagesOf(docId);
      if (doc == null || pages.isEmpty) return const [];
      final pdf = _sourcePdf(pages);
      if (pdf != null) {
        if (doc.ocrText == ImportService.formFieldsSentinel) return const [];
        if (!await (_imageOnly[pdf] ??= compute(isImageOnlyPdf, pdf))) {
          return const [];
        }
      }
      return pages;
    } catch (e) {
      debugPrint('EdgeCheckService: $e');
      return const [];
    }
  }

  /// The pages of document [docId] worth offering a corner fix, in order.
  /// Empty when none are, or when [stop] says the user skipped the check.
  /// Never throws: the check is a convenience.
  ///
  /// For a resumed job: pages in [known] were checked before (page id →
  /// corners worth cropping, or null) and are not checked again. [onStart]
  /// and [onPage] run around each page checked now, for the checkpoint.
  /// When [hold] says the job is paused, no new page starts and the pages
  /// found so far are returned.
  Future<List<EdgeCandidate>> candidatesFor(
    int docId, {
    PageProgress? onProgress,
    ShouldStop? stop,
    ShouldStop? hold,
    Map<int, List<double>?> known = const {},
    PageEvent? onStart,
    Future<void> Function(int pageId, EdgeQuad? quad)? onPage,
  }) async {
    try {
      final pages = await checkablePages(docId);
      final clock = Stopwatch()..start();
      final out = <EdgeCandidate>[];
      var checked = 0;
      for (final (i, page) in pages.indexed) {
        if (stop?.call() ?? false) return const [];
        if (hold?.call() ?? false) return out;
        onProgress?.call(i, pages.length);
        if (known.containsKey(page.id)) {
          if (EdgeQuad.fromList(known[page.id]) case final quad?) {
            final image = await _raster.imageFor(page.imagePath);
            out.add(
              EdgeCandidate(pageId: page.id, imagePath: image, quad: quad),
            );
          }
          continue;
        }
        await onStart?.call(page.id);
        final image = await _raster.imageFor(page.imagePath);
        final quad = await detect(image);
        final worth = quad != null && quad.worthCropping ? quad : null;
        if (worth != null) {
          out.add(
            EdgeCandidate(pageId: page.id, imagePath: image, quad: worth),
          );
        }
        checked++;
        await onPage?.call(page.id, worth);
      }
      await _learn(checkMsKey, clock.elapsed, checked);
      return out;
    } catch (e) {
      debugPrint('EdgeCheckService: $e');
      return const [];
    }
  }

  final _busy = <int, Completer<void>>{};

  /// Marks document [docId] as in the edge check, from import until the
  /// crops are applied or skipped. Reading every page's text waits for
  /// [whenDone]: it would slow the check, and read pages it is replacing.
  void begin(int docId) => _busy.putIfAbsent(docId, Completer<void>.new);

  /// Ends the check of [docId]. Safe to call more than once.
  void end(int docId) {
    final c = _busy.remove(docId);
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Completes when the check of [docId] has ended (at once if none runs).
  Future<void> whenDone(int docId) => _busy[docId]?.future ?? Future.value();

  /// The document's corners in the image at [path], or null if none found.
  Future<EdgeQuad?> detect(String path) async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        final v = await _channel.invokeListMethod<dynamic>('detect', {
          'path': path,
        });
        // Vision answered: trust it, including "no document".
        return EdgeQuad.fromList(v);
      } on MissingPluginException {
        // Tests: fall through to the Dart detector.
      } catch (e) {
        debugPrint('EdgeCheckService: Vision failed: $e');
      }
    }
    return compute(_detectFile, path);
  }

  /// Applies the user's choices: page id → corners to crop to. Pages left
  /// out (or "use whole image") stay as they are.
  ///
  /// A PDF-backed document is turned into one image per page at the same
  /// time, so that every page is the same kind and the exports never mix
  /// the two. Each page is rendered, cropped and saved in one pass, two at a
  /// time. [onProgress] counts the pages done.
  ///
  /// When [stop] says the user skipped, no new page starts: photo pages
  /// already cropped stay cropped, and a PDF stays as it was (all or none).
  /// Returns the ids of pages that could not be cropped.
  ///
  /// For a resumed job: pages in [done] were finished before. A PDF's pages
  /// are written as `page_<n>_<tag>.jpg` when [tag] is given, so a resume
  /// finds them; [discardStaged] removes them. When [hold] says the job is
  /// paused, no new page starts and the pages written so far stay.
  /// [onStart] and [onDone] run around each page, for the checkpoint.
  Future<List<int>> apply(
    int docId,
    Map<int, EdgeQuad> crops, {
    PageProgress? onProgress,
    ShouldStop? stop,
    ShouldStop? hold,
    Set<int> done = const {},
    String? tag,
    PageEvent? onStart,
    PageEvent? onDone,
  }) async {
    if (crops.isEmpty) return const [];
    final pages = await _pageRepo.pagesOf(docId);
    final pdf = _sourcePdf(pages);
    if (pdf != null) {
      return _pdfToImages(
        pdf,
        pages,
        crops,
        onProgress: onProgress,
        stop: stop,
        hold: hold,
        doneBefore: done,
        tag: tag,
        onStart: onStart,
        onDone: onDone,
      );
    }

    final todo = [
      for (final pg in pages)
        if (crops[pg.id] != null && !done.contains(pg.id)) pg,
    ];
    final total = todo.length + done.length;
    final failed = <int>[];
    var finished = done.length;
    final clock = Stopwatch()..start();
    onProgress?.call(finished, total);
    await runTwoAtATime(todo, (page) async {
      if ((stop?.call() ?? false) || (hold?.call() ?? false)) return;
      await onStart?.call(page.id);
      try {
        final src = PathResolver.resolve(page.imagePath);
        final dest = _newPagePath(p.dirname(src), page.pageIndex);
        await compute(_cropFile, (src, dest, crops[page.id]!.toList()));
        await _pageRepo.updatePage(
          PagesCompanion(
            id: Value(page.id),
            imagePath: Value(PathResolver.toStorable(dest)),
          ),
        );
        await _deleteQuietly(src);
      } catch (e) {
        debugPrint('EdgeCheckService: crop failed: $e');
        failed.add(page.id);
      }
      await onDone?.call(page.id);
      onProgress?.call(++finished, total);
    });
    if (!(stop?.call() ?? false) && !(hold?.call() ?? false)) {
      await _learn(straightenMsKey, clock.elapsed, todo.length);
    }
    return failed;
  }

  /// True when document [docId]'s pages are still an imported PDF's.
  Future<bool> isPdfBacked(int docId) async =>
      _sourcePdf(await _pageRepo.pagesOf(docId)) != null;

  /// Removes the page images a paused or stopped job with [tag] wrote for
  /// the PDF behind document [docId]. The PDF itself stays.
  Future<void> discardStaged(int docId, String tag) async {
    try {
      final pdf = _sourcePdf(await _pageRepo.pagesOf(docId));
      if (pdf == null) return;
      final dir = Directory(p.dirname(pdf));
      for (final f in dir.listSync().whereType<File>()) {
        final name = p.basename(f.path);
        if (name.startsWith('page_') &&
            (name.endsWith('_$tag.jpg') || name.endsWith('_$tag.jpg.part'))) {
          await _deleteQuietly(f.path);
        }
      }
    } catch (e) {
      debugPrint('EdgeCheckService: $e');
    }
  }

  /// A new name each time, so an image cached under the old path is never
  /// shown for the cropped page.
  static String _newPagePath(String dir, int pageIndex) =>
      p.join(dir, 'page_${pageIndex}_${const Uuid().v4().substring(0, 8)}.jpg');

  /// The imported PDF behind [pages], or null for image pages.
  static String? _sourcePdf(List<Page> pages) {
    for (final pg in pages) {
      if (pg.imagePath.contains('#page=')) {
        return PathResolver.resolve(pg.imagePath.split('#page=').first);
      }
    }
    return null;
  }

  /// Renders every page of the PDF at [pdfPath] to a JPEG, cropping those
  /// in [crops] on the way, and moves the pages over to the images: all of
  /// them or none, since a half-converted document would mix both kinds.
  /// Returns the ids of pages whose crop failed (kept whole).
  Future<List<int>> _pdfToImages(
    String pdfPath,
    List<Page> pages,
    Map<int, EdgeQuad> crops, {
    PageProgress? onProgress,
    ShouldStop? stop,
    ShouldStop? hold,
    Set<int> doneBefore = const {},
    String? tag,
    PageEvent? onStart,
    PageEvent? onDone,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final dir = p.dirname(pdfPath);
    String destFor(int index) => tag == null
        ? _newPagePath(dir, index)
        : p.join(dir, 'page_${index}_$tag.jpg');
    final written = <int, String>{};
    final todo = <Page>[];
    for (final page in pages) {
      final index = _pdfPageIndex(page.imagePath);
      final dest = destFor(index);
      if (doneBefore.contains(page.id) && File(dest).existsSync()) {
        written[index] = dest;
      } else {
        todo.add(page);
      }
    }
    final failed = <int>[];
    var done = written.length;
    final clock = Stopwatch()..start();
    onProgress?.call(done, pages.length);
    try {
      await runTwoAtATime(todo, (page) async {
        if (stop?.call() ?? false) throw const _Stopped();
        if (hold?.call() ?? false) throw const _Held();
        await onStart?.call(page.id);
        final index = _pdfPageIndex(page.imagePath);
        // One page per render: the renderer would otherwise hand over every
        // page of a long PDF at once, each a large image in memory.
        final raster = await Printing.raster(
          bytes,
          pages: [index],
          dpi: pdfPageDpi,
        ).first;
        final dest = destFor(index);
        // Written whole, then renamed: a file with its final name is never
        // half a page, even when the app stops while writing.
        final cropped = await compute(saveRender, (
          raster.pixels,
          raster.width,
          raster.height,
          crops[page.id]?.toList(),
          '$dest.part',
        ));
        await File('$dest.part').rename(dest);
        if (!cropped && crops[page.id] != null) failed.add(page.id);
        written[index] = dest;
        await onDone?.call(page.id);
        onProgress?.call(++done, pages.length);
      });
    } catch (e) {
      // Paused: the pages written stay for the resume.
      if (e is _Held) return const [];
      for (final f in written.values) {
        await _deleteQuietly(f);
      }
      if (e is _Stopped) return const [];
      rethrow;
    }
    await _docRepo.transaction(() async {
      for (final pg in pages) {
        await _pageRepo.updatePage(
          PagesCompanion(
            id: Value(pg.id),
            imagePath: Value(
              PathResolver.toStorable(written[_pdfPageIndex(pg.imagePath)]!),
            ),
          ),
        );
      }
    });
    await _raster.evict(PathResolver.toStorable(pdfPath));
    await _deleteQuietly(pdfPath);
    await _learn(straightenMsKey, clock.elapsed, todo.length);
    return failed;
  }

  static int _pdfPageIndex(String stored) =>
      int.tryParse(stored.split('#page=').last) ?? 0;

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

/// compute() entry: true when the PDF at [path] is only pictures — no page
/// has a text layer and there are no form fields. Unreadable → false.
bool isImageOnlyPdf(String path) {
  try {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    try {
      if (doc.form.fields.count > 0) return false;
      for (var i = 0; i < doc.pages.count; i++) {
        final layout = pdfTextLayoutOf(doc, i);
        if (layout != null && layout.$1.isNotEmpty) return false;
      }
      return true;
    } finally {
      doc.dispose();
    }
  } catch (_) {
    return false;
  }
}

EdgeQuad? _detectFile(String path) {
  final image = img.decodeImage(File(path).readAsBytesSync());
  if (image == null) return null;
  return detectDocumentEdges(image);
}

void _cropFile((String, String, List<double>) args) {
  final (src, dest, quad) = args;
  final image = img.decodeImage(File(src).readAsBytesSync());
  if (image == null) throw FileSystemException('Unreadable image', src);
  final out = cropToQuad(image, EdgeQuad.fromList(quad)!);
  File(dest).writeAsBytesSync(img.encodeJpg(out, quality: 90), flush: true);
}

/// compute() entry: a rendered PDF page (RGBA pixels) saved as a JPEG,
/// cropped to the corners when given. A crop that fails saves the whole
/// page instead. Returns whether the corners were applied.
@visibleForTesting
bool saveRender((Uint8List, int, int, List<double>?, String) args) {
  final (pixels, width, height, quad, dest) = args;
  final page = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    numChannels: 4,
  );
  var out = page;
  var cropped = false;
  if (quad != null) {
    try {
      out = cropToQuad(page, EdgeQuad.fromList(quad)!);
      cropped = true;
    } catch (_) {}
  }
  File(dest).writeAsBytesSync(img.encodeJpg(out, quality: 90), flush: true);
  return cropped;
}

/// Runs [job] on each of [items], at most two at a time: phones have at
/// least two fast cores, and each page holds a large image in memory. On the
/// first failure no new job starts; the one still running finishes (the
/// caller cleans up after both), then the failure is thrown.
@visibleForTesting
Future<void> runTwoAtATime<T>(
  List<T> items,
  Future<void> Function(T) job,
) async {
  Object? error;
  StackTrace? stack;
  Future<void> guarded(T item) async {
    try {
      await job(item);
    } catch (e, s) {
      error ??= e;
      stack ??= s;
    }
  }

  final running = <Future<void>>[];
  for (final item in items) {
    if (error != null) break;
    running.add(guarded(item));
    if (running.length >= 2) await running.removeAt(0);
  }
  await Future.wait(running);
  if (error case final e?) Error.throwWithStackTrace(e, stack!);
}
