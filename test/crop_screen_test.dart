// Check the edges (1.3.1): on a long file the user can keep the rest of the
// pages whole in one tap, sees which page is being straightened, and leaving
// the screen ends the edge check (so the pages' text can be read).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/core/utils/router.dart';
import 'package:scan_sign_send/features/review/presentation/crop_screen.dart';
import 'package:scan_sign_send/l10n/app_localizations_en.dart';

class _FakeEdges implements EdgeCheckService {
  Map<int, EdgeQuad>? applied;
  final ended = <int>[];
  final done = Completer<List<int>>();
  PageProgress? progress;
  ShouldStop? stop;

  @override
  Future<List<int>> apply(
    int docId,
    Map<int, EdgeQuad> crops, {
    PageProgress? onProgress,
    ShouldStop? stop,
  }) {
    applied = crops;
    progress = onProgress;
    this.stop = stop;
    return done.future;
  }

  @override
  void end(int docId) => ended.add(docId);

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

  Future<_FakeEdges> open(WidgetTester tester, int pages) async {
    final edges = _FakeEdges();
    final router = GoRouter(
      initialLocation: '/crop/7',
      routes: [
        GoRoute(
          path: AppRoutes.crop,
          builder: (_, _) => CropScreen(
            docId: 7,
            candidates: [
              for (var i = 0; i < pages; i++)
                EdgeCandidate(
                  pageId: 100 + i,
                  imagePath: '/missing/page_$i.jpg',
                  quad: _tilted,
                ),
            ],
          ),
        ),
        GoRoute(
          path: AppRoutes.review,
          builder: (_, _) => const Scaffold(body: Text('review')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [edgeCheckServiceProvider.overrideWithValue(edges)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: kLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
        ),
      ),
    );
    await tester.pump();
    return edges;
  }

  testWidgets('keep the rest whole: only the crops chosen so far', (
    tester,
  ) async {
    final edges = await open(tester, 18);
    expect(find.text(l10n.reviewPageOf(1, 18)), findsOneWidget);
    await tester.tap(find.text(l10n.cropApply));
    await tester.pump();
    await tester.tap(find.text(l10n.cropUseWhole));
    await tester.pump();
    expect(find.text(l10n.reviewPageOf(3, 18)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('crop-use-whole-rest')));
    await tester.pump();
    expect(edges.applied!.keys, [100], reason: 'page 1 only');

    // Straightening shows which page it is on.
    edges.progress!(0, 18);
    await tester.pump();
    expect(find.text(l10n.cropStraighteningPage(1, 18)), findsOneWidget);
    edges.progress!(5, 18);
    await tester.pump();
    expect(find.text(l10n.cropStraighteningPage(6, 18)), findsOneWidget);
    edges.progress!(18, 18);
    await tester.pump();
    expect(find.text(l10n.cropStraighteningPage(18, 18)), findsOneWidget);

    expect(edges.ended, isEmpty, reason: 'still working');
    edges.done.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('review'), findsOneWidget);
    expect(edges.ended, contains(7));
  });

  testWidgets('the last page has no "rest" button; one page, no count', (
    tester,
  ) async {
    final edges = await open(tester, 1);
    expect(find.byKey(const ValueKey('crop-use-whole-rest')), findsNothing);
    await tester.tap(find.text(l10n.cropApply));
    await tester.pump();
    edges.progress!(0, 1);
    await tester.pump();
    expect(find.textContaining('1 of 1'), findsNothing);
    expect(edges.applied!.keys, [100]);
  });

  testWidgets('Skip while straightening goes on to Review', (tester) async {
    final edges = await open(tester, 3);
    await tester.tap(find.text(l10n.cropApply));
    await tester.pump();
    await tester.tap(find.text(l10n.cropApply));
    await tester.pump();
    await tester.tap(find.text(l10n.cropApply));
    await tester.pump();
    edges.progress!(0, 3);
    await tester.pump();
    expect(edges.stop!(), isFalse);
    await tester.tap(find.byKey(const ValueKey('straighten-progress-skip')));
    await tester.pump();
    expect(edges.stop!(), isTrue);
    // Pages not started are not failures: no "could not crop" message.
    edges.done.complete(const [101, 102]);
    await tester.pump();
    expect(find.text(l10n.cropFailed), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('review'), findsOneWidget);
  });

  testWidgets('leaving the screen ends the edge check', (tester) async {
    final edges = await open(tester, 3);
    await tester.pumpWidget(const SizedBox());
    expect(edges.ended, [7]);
  });
}
