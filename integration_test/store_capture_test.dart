import 'dart:async';
// Drives the real app through Scan → Detect → Fill → Sign → Send for App Store
// screenshots and preview footage. Run by tool/store_capture/capture.sh, which
// swaps in the ML Kit stub, sets the simulator language, and grabs a
// screenshot each time this prints `CAPTURE:<name>`.
//
// Everything on screen is fictional: the form comes from make_forms.py and the
// applicant below is invented.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/features/library/presentation/library_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations.dart';
import 'package:scan_sign_send/shared/widgets/field_box.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/main.dart' as app;
import 'package:scan_sign_send/shared/widgets/paywall_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

/// Host path of the demo form (the simulator can read the Mac's filesystem).
const _form = String.fromEnvironment('FORM');

/// `video` paces the run for the preview recording; `stills` is quick.
const _mode = String.fromEnvironment('MODE', defaultValue: 'stills');
bool get _video => _mode == 'video';

/// Fictional applicant, per language of the demo form.
const _applicants = {
  'en': (
    'Priya Sharma',
    'priya.sharma@example.com',
    '+1 (555) 014-2381',
    '12 Lake View Road, Austin TX',
    'Northwind Analytics',
    '\$6,200',
  ),
  'fr': (
    'Camille Martin',
    'camille.martin@example.com',
    '06 12 34 56 78',
    '8 rue des Lilas, Lyon',
    'Atelier Boréal',
    '3 400 €',
  ),
  'es': (
    'Lucía Hernández',
    'lucia.hernandez@example.com',
    '55 1234 5678',
    'Calle Olmo 21, Guadalajara',
    'Grupo Aurora',
    '\$32,000',
  ),
  'pt': (
    'Ana Souza',
    'ana.souza@example.com',
    '(11) 91234-5678',
    'Rua das Acácias, 45, São Paulo',
    'Horizonte Digital',
    'R\$ 7.500',
  ),
};

