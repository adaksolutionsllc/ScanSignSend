// Home-screen quick actions: Scan, Open a PDF, and Fill last draft while
// there is one, titled in the app's language. An action waits for the app
// lock, so the camera or file picker never opens over the lock screen.

import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/app_lock_provider.dart';
import 'package:scan_sign_send/core/services/biometric_service.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/privacy_screen_service.dart';
import 'package:scan_sign_send/core/services/profile_repository.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/l10n/app_localizations_fr.dart';
import 'package:scan_sign_send/shared/widgets/quick_actions_setup.dart';

/// Unlocking waits for [answer].
class _Bio extends BiometricService {
  Completer<bool> answer = Completer();
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<bool> authenticate({required String reason}) => answer.future;
}

class _FakeQuickActions implements QuickActions {
  QuickActionHandler? handler;
  List<ShortcutItem> items = const [];
  @override
  Future<void> initialize(QuickActionHandler handler) async =>
      this.handler = handler;
  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async =>
      this.items = items;
  @override
  Future<void> clearShortcutItems() async => items = const [];
}

Document _doc(int id, String status, DateTime at) => Document(
  id: id,
  uuid: 'u$id',
  title: 'Doc $id',
  createdAt: at,
  updatedAt: at,
  status: status,
  pageCount: 1,
  ocrText: '',
  isTemplate: status == 'template',
  countedFree: false,
  titleEdited: false,
  categoryManual: false,
  hasFormFields: false,
);

void main() {
  late AppDatabase db;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.scansignsend/privacy'),
          (_) async => null,
        );
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  test('routes: scan, open, and the newest draft still being filled', () {
    final t = DateTime(2026, 11, 21);
    final docs = [
      _doc(1, 'draft', t),
      _doc(2, 'fillable', t.add(const Duration(hours: 2))),
      _doc(3, 'pressed', t.add(const Duration(hours: 3))),
      _doc(4, 'template', t.add(const Duration(hours: 4))),
    ];
    expect(
      quickActionRoute(QuickActionType.scan, docs),
      '/capture?action=scan',
    );
    expect(
      quickActionRoute(QuickActionType.openPdf, docs),
      '/capture?action=import',
    );
    expect(quickActionRoute(QuickActionType.lastDraft, docs), '/fill/2');
    expect(quickActionRoute(QuickActionType.lastDraft, [docs[2]]), isNull);
    expect(quickActionRoute('unknown', docs), isNull);
  });

  test(
    'whenUnlocked waits for the lock setting, then for the unlock',
    () async {
      await ProfileRepository(
        db,
      ).update(const UserProfileCompanion(biometricLockEnabled: Value(true)));
      final bio = _Bio();
      final lock = AppLockNotifier(
        bio,
        ProfileRepository(db),
        PrivacyScreenService(),
      );
      // Straight after start the state still reads "unlocked": not yet known.
      expect(lock.state, isFalse);
      var through = false;
      unawaited(lock.whenUnlocked().then((_) => through = true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(lock.state, isTrue);
      expect(through, isFalse, reason: 'held while locked');
      bio.answer.complete(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(through, isTrue);
      lock.dispose();
    },
  );

  testWidgets(
    'items follow drafts and language; an action opens its route',
    (tester) async {
      final qa = _FakeQuickActions();
      final bio = _Bio();
      await tester.runAsync(
        () => ProfileRepository(
          db,
        ).update(const UserProfileCompanion(biometricLockEnabled: Value(true))),
      );
      final opened = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/fill/:docId',
            builder: (_, s) {
              opened.add(s.uri.toString());
              return const SizedBox();
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routerProvider.overrideWithValue(router),
            appLockProvider.overrideWith(
              (ref) => AppLockNotifier(
                bio,
                ProfileRepository(db),
                PrivacyScreenService(),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('fr'),
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
            builder: (context, child) =>
                QuickActionsSetup(quickActions: qa, child: child!),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await settle();
      final fr = AppLocalizationsFr();
      expect(qa.items.map((i) => i.localizedTitle), [
        fr.quickScan,
        fr.quickOpenPdf,
      ]);

      // In the test's own zone: the library's live query runs there too, and
      // a write from runAsync would wait on it while fake time stands still.
      final created = DocumentRepository(db).createDocument('Bail');
      await settle();
      final id = (await created).id;
      expect(qa.items.map((i) => i.type), [
        QuickActionType.scan,
        QuickActionType.openPdf,
        QuickActionType.lastDraft,
      ]);
      expect(qa.items.last.localizedTitle, fr.quickLastDraft);

      // As the OS calls it: the handler waits for the lock and a frame.
      qa.handler!(QuickActionType.lastDraft);
      await settle();
      expect(opened, isEmpty, reason: 'held behind the lock');
      bio.answer.complete(true);
      await settle();
      expect(opened, ['/fill/$id']);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Siri / Shortcuts: queued at launch or pinged later, same routes',
    (tester) async {
      const channel = MethodChannel('com.scansignsend/shortcuts');
      final messenger = tester.binding.defaultBinaryMessenger;
      String? pending = QuickActionType.lastDraft; // ran before Dart started
      messenger.setMockMethodCallHandler(channel, (call) async {
        final type = pending;
        pending = null;
        return call.method == 'takePending' ? type : null;
      });
      final opened = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: SizedBox()),
          ),
          GoRoute(
            path: '/fill/:docId',
            builder: (_, s) {
              opened.add(s.uri.toString());
              return const SizedBox();
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routerProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('fr'),
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
            builder: (context, child) => QuickActionsSetup(
              quickActions: _FakeQuickActions(),
              child: child!,
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await settle();
      final fr = AppLocalizationsFr();
      expect(opened, isEmpty);
      expect(
        find.text(fr.shortcutNoDraft),
        findsOneWidget,
        reason: 'no draft: Siri still opened the app, so say why',
      );

      final created = DocumentRepository(db).createDocument('Bail');
      await settle();
      final id = (await created).id;
      // The app is running: native queues the action and pings.
      pending = QuickActionType.lastDraft;
      // Not awaited: the handler waits on a live query that only runs
      // while the test pumps.
      unawaited(
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('pending'),
          ),
          (_) {},
        ),
      );
      await settle();
      expect(opened, ['/fill/$id']);

      messenger.setMockMethodCallHandler(channel, null);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
