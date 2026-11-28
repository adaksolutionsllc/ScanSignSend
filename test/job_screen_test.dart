// The job screen and the Library bar (plan 1.3.2): progress with Pause,
// Resume, Skip and Keep using the app; the crop screen when pages wait for
// the user; Review (with what happened) when the job ends.

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/import_job.dart';
import 'package:scan_sign_send/core/services/import_job_runner.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/review/presentation/import_job_bar.dart';
import 'package:scan_sign_send/features/review/presentation/job_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';

class _FakeRunner extends ChangeNotifier implements ImportJobRunner {
  final jobs = <int, JobView>{};
  final results = <int, JobResult>{};
  final calls = <String>[];
  int pending = 0;

  /// What onAppResumed returns: pages the system-paused jobs go on from.
  List<int> resumedPages = const [];

  @override
  JobStrings strings = JobStrings.fallback;

  @override
  Future<void> restore() async {}

  @override
  List<int> onAppResumed() => resumedPages;

  void set(JobView? v, {int docId = 7}) {
    if (v == null) {
      jobs.remove(docId);
    } else {
      jobs[docId] = v;
    }
    notifyListeners();
  }

  @override
  JobView? view(int docId) => jobs[docId];

  @override
  List<JobView> get views => jobs.values.toList();

  @override
  bool hasJob(int docId) => jobs.containsKey(docId);

  @override
  int toCheckCount(int docId) => pending;

  @override
  JobResult? takeResult(int docId) => results.remove(docId);

  @override
  Future<void> pause(int docId) async => calls.add('pause $docId');

  @override
  Future<void> resume(int docId) async => calls.add('resume $docId');