class _DemoPicker extends FilePicker {
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
    final f = File(_form);
    return FilePickerResult([
      PlatformFile(
        path: f.path,
        name: f.uri.pathSegments.last,
        size: f.lengthSync(),
      ),
    ]);
  }

  @override
  Future<bool?> clearTemporaryFiles() async => true;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    FilePicker.platform = _DemoPicker();

    // main() installs its own FlutterError.onError and ErrorWidget.builder; the
    // test binding needs its own back so failures are reported instead of tripping an assert.
    final testOnError = FlutterError.onError;
    final testErrorWidget = ErrorWidget.builder;
    app.main();
    await _waitFor(tester, find.byType(LibraryScreen));
    FlutterError.onError = testOnError;
    ErrorWidget.builder = testErrorWidget;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LibraryScreen)),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryScreen)),
    );
    final lang = l10n.localeName.split('_').first;
    final who = _applicants[lang] ?? _applicants['en']!;

    await container
        .read(profileRepositoryProvider)
        .update(
          UserProfileCompanion(
            fullName: Value(who.$1),
            email: Value(who.$2),
            phone: Value(who.$3),
            address: Value(who.$4),
            isPurchased: const Value(true),
          ),
        );

    // ── Import → Review ────────────────────────────────────────────────────
    _mark('REC:start');
    await _pause(tester, _video ? 1200 : 300);
    _mark('BEAT:import');
    await tester.tap(find.text(l10n.libraryImport));
    await _waitFor(tester, find.text(l10n.reviewDetectFields));
    await _pause(tester, _video ? 1500 : 600);
    await _capture(tester, 'review');

    // ── Detect fields ──────────────────────────────────────────────────────
    _mark('BEAT:detect');
    await tester.tap(find.text(l10n.reviewDetectFields));
    await _waitFor(tester, find.byType(FieldBox));
    await _pause(tester, _video ? 2500 : 900);
    await _capture(tester, 'detect');

    final docs = await container
        .read(documentRepositoryProvider)
        .watchAll()
        .first;
    final docId = docs.single.id;
    final fieldRepo = container.read(fieldRepositoryProvider);
    final fields = await fieldRepo.watchFields(docId).first;
    for (final f in fields) {
      // ignore: avoid_print
      print('FIELD ${f.id} ${f.type} "${f.label}"');
    }

    // Give the signature room, as a user does by dragging its corner: the
    // detected box is one text line tall. Bottom stays on the signing line.
    for (final f in fields.where((f) => f.type == 'signature')) {
      final b = jsonDecode(f.boundingBoxJson) as Map<String, dynamic>;
      final y = (b['y'] as num) + (b['h'] as num);
      const h = 0.06;
      await fieldRepo.updateField(
        FieldsCompanion(
          id: Value(f.id),
          boundingBoxJson: Value(
            jsonEncode({...b, 'y': y - h, 'h': h, 'w': 0.5}),
          ),
        ),
      );
    }

    // ── Fill ───────────────────────────────────────────────────────────────
    _mark('BEAT:fill');
    await tester.tap(find.text(l10n.detectFillFields(fields.length)));
    await _waitFor(tester, find.text(l10n.fillReviewAndFinish));
    await _pause(tester, _video ? 1200 : 600);

    // Field boxes are built in field order.
    int indexOf(bool Function(Field f) test) => fields.indexWhere(test);
    Finder box(int i) => find.byType(FieldBox).at(i);

    // Type the name by hand, as a user would.
    final nameIdx = indexOf((f) => f.type == 'text');
    await tester.tap(box(nameIdx));
    await _waitFor(tester, find.byType(TextField));
    await _pause(tester, _video ? 500 : 200);
    if (_video) {
      for (var i = 1; i <= who.$1.length; i++) {
        await tester.enterText(find.byType(TextField), who.$1.substring(0, i));
        await _pause(tester, 70);
      }
    } else {
      await tester.enterText(find.byType(TextField), who.$1);
    }
    await _pause(tester, _video ? 500 : 200);
    await tester.tap(find.text(l10n.actionSave));
    await _pause(tester, _video ? 900 : 400);

    // The rest arrives the way autofill and the date picker would put it.
    final values = <String, String>{
      'email': who.$2,
      'phone': who.$3,
      'address': who.$4,
      'employer': who.$5,
      'income': who.$6,
    };
    String? valueFor(Field f) {
      final l = f.label.toLowerCase();
      bool has(List<String> keys) => keys.any(l.contains);
      if (f.type == 'date') {
        if (has(['birth', 'naissance', 'nacimiento', 'nascimento'])) {
          return lang == 'en' ? '03/14/1994' : '14/03/1994';
        }
        if (has(['start', 'embauche', 'ingreso', 'admissão'])) {
          return lang == 'en' ? '01/09/2023' : '09/01/2023';
        }
        return null; // the signing date fills itself in
      }
      const byLabel = {
        'email': ['mail'],
        'phone': ['phone', 'téléphone', 'teléfono', 'telefone'],
        'address': ['address', 'adresse', 'domicilio', 'endereço'],
        'employer': ['employ', 'empresa', 'empregador'],
        'income': ['income', 'revenu', 'ingreso', 'renda'],
      };
      for (final e in byLabel.entries) {
        if (has(e.value)) return values[e.key];
      }
      return null;
    }

    for (final f in fields) {
      if (f.isFilled || fields.indexOf(f) == nameIdx) continue;
      final v = valueFor(f);
      if (v == null) continue;
      await fieldRepo.updateField(
        FieldsCompanion(
          id: Value(f.id),
          value: Value(v),
          isFilled: const Value(true),
        ),
      );
      if (_video) await _pause(tester, 260);
    }
    await _pause(tester, _video ? 600 : 300);

    // Tick a box by tapping it.
    final boxIdx = indexOf((f) => f.type == 'checkbox');
    if (boxIdx >= 0) {
      final second = fields.indexWhere((f) => f.type == 'checkbox', boxIdx + 1);
      await tester.tap(box(second >= 0 ? second : boxIdx));
      await _pause(tester, _video ? 800 : 300);
    }
    await _capture(tester, 'fill');

    // ── Sign ───────────────────────────────────────────────────────────────
    final sigIdx = indexOf((f) => f.type == 'signature');
    _mark('BEAT:sign');
    await tester.ensureVisible(box(sigIdx));
    await tester.tap(box(sigIdx));
    await _waitFor(tester, find.text(l10n.signUseThis));
    await _pause(tester, _video ? 700 : 400);
    await _drawSignature(tester, find.byType(SfSignaturePad));
    await _pause(tester, _video ? 700 : 300);
    await _capture(tester, 'sign');
    await tester.tap(find.text(l10n.signUseThis));
    await _waitFor(tester, find.text(l10n.fillReviewAndFinish));
    await _pause(tester, _video ? 1500 : 600);

    // ── Finish → Send ──────────────────────────────────────────────────────
    _mark('BEAT:finish');
    await tester.tap(find.text(l10n.fillReviewAndFinish));
    await _waitFor(tester, find.text(l10n.pressFlattenAndSign));
    await _pause(tester, _video ? 1200 : 400);
    await tester.tap(find.text(l10n.pressFlattenAndSign));
    await _waitFor(tester, find.text(l10n.pressFlattenAndLock));
    await _pause(tester, _video ? 900 : 300);
    await tester.tap(find.text(l10n.pressFlattenAndLock));
    await _waitFor(tester, find.text(l10n.sendPreviewDocument), seconds: 60);
    await _pause(tester, _video ? 1200 : 500);
    await _capture(tester, 'send');
    if (!_video) {
      await tester.tap(find.text(l10n.sendSaveAsTemplate));
      await _pause(tester, 1500);
    }

    _mark('BEAT:pdf');
    await tester.tap(find.text(l10n.sendPreviewDocument));
    await _pause(tester, 3000);
    await _capture(tester, 'pdf');
    _mark('REC:stop');

    // ── Library: the signed form and its reusable template ───────────────
    if (!_video) {
      final router = container.read(routerProvider);
      router.go(AppRoutes.library);
      await _waitFor(tester, find.byType(LibraryScreen));
      await _pause(tester, 1500);
      await _capture(tester, 'library');

      // App Review screenshot for the Full Access in-app purchase.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      unawaited(nav.push(
        MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
      ));
      await _waitFor(tester, find.byType(PaywallScreen));
      await _pause(tester, 1500);
      await _capture(tester, 'paywall');

      // A free user's library, with the Unlimited banner (not a store shot).
      nav.pop();
      await container
          .read(profileRepositoryProvider)
          .update(const UserProfileCompanion(isPurchased: Value(false)));
      await _pause(tester, 2500);
      await _capture(tester, 'banner');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// A flowing two-loop signature, drawn in real time so the pad renders the
