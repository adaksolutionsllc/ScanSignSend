import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../models/document_category.dart';
import 'category_hints.dart';
import 'document_repository.dart';
import 'document_titler.dart';
import 'import_service.dart';
import 'keyword_categoriser.dart';
import 'on_device_ai_service.dart';
import 'page_layout_service.dart';

final documentSorterProvider = Provider<DocumentSorter>(
  (ref) => DocumentSorter(
    docRepo: ref.watch(documentRepositoryProvider),
    pageRepo: ref.watch(pageRepositoryProvider),
    layouts: ref.watch(pageLayoutServiceProvider),
    hints: ref.watch(categoryHintRepositoryProvider),
    ai: ref.watch(onDeviceAiServiceProvider),
  ),
);

/// Which engine chose a category, for tests and the Library tip.
enum SortedBy { learned, model, keywords }

/// Names a new document from its content and sorts it into a category.
///
/// Order of authority: the user's own choice (never overridden), then what
/// their past corrections taught ([LearnedCategoryHints]), then the phone's
/// language model where there is one, then keyword rules. Any of them may say
/// "not sure", which leaves the document Uncategorised.
class DocumentSorter {
  DocumentSorter({
    required this.docRepo,
    required this.pageRepo,
    required this.layouts,
    required this.hints,
    required this.ai,
  });

  final DocumentRepository docRepo;
  final PageRepository pageRepo;
  final PageLayoutService layouts;
  final CategoryHintRepository hints;
  final OnDeviceAiService ai;

  /// SharedPreferences: Settings → "Sort documents automatically".
  static const enabledKey = 'sort_documents_automatically';

  /// SharedPreferences: the one-time Library tip about keyword sorting.
  static const keywordTipShownKey = 'keyword_sorting_tip_shown';

  /// SharedPreferences: existing documents were sorted once after upgrade.
  static const backfilledKey = 'categories_backfilled_v1';

  /// After an upgrade only this many of the newest documents go to the model
  /// (Android limits each app's model use); the rest are sorted by keywords.
  static const backfillModelLimit = 20;

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// A document was just created by scanning or importing. Reads page 1 and,
  /// when the document is a scan or a photo, names it from its title (an
  /// imported PDF keeps its file name); then sorts it.
  ///
  /// [nameFor] turns a title found on the page into the document name (it
  /// adds the date), resolved by the caller before any await. Never throws:
  /// naming and sorting are conveniences and must not break saving.
  Future<SortedBy?> sortNew(
    int docId, {
    required String Function(String title) nameFor,
  }) async {
    try {
      final pages = await pageRepo.pagesOf(docId);
      if (pages.isEmpty) return null;
      final first = pages.first.imagePath;
      final (layout, text) = await layouts.textOnly(first);

      var doc = await docRepo.getById(docId);
      if (doc == null) return null;
      final isPdf = first.contains('#page=');
      final found = DocumentTitler.titleFrom(layout);
      // Re-read right before writing: the user may have renamed it meanwhile.
      if (!isPdf &&
          found != null &&
          !doc.titleEdited &&
          looksGenerated(doc.title)) {
        await docRepo.updateDocument(
          DocumentsCompanion(id: Value(docId), title: Value(nameFor(found))),
        );
      }
      // Page 1's text makes a plain-saved scan searchable too. Never replace
      // text detection stored, or the imported-form marker.
      if (doc.ocrText.isEmpty && text.trim().isNotEmpty) {
        await docRepo.updateDocument(
          DocumentsCompanion(id: Value(docId), ocrText: Value(text)),
        );
      }

      doc = await docRepo.getById(docId);
      if (doc == null) return null;
      return _sort(doc, found ?? doc.title, text);
    } catch (_) {
      return null;
    }
  }

  /// Field detection has read every page. A document still Uncategorised gets
  /// another try with the fuller text.
  Future<SortedBy?> afterDetection(int docId) async {
    try {
      final doc = await docRepo.getById(docId);
      if (doc == null || doc.category != null) return null;
      return _sort(doc, doc.title, doc.ocrText);
    } catch (_) {
      return null;
    }
  }

  /// Once, after upgrading to a build with categories: sorts the documents
  /// that existed before, from the text already stored for them.
  Future<void> backfillOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(backfilledKey) ?? false) return;
      final docs = await docRepo.watchAll().first;
      var modelUses = 0;
      for (final doc in docs) {
        if (doc.category != null || doc.categoryManual) continue;
        final useModel = modelUses < backfillModelLimit;
        final by = await _sort(doc, doc.title, doc.ocrText, useModel: useModel);
        if (by == SortedBy.model) modelUses++;
      }
      await prefs.setBool(backfilledKey, true);
    } catch (_) {
      // Tried again on the next launch.
    }
  }

  Future<SortedBy?> _sort(
    Document doc,
    String title,
    String text, {
    bool useModel = true,
  }) async {
    if (doc.categoryManual || doc.category != null) return null;
    if (!await isEnabled()) return null;
    if (text == ImportService.formFieldsSentinel) text = '';

    final (key, by) = await categorise(title, text, useModel: useModel);
    if (key == null) return null;

    // The user may have chosen one while we were thinking.
    final now = await docRepo.getById(doc.id);
    if (now == null || now.categoryManual || now.category != null) return null;
    await docRepo.updateDocument(
      DocumentsCompanion(id: Value(doc.id), category: Value(key)),
    );
    return by;
  }

  /// The category for a document with this [title] and [text], and which
  /// engine chose it; (null, null) when nobody is sure.
  Future<(String?, SortedBy?)> categorise(
    String title,
    String text, {
    bool useModel = true,
  }) async {
    final learned = (await hints.load()).categoryFor(title);
    if (learned != null) return (learned, SortedBy.learned);
    if (title.trim().isEmpty && text.trim().isEmpty) return (null, null);

    if (useModel) {
      final status = await ai.status();
      if (status == OnDeviceAiStatus.available) {
        final picked = await ai.classify(title, text);
        if (picked != null) return (picked.key, SortedBy.model);
        // The model said "not sure" or failed: keywords may still be sure.
      }
    }
    final byKeywords = KeywordCategoriser.classify(title, text);
    return (byKeywords?.key, byKeywords == null ? null : SortedBy.keywords);
  }

  /// The user picked [to] (null = Uncategorised) for [doc] by hand. From now
  /// on automatic sorting leaves it alone, and the move teaches the hints.
  Future<void> setByUser(Document doc, String? to) async {
    await docRepo.updateDocument(
      DocumentsCompanion(
        id: Value(doc.id),
        category: Value(to),
        categoryManual: const Value(true),
      ),
    );
    await hints.recordMove(
      doc.title,
      from: doc.categoryManual ? null : doc.category,
      to: to,
    );
  }

  /// True for names nobody chose: the scan default ("Document 2026-10-23")
  /// and camera or messaging file names ("IMG_2041", "PXL_20261023_1012",
  /// "WhatsApp Image 2026-10-23 at 10.12"). A photo named "Lease" keeps it.
  static bool looksGenerated(String title) {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return true;
    if (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(t)) return true;
    if (RegExp(r'^[\d\s_\-.]+$').hasMatch(t)) return true;
    return RegExp(
      r'^(img|pxl|dsc|dscn|dcim|photo|image|scan|screenshot|whatsapp image|signal)[\s_\-]?\d',
    ).hasMatch(t);
  }

  /// Built-in category keys, in display order.
  static List<String> get builtInKeys => [
    for (final c in BuiltInCategory.values) c.key,
  ];
}