  @override
  Future<void> skip(int docId) async => calls.add('skip $docId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

JobView _view({
  JobStep step = JobStep.straighten,
  bool paused = false,
  bool running = true,
  int done = 4,
  int total = 18,
  int docId = 7,
}) => JobView(
  docId: docId,
  step: step,
  paused: paused,
  running: running,
  done: done,
  total: total,
  left: const Duration(minutes: 3),
);

void main() {
  final l10n = AppLocalizationsEn();

  Future<_FakeRunner> open(
    WidgetTester tester, {
    JobView? view,
    bool back = false,
  }) async {
    final runner = _FakeRunner()..set(view ?? _view());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: AppRoutes.library,
          builder: (_, _) => const Scaffold(body: Text('library')),
        ),
        GoRoute(
          path: AppRoutes.job,
          builder: (_, s) => JobScreen(
            docId: int.parse(s.pathParameters['docId']!),
            popWhenDone: back,
          ),
        ),
        GoRoute(
          path: AppRoutes.crop,
          builder: (_, _) => const Scaffold(body: Text('crop')),
        ),
        GoRoute(
          path: AppRoutes.review,
          builder: (_, _) => const Scaffold(body: Text('review')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [importJobRunnerProvider.overrideWith((ref) => runner)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
        ),
      ),
    );
    router.push('/job/7');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return runner;
  }

  testWidgets('running: page, screen on, Pause and Skip', (tester) async {
    final runner = await open(tester);
    expect(find.text(l10n.cropStraighteningPage(5, 18)), findsOneWidget);
    expect(find.text(l10n.jobScreenOn), findsOneWidget);
    expect(find.text(l10n.progressMinutesLeft(3)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('job-pause')));
    await tester.tap(find.byKey(const ValueKey('straighten-progress-skip')));
    expect(runner.calls, ['pause 7', 'skip 7']);
  });

  testWidgets('iOS: running says the phone may pause it when locked', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await open(tester);
      expect(find.text(l10n.jobLockHint), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android: no lock line (the work goes on when locked)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await open(tester);
      expect(find.text(l10n.jobScreenOn), findsOneWidget);
      expect(find.text(l10n.jobLockHint), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the app back in front: a message for a job the phone paused', (
    tester,
  ) async {
    final runner = _FakeRunner()..resumedPages = [6];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [importJobRunnerProvider.overrideWith((ref) => runner)],
        child: MaterialApp(
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          builder: (context, child) => ImportJobHost(child: child!),
          home: const Scaffold(body: Text('library')),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l10n.jobResumedNotice(6)), findsOneWidget);

    // Nothing the phone paused: no message.
    ScaffoldMessenger.of(
      tester.element(find.text('library')),
    ).removeCurrentSnackBar();
    await tester.pump();
    runner.resumedPages = const [];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('paused: Resume and the saved-progress line', (tester) async {
    final runner = await open(
      tester,
      view: _view(paused: true, running: false),
    );
    expect(find.text(l10n.jobPausedHint), findsOneWidget);
    expect(find.text(l10n.jobScreenOn), findsNothing);
    await tester.tap(find.byKey(const ValueKey('job-resume')));
    expect(runner.calls, ['resume 7']);
  });

  testWidgets('Keep using the app goes to the Library', (tester) async {
    await open(tester, view: _view(step: JobStep.check, done: 0));
    expect(find.text(l10n.cropCheckingPage(1, 18)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('job-keep-using')));
    await tester.pumpAndSettle();
    expect(find.text('library'), findsOneWidget);
  });

  testWidgets('pages to look at: the crop screen', (tester) async {
    final runner = await open(tester, view: _view(step: JobStep.check));
    runner.set(_view(step: JobStep.choose, running: false));
    await tester.pumpAndSettle();
    expect(find.text('crop'), findsOneWidget);
  });

  testWidgets('done: Review, and pages kept after a crash are told', (
    tester,
  ) async {
    final runner = await open(tester);
    runner
      ..results[7] = const JobResult(kept: {12})
      ..set(null);
    await tester.pumpAndSettle();
    expect(find.text('review'), findsOneWidget);
    expect(find.text(l10n.jobKeptAsIs(1)), findsOneWidget);
  });

  testWidgets('a skipped job says nothing', (tester) async {
    final runner = await open(tester);
    runner
      ..results[7] = const JobResult(failed: [3], skipped: true)
      ..set(null);
    await tester.pumpAndSettle();
    expect(find.text('review'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('from Review: back to it; nothing found is told', (tester) async {
    final runner = await open(
      tester,
      view: _view(step: JobStep.check),
      back: true,
    );
    runner
      ..results[7] = const JobResult()
      ..set(null);
    await tester.pumpAndSettle();
    expect(find.text('library'), findsOneWidget, reason: 'popped');
    expect(find.text(l10n.reviewStraightenNone), findsOneWidget);
  });

  group('Library bar', () {
    late AppDatabase db;
    setUp(
      () => db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      ),
    );
    tearDown(() => db.close());

    testWidgets('one line per job, with its state and action', (tester) async {
      final ids = (await tester.runAsync(() async {
        final repo = DocumentRepository(db);
        return [
          for (final t in ['Tax form', 'Lease', 'Receipts', 'Will'])
            (await repo.createDocument(t)).id,
        ];
      }))!;
      final runner = _FakeRunner()
        ..pending = 3
        ..set(_view(docId: ids[0]), docId: ids[0])
        ..set(_view(docId: ids[1], paused: true, running: false), docId: ids[1])
        ..set(
          _view(docId: ids[2], running: false, done: 0, total: 0),
          docId: ids[2],
        )
        ..set(
          _view(docId: ids[3], step: JobStep.choose, running: false),
          docId: ids[3],
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            importJobRunnerProvider.overrideWith((ref) => runner),
          ],
          child: MaterialApp(
            localizationsDelegates: kLocalizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const Scaffold(body: ImportJobBar()),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(find.text('Tax form'), findsOneWidget);
      expect(find.text(l10n.cropStraighteningPage(5, 18)), findsOneWidget);
      expect(find.text(l10n.jobPaused), findsOneWidget);
      expect(find.text(l10n.jobWaiting), findsOneWidget);
      expect(find.text(l10n.jobPagesToCheck(3)), findsOneWidget);
      expect(find.text(l10n.jobCheckNow), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('job-bar-pause-${ids[0]}')));
      await tester.tap(find.byKey(ValueKey('job-bar-resume-${ids[1]}')));
      expect(runner.calls, ['pause ${ids[0]}', 'resume ${ids[1]}']);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