/// stroke the way a finger would.
Future<void> _drawSignature(WidgetTester tester, Finder pad) async {
  final r = tester.getRect(pad);
  Offset at(double x, double y) =>
      Offset(r.left + r.width * x, r.top + r.height * y);

  Future<void> stroke(List<Offset> pts) async {
    final g = await tester.startGesture(pts.first);
    for (final p in pts.skip(1)) {
      await g.moveTo(p);
      await tester.pump(const Duration(milliseconds: 8));
    }
    await g.up();
    await tester.pump();
  }

  // Capital: a stem, then a bowl that flows back across it.
  await stroke([
    for (var i = 0; i <= 30; i++)
      at(0.12 + 0.02 * i / 30, 0.58 - 0.20 * math.sin(math.pi / 2 * i / 30)),
    for (var i = 0; i <= 50; i++)
      at(
        0.14 + 0.09 * math.sin(math.pi * 1.15 * i / 50),
        0.38 + 0.05 * (1 - math.cos(math.pi * 1.15 * i / 50)),
      ),
  ]);
  // Joined lowercase: a prolate trochoid loops back on itself like
  // handwriting, shrinking slightly, then trails off in a flick.
  const loops = 5.0;
  await stroke([
    for (var i = 0; i <= 220; i++)
      () {
        final s = i / 220;
        final th = s * loops * 2 * math.pi;
        final shrink = 1 - 0.35 * s;
        final x = 0.26 + 0.52 * s - 0.035 * math.sin(th) * shrink;
        final y = 0.52 - 0.045 * (1 - math.cos(th)) * shrink + 0.02 * s;
        return at(x, y);
      }(),
    for (var i = 1; i <= 24; i++)
      at(0.78 + 0.10 * i / 24, 0.54 - 0.06 * i / 24),
  ]);
}

/// Asks capture.sh for a screenshot (stills) — the video only needs a beat.
Future<void> _capture(WidgetTester tester, String name) async {
  if (_video) return _pause(tester, 700);
  _mark('CAPTURE:$name');
  await _pause(tester, 1800);
}

/// A marker line for capture.sh: CAPTURE:, BEAT: or REC:.
// ignore: avoid_print
void _mark(String m) => print(m);

Future<void> _pause(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _waitFor(WidgetTester tester, Finder f, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}
