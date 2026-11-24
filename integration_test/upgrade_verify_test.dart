// Upgrade check: a user's data from an OLD version still works in this one.
//
// Run by `tool/verify/device_check.sh <device> --upgrade`, once per fixture
// in tool/verify/upgrade/versions.txt. The app is installed fresh; on NEED:upgrade
// the script restores the old version's data folder and settings (made by
// tool/verify/upgrade_seed.sh with that version's own code) and its
// expect.json. Then the app starts for the first time on that data, as after
// a store update: the database migrates, stored paths are rebased onto the
// new app folder, and the settings are read.
//
// Checked: every document, page, field value, signature, PDF and the profile
// is still there and the same; every file opens; the user is not sent
// through the first-run pages again; each document opens in the app; a
// draft can still be filled and flattened.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/press_service.dart';
import 'package:scan_sign_send/core/utils/path_resolver.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/library/presentation/library_screen.dart';
import 'package:scan_sign_send/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations.dart';
import 'package:scan_sign_send/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _from = String.fromEnvironment('FROM');

/// [_from] for screenshot names (a-z, 0-9 and _ only).
final _tag = _from.replaceAll(RegExp('[^a-z0-9]'), '_');

const _cert = PressCertificateStrings(
  title: 'Signing record',
  documentLabel: 'Document',
  signedOnLabel: 'Signed on',
  methodLabel: 'Method',
  methodValue: 'Drawn on device',
  noteLabel: 'Note',
  noteValue: 'Upgrade check',
  dateFormat: 'yyyy-MM-dd',
  localeName: 'en',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('data from $_from still works', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (_) async => 'upgrade-check',
    );

    // The script restores the old data before the app first opens it.
    final tmp = await getTemporaryDirectory();
    final ready = File(p.join(tmp.path, 'upgrade_ready'));
    _mark('NEED:upgrade');
    final until = DateTime.now().add(const Duration(seconds: 60));
    while (!ready.existsSync()) {
      if (DateTime.now().isAfter(until)) fail('the old data was not restored');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
    }
    final expected =
        jsonDecode(
              File(p.join(tmp.path, 'upgrade_expect.json')).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final oldDocs = (expected['documents'] as List)
        .cast<Map<String, dynamic>>();

    if (Platform.isAndroid) await tester.runAsync(_androidSettings);

    final testOnError = FlutterError.onError;
    final testErrorWidget = ErrorWidget.builder;
    app.main();
    await _waitFor(tester, find.byType(app.ScanSignSendApp));
    FlutterError.onError = testOnError;
    ErrorWidget.builder = testErrorWidget;

    // An updating user sees at most "What's new", never the first run again.
    final screen = await _waitForAny(tester, [
      find.byType(LibraryScreen),
      find.byType(OnboardingScreen),
    ]);
    if (screen == 1) {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      );
      await _waitFor(tester, find.text(l10n.tourWhatsNew));
      expect(
        find.text(l10n.onboardScanTitle),
        findsNothing,
        reason: 'the first-run pages showed again after the update',
      );
      await _capture(tester, '${_tag}_upgrade_whats_new');
      await tester.tap(find.text(l10n.tourGotIt));
      await _waitFor(tester, find.byType(LibraryScreen));
    }
    _mark('INFO:$_from: no first-run pages again');

    final ctx = tester.element(find.byType(LibraryScreen));
    final c = ProviderScope.containerOf(ctx);
    final db = c.read(appDatabaseProvider);

    // --- The data, compared with what the old version saved. ---
    final docs = await tester.runAsync(
      () => (db.select(
        db.documents,
      )..orderBy([(d) => OrderingTerm(expression: d.id)])).get(),
    );
    expect(
      docs!.map((d) => d.title).toList(),
      oldDocs.map((d) => d['title']).toList(),
      reason: 'documents',
    );
    var files = 0;
    for (final (i, doc) in docs.indexed) {
      final want = oldDocs[i];
      final why = '${doc.title} ($_from)';
      expect(doc.status, want['status'], reason: '$why status');
      expect(doc.isTemplate, want['isTemplate'], reason: '$why template');
      expect(doc.pageCount, want['pageCount'], reason: '$why page count');

      final pages = await tester.runAsync(
        () => (db.select(
          db.pages,
        )..where((t) => t.documentId.equals(doc.id))).get(),
      );
      expect(pages!.length, want['pages'], reason: '$why pages');
      for (final page in pages) {
        final path = PathResolver.resolve(page.imagePath);
        // An imported PDF's page is stored as "<pdf>#page=<n>": the PDF must
        // be there and have that page; any other page is an image.
        final parts = path.split('#page=');
        expect(
          File(parts.first).existsSync(),
          isTrue,
          reason: '$why page $path',
        );
        if (parts.length == 2) {
          final pdf = PdfDocument(
            inputBytes: File(parts.first).readAsBytesSync(),
          );
          expect(
            int.parse(parts.last),
            lessThan(pdf.pages.count),
            reason: '$why page $path',
          );
          pdf.dispose();
        } else {
          await tester.runAsync(() => _decodes(path));
        }
        files++;
      }

      final fields = await tester.runAsync(
        () => (db.select(
          db.fields,
        )..where((t) => t.documentId.equals(doc.id))).get(),
      );
      expect(fields!.length, want['fields'], reason: '$why fields');
      final values =
          fields
              .where((f) => f.value.isNotEmpty && f.type != 'signature')
              .map((f) => f.value)
              .toList()
            ..sort();
      expect(values, want['values'], reason: '$why values');
      expect(
        fields.where((f) => f.isChecked).length,
        want['checked'],
        reason: '$why ticks',
      );
      final signed = fields.where(
        (f) => f.type == 'signature' && f.value.isNotEmpty,
      );
      expect(signed.length, want['signed'], reason: '$why signed');
      for (final f in signed) {
        expect(
          File(PathResolver.resolve(f.value)).existsSync(),
          isTrue,
          reason: '$why signature image',
        );
      }

      for (final (has, stored) in [
        (want['pressedPdf'] as bool, doc.pressedPdfPath),
        (want['fillablePdf'] as bool, doc.fillablePdfPath),
      ]) {
        expect(stored != null, has, reason: '$why PDF kept');
        if (stored == null) continue;
        final path = PathResolver.resolve(stored);
        final pdf = PdfDocument(inputBytes: File(path).readAsBytesSync());
        expect(pdf.pages.count, greaterThan(0), reason: '$why PDF opens');
        pdf.dispose();
        files++;
      }
    }

    final sigs = await tester.runAsync(() => db.select(db.signatures).get());
    expect(sigs!.length, expected['signatures'], reason: 'signatures');
    for (final s in sigs) {
      await tester.runAsync(() => _decodes(PathResolver.resolve(s.imagePath)));
    }

    // The row the app shows: the lowest id (ProfileRepository). 1.0.0 could
    // leave duplicate rows (a first-launch race).
    final rows = await tester.runAsync(
      () => (db.select(
        db.userProfile,
      )..orderBy([(t) => OrderingTerm(expression: t.id)])).get(),
    );
    _mark('INFO:$_from: ${rows!.length} profile row(s)');
    final profile = rows.first;
    final old = expected['profile'] as Map<String, dynamic>;
    expect(profile.email, old['email'], reason: 'profile email');
    expect(profile.isPurchased, old['isPurchased'], reason: 'purchase flag');
    // 1.0.0 kept one full name (split on upgrade); from 1.2.0 first and last.
    final (first, last) = old.containsKey('firstName')
        ? (old['firstName'] as String, old['lastName'] as String)
        : AppDatabase.splitFullName(old['fullName'] as String);
    expect(
      (profile.firstName, profile.lastName),
      (first, last),
      reason: 'name',
    );
    _mark(
      'INFO:$_from: ${docs.length} documents, $files files and '
      '${sigs.length} signatures same and readable',
    );

    // --- Each document still opens in the app. ---
    await _capture(tester, '${_tag}_upgrade_library');
    final router = c.read(routerProvider);
    for (final doc in docs.where((d) => !d.isTemplate)) {
      final title = find.text(doc.title);
      // The grid builds only the cards on screen, and a tip or sheet may
      // cover it (Android: keyword sorting). A card not on screen opens by
      // the route its tap uses (LibraryScreen).
      if (title.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(title.hitTestable().first);
      } else {
        _mark('INFO:$_from: ${doc.title} opened by its route');
        router.push(
          (doc.status == 'pressed' ? AppRoutes.viewer : AppRoutes.fillMode)
              .replaceAll(':docId', '${doc.id}'),
        );
      }
      await _pause(tester, 2500);
      expect(find.byType(ErrorWidget), findsNothing, reason: doc.title);
      await _capture(tester, '${_tag}_upgrade_open_${doc.id}');
      router.go(AppRoutes.library);
      await _waitFor(tester, find.byType(LibraryScreen));
      await _pause(tester, 500);
    }
    _mark('INFO:$_from: every document opened');

    // --- A draft can still be filled and flattened. ---
    final draft = docs.where((d) => d.status == 'draft' && !d.isTemplate);
    if (draft.isNotEmpty) {
      final id = draft.first.id;
      final repo = c.read(fieldRepositoryProvider);
      final text = (await repo.watchFields(id).first).firstWhere(
        (f) => f.type == 'text',
      );
      await repo.updateField(
        FieldsCompanion(
          id: Value(text.id),
          value: const Value('Edited after update'),
          isFilled: const Value(true),
        ),
      );
      final out = await tester.runAsync(
        () => c.read(pressServiceProvider).press(id, _cert),
      );
      expect(File(out!).existsSync(), isTrue, reason: 'flattened after update');
      _mark('INFO:$_from: a draft was filled and flattened');
    }
  });
}

