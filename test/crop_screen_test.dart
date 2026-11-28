// Check the edges (1.3.1, 1.3.2): the pages come from the document's import
// job and each choice is saved to it, so leaving and coming back starts at
// the first page not decided. On a long file the user can keep the rest of
// the pages whole in one tap; the job then straightens and JobScreen shows
// it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/services/import_job_runner.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/review/presentation/crop_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';

class _FakeRunner extends ChangeNotifier implements ImportJobRunner {
  _FakeRunner(this.pages, this.chosen);
  final int pages;
  final Map<int, EdgeQuad?> chosen;
  final choices = <int, EdgeQuad?>{};
  var straightened = false;

  @override
  Future<(List<EdgeCandidate>, Map<int, EdgeQuad?>)> toChoose(
    int docId,
  ) async => (
    [
      for (var i = 0; i < pages; i++)
        EdgeCandidate(
          pageId: 100 + i,
          imagePath: '/missing/page_$i.jpg',
          quad: _tilted,
        ),
    ],
    chosen,
  );

  @override
  Future<void> choose(int docId, int pageId, EdgeQuad? quad) async =>
      choices[pageId] = quad;

  @override
  Future<void> startStraighten(int docId) async => straightened = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _tilted = EdgeQuad(
  math.Point(0.1, 0.1),
  math.Point(0.9, 0.1),
  math.Point(0.9, 0.9),
  math.Point(0.1, 0.9),
);

void main() {
  final l10n = AppLocalizationsEn();

  Future<_FakeRunner> open(
    WidgetTester tester,
    int pages, {
    Map<int, EdgeQuad?> chosen = const {},
  }) async {
    final runner = _FakeRunner(pages, chosen);
    final router = GoRouter(
      initialLocation: '/crop/7',
      routes: [
        GoRoute(
          path: AppRoutes.crop,
          builder: (_, _) => const CropScreen(docId: 7),
        ),
        GoRoute(
          path: AppRoutes.job,
          builder: (_, _) => const Scaffold(body: Text('job')),
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
    await tester.pump();
    await tester.pump();
    return runner;
  }

  testWidgets('each choice is saved; keep the rest whole goes to the job', (
    tester,
  ) async {
    final runner = await open(tester, 18);
    expect(find.text(l10n.reviewPageOf(1, 18)), findsOneWidget);
    await tester.tap(find.text(l10n.cropApply));
    await tester.pump();
    await tester.tap(find.text(l10n.cropUseWhole));
    await tester.pump();
    expect(find.text(l10n.reviewPageOf(3, 18)), findsOneWidget);
    expect(runner.choices, {100: _tilted, 101: null});

    await tester.tap(find.byKey(const ValueKey('crop-use-whole-rest')));
    await tester.pumpAndSettle();
    expect(runner.straightened, isTrue);
    expect(find.text('job'), findsOneWidget);
  });

  testWidgets('coming back starts at the first page not decided', (
    tester,
  ) async {
    await open(tester, 5, chosen: {100: _tilted, 101: null});
    expect(find.text(l10n.reviewPageOf(3, 5)), findsOneWidget);
  });

  testWidgets('the last page has no "rest" button; one page, no count', (
    tester,
  ) async {
    final runner = await open(tester, 1);
    expect(find.byKey(const ValueKey('crop-use-whole-rest')), findsNothing);
    expect(find.textContaining('1 of 1'), findsNothing);
    await tester.tap(find.text(l10n.cropApply));
    await tester.pumpAndSettle();
    expect(runner.choices.keys, [100]);
    expect(runner.straightened, isTrue);
  });

  testWidgets('no pages waiting (a restored route): Review', (tester) async {
    await open(tester, 0);
    await tester.pumpAndSettle();
    expect(find.text('review'), findsOneWidget);
  });
}
