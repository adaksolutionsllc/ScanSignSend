// PreFill learns from the user's picks: a detail picked twice for a label
// fills that label next time; a match the user keeps replacing is dropped.
// Labels about someone else are never learned, and only the label and the
// detail's name are stored, never the value.

import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/models/field_model.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/prefill_hints.dart';
import 'package:scan_sign_send/core/services/prefill_matcher.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/fill_mode/presentation/fill_mode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Map<int, PrefillSlot> match(List<String> labels, LearnedPrefill learned) =>
      PrefillMatcher.matchForm([
        for (var i = 0; i < labels.length; i++)
          PrefillField(id: i, label: labels[i], type: FieldType.text),
      ], learned: learned);

  group('matching with what was learned', () {
    test(
      'two picks teach a label the rules don\'t know; one doesn\'t',
      () async {
        final repo = PrefillHintRepository(db);
        await repo.record('3 Applicant', PrefillSlot.fullName, accepted: true);
        expect(match(['Applicant'], await repo.load()), isEmpty);
        await repo.record('Applicant:', PrefillSlot.fullName, accepted: true);
        expect(match(['Applicant'], await repo.load()), {
          0: PrefillSlot.fullName,
        });
        // Only the label and the slot's name are stored.
        final row = (await db.select(db.prefillHints).get()).single;
        expect((row.phrase, row.slot), ('applicant', 'fullName'));
      },
    );

    test('a learned slot beats the rules and the form context', () async {
      final repo = PrefillHintRepository(db);
      // "Name" beside "Last name" is the first name by the rules; this user
      // keeps picking the full name there.
      for (var i = 0; i < 2; i++) {
        await repo.record('Name', PrefillSlot.fullName, accepted: true);
      }
      expect(
        match(['Name', 'Last name'], await repo.load())[0],
        PrefillSlot.fullName,
      );
      expect(
        match(['Name', 'Last name'], LearnedPrefill.none)[0],
        PrefillSlot.firstName,
      );
    });

    test('a rule match replaced twice is dropped', () async {
      final repo = PrefillHintRepository(db);
      await repo.record('Company', PrefillSlot.company, accepted: false);
      expect(match(['Company'], await repo.load()), {0: PrefillSlot.company});
      await repo.record('Company', PrefillSlot.company, accepted: false);
      expect(match(['Company'], await repo.load()), isEmpty);
    });

    test('labels about someone else, and sentences, are never learned', () {
      expect(PrefillMatcher.learnKey("Father's name"), isNull);
      expect(PrefillMatcher.learnKey('Emergency contact phone'), isNull);
      expect(PrefillMatcher.learnKey(''), isNull);
      expect(
        PrefillMatcher.learnKey(
          'Enter the amount from line 4 of the worksheet here',
        ),
        isNull,
      );
      expect(PrefillMatcher.learnKey('12b  Applicant'), 'applicant');
    });
  });

  testWidgets('picking a detail in Fill mode records it for the label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('google_mlkit_text_recognizer'),
          (_) async => null,
        );
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('sss_learn');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final docId = (await tester.runAsync(() async {
      await ProfileRepository(db).update(
        const UserProfileCompanion(
          firstName: Value('Priya'),
          lastName: Value('Raman'),
          email: Value('priya@example.com'),
        ),
      );
      final page = File('${tmp.path}/page.png')
        ..writeAsBytesSync(
          img.encodePng(
            img.fill(
              img.Image(width: 300, height: 400),
              color: img.ColorRgb8(255, 255, 255),
            ),
          ),
        );
      final doc = await DocumentRepository(db).createDocument('Form');
      await PageRepository(
        db,
      ).addPage(documentId: doc.id, pageIndex: 0, imagePath: page.path);
      await FieldRepository(db).addField(
        FieldsCompanion.insert(
          documentId: doc.id,
          pageIndex: 0,
          type: 'text',
          boundingBoxJson: '{"x":0.1,"y":0.2,"w":0.5,"h":0.05}',
          label: const Value('Applicant'),
        ),
      );
      return doc.id;
    }))!;

    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          home: FillModeScreen(docId: docId),
        ),
      ),
    );
    await settle();
    await tester.tap(find.byKey(const ValueKey('next-field')));
    await settle();

    // "Applicant" matches no rule, so no chip carries the sparkle.
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
    await tester.tap(find.widgetWithText(ActionChip, 'Priya Raman'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle();

    final rows = (await tester.runAsync(
      () => db.select(db.prefillHints).get(),
    ))!;
    expect(rows.single.phrase, 'applicant');
    expect(rows.single.slot, 'fullName');
    expect(rows.single.accepted, 1);
    expect(rows.any((r) => r.phrase.contains('priya')), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