/// Android reads the settings file once, when the test process starts, so
/// the old version's file, restored after that, is not seen. The settings
/// must be in that file under the keys the new version reads: check that,
/// then hand them to the running app.
Future<void> _androidSettings() async {
  final docs = await getApplicationDocumentsDirectory(); // <data>/app_flutter
  final file = File(
    p.join(docs.parent.path, 'shared_prefs', 'FlutterSharedPreferences.xml'),
  );
  expect(file.existsSync(), isTrue, reason: 'old settings file restored');
  final xml = file.readAsStringSync();
  final prefs = await SharedPreferences.getInstance();
  final bools = RegExp(
    r'<boolean name="flutter\.([^"]+)" value="(true|false)"',
  );
  for (final m in bools.allMatches(xml)) {
    await prefs.setBool(m[1]!, m[2] == 'true');
  }
  final strings = RegExp(r'<string name="flutter\.([^"]+)">([^<]*)</string>');
  for (final m in strings.allMatches(xml)) {
    await prefs.setString(m[1]!, m[2]!);
  }
  expect(
    bools.allMatches(xml).any((m) => m[1] == 'onboarding_done'),
    isTrue,
    reason: 'first-run pages done, in the old settings',
  );
  _mark(
    'INFO:android settings from the old file: ${bools.allMatches(xml).length} switches',
  );
}

Future<void> _decodes(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  (await codec.getNextFrame()).image.dispose();
}

void _mark(String m) => print(m);

Future<void> _capture(WidgetTester tester, String name) async {
  await _pause(tester, 400);
  _mark('CAPTURE:$name');
  await _pause(tester, 1200);
}

Future<void> _pause(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder f, {int seconds = 60}) async {
  await _waitForAny(tester, [f], seconds: seconds);
}

/// The index of the first of [fs] found.
Future<int> _waitForAny(
  WidgetTester tester,
  List<Finder> fs, {
  int seconds = 60,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    for (final (i, f) in fs.indexed) {
      if (f.evaluate().isNotEmpty) return i;
    }
  }
  throw TestFailure('Timed out waiting for $fs');
}
