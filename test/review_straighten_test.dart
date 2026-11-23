// Review → Straighten pages (1.3.1, 1.3.2): a user who kept the pages as
// they were at import can still straighten them later. It runs as an import
// job (progress, Pause, Skip) and comes back to the same Review screen.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart' as db_;
import 'package:scan_sign_send/core/db/app_database.dart' hide Page;
import 'package:scan_sign_send/core/db/database_provider.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/core/services/background_work_service.dart';
import 'package:scan_sign_send/core/services/import_job.dart';
import 'package:scan_sign_send/core/services/import_job_runner.dart';
import 'package:scan_sign_send/features/review/presentation/crop_screen.dart';
import 'package:scan_sign_send/features/review/presentation/job_screen.dart';
import 'package:scan_sign_send/features/review/presentation/review_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEdges implements EdgeCheckService {
  _FakeEdges(this.db);
  final AppDatabase db;

  /// What the next check finds; completed by the test.
  var found = Completer<List<EdgeCandidate>>();
  PageProgress? progress;
  ShouldStop? stop;
  Map<int, EdgeQuad>? applied;

  @override
  Future<List<db_.Page>> checkablePages(int docId) =>
      PageRepository(db).pagesOf(docId);

  @override
  Future<List<EdgeCandidate>> candidatesFor(
    int docId, {
    PageProgress? onProgress,
    ShouldStop? stop,
    ShouldStop? hold,
    Map<int, List<double>?> known = const {},
    PageEvent? onStart,
    Future<void> Function(int pageId, EdgeQuad? quad)? onPage,
  }) async {
    progress = onProgress;
    this.stop = stop;
    final out = await found.future;
    return stop?.call() ?? false ? const [] : out;
  }

  @override
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
    applied = crops;
    return const [];
  }

  @override
  Future<bool> isPdfBacked(int docId) async => false;

  @override
  Future<void> discardStaged(int docId, String tag) async {}

  @override
  void begin(int docId) {}

  @override
  void end(int docId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;
  late Directory jobs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  setUp(() => jobs = Directory.systemTemp.createTempSync('jobs'));
  tearDown(() async {
    await db.close();
    jobs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A 3-page photo document open in Review, through the app's own routes.
  Future<(_FakeEdges, int)> open(
    WidgetTester tester, {
    bool withField = false,
  }) async {
    final edges = _FakeEdges(db);
    final docId = (await tester.runAsync(() async {
      final doc = await DocumentRepository(db).createDocument('Scan');
      for (var i = 0; i < 3; i++) {
        await PageRepository(db).addPage(
          documentId: doc.id,
          pageIndex: i,
          imagePath: '/missing/page_$i.jpg',
        );
      }
      if (withField) {
        await FieldRepository(db).addField(
          FieldsCompanion.insert(
            documentId: doc.id,
            pageIndex: 0,
            type: 'text',
            boundingBoxJson: '{"x":0.1,"y":0.1,"w":0.3,"h":0.05}',
          ),
        );
      }
      return doc.id;
    }))!;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        edgeCheckServiceProvider.overrideWithValue(edges),
        importJobRunnerProvider.overrideWith(
          (ref) => ImportJobRunner(
            edges: edges,
            docRepo: DocumentRepository(db),
            store: ImportJobStore(folder: () async => jobs),
            phone: BackgroundWorkService(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    router.go(AppRoutes.review.replaceAll(':docId', '$docId'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
        ),
      ),
    );
    await settle(tester);
    return (edges, docId);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  final straighten = find.byKey(const ValueKey('review-straighten'));

  testWidgets('straighten, check the pages, and come back to Review', (
    tester,
  ) async {
    final (edges, docId) = await open(tester);
    expect(find.text(l10n.reviewStraighten), findsOneWidget);
    await tester.tap(straighten);
    await settle(tester); // the job's checkpoint is a real file write

    // Progress while it checks, with the time left and Skip.
    edges.progress!(0, 3);
    await tester.pump();
    expect(find.byType(JobScreen), findsOneWidget);
    expect(find.text(l10n.cropCheckingPage(1, 3)), findsOneWidget);
    expect(find.byKey(const ValueKey('edge-check-skip')), findsOne);
    expect(find.byKey(const ValueKey('job-pause')), findsOne);

    final pages = (await tester.runAsync(
      () => PageRepository(db).pagesOf(docId),
    ))!;
    edges.found.complete([
      EdgeCandidate(
        pageId: pages.first.id,
        imagePath: '/missing/page_0.jpg',
        quad: const EdgeQuad(
          math.Point(0.1, 0.1),
          math.Point(0.9, 0.1),
          math.Point(0.9, 0.9),
          math.Point(0.1, 0.9),
        ),
      ),
    ]);
    await settle(tester);
    expect(find.byType(CropScreen), findsOneWidget);

    await tester.tap(find.text(l10n.cropApply));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1)); // the page transition
    expect(edges.applied!.keys, [pages.first.id]);
    // Back on the same Review, not a second one on top.
    expect(find.byType(CropScreen), findsNothing);
    expect(find.byType(ReviewScreen, skipOffstage: false), findsOneWidget);
    expect(find.text(l10n.reviewStraighten), findsOneWidget);
    await close(tester);
  });

  testWidgets('nothing to fix says so; Skip says nothing', (tester) async {
    final (edges, _) = await open(tester);
    await tester.tap(straighten);
    await settle(tester); // the job's checkpoint is a real file write
    edges.found.complete(const []);
    await settle(tester);
    expect(find.text(l10n.reviewStraightenNone), findsOneWidget);
    expect(find.byType(CropScreen), findsNothing);

    ScaffoldMessenger.of(
      tester.element(find.byType(ReviewScreen)),
    ).removeCurrentSnackBar();
    edges.found = Completer();
    await tester.tap(straighten);
    await settle(tester); // the job's checkpoint is a real file write
    edges.progress!(0, 3);
    await tester.pump();
    expect(edges.stop!(), isFalse);
    await tester.tap(find.byKey(const ValueKey('edge-check-skip')));
    await tester.pump();
    expect(edges.stop!(), isTrue);
    edges.found.complete(const []);
    await settle(tester);
    expect(find.text(l10n.reviewStraightenNone), findsNothing);
    expect(find.text(l10n.reviewStraighten), findsOneWidget);
    await close(tester);
  });

  testWidgets('not offered once the document has fields', (tester) async {
    await open(tester, withField: true);
    expect(find.text(l10n.reviewDetectFields), findsOneWidget);
    expect(straighten, findsNothing);
    await close(tester);
  });
}
