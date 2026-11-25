// QA gaps for import jobs (plan 1.3.2), found by mutation checks:
// - an unreadable checkpoint file is skipped and removed, and the other jobs
//   still load;
// - a second start while a job runs never runs that same job twice.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/db/app_database.dart';
import 'package:scan_sign_send/core/services/background_work_service.dart';
import 'package:scan_sign_send/core/services/document_edges.dart';
import 'package:scan_sign_send/core/services/document_repository.dart';
import 'package:scan_sign_send/core/services/edge_check_service.dart';
import 'package:scan_sign_send/core/services/import_job.dart';
import 'package:scan_sign_send/core/services/import_job_runner.dart';

const _quad = EdgeQuad(
  math.Point(0.1, 0.1),
  math.Point(0.9, 0.1),
  math.Point(0.9, 0.9),
  math.Point(0.1, 0.9),
);

/// Pages 11, 12 and 13 of every document; each page waits for [release].
class _GatedEdges implements EdgeCheckService {
  final started = <(int, int)>[]; // (docId, pageId)
  final _waiting = <Completer<void>>[];

  void release() => _waiting.removeAt(0).complete();
  bool get pageWaiting => _waiting.isNotEmpty;

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
    final out = <EdgeCandidate>[];
    for (final (i, page) in [11, 12, 13].indexed) {
      if (stop?.call() ?? false) return const [];
      if (hold?.call() ?? false) return out;
      onProgress?.call(i, 3);
      if (known.containsKey(page)) continue;
      await onStart?.call(page);
      started.add((docId, page));
      final c = Completer<void>();
      _waiting.add(c);
      await c.future;
      out.add(EdgeCandidate(pageId: page, imagePath: '/p.jpg', quad: _quad));
      await onPage?.call(page, _quad);
    }
    return out;
  }

  @override
  void begin(int docId) {}

  @override
  void end(int docId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietPhone extends BackgroundWorkService {
  @override
  Future<void> keepScreenOn(bool on) async {}
  @override
  Future<void> begin(
    String t,
    String s,
    int d,
    int n, {
    String paused = '',
  }) async {}
  @override
  Future<void> progress(
    String t,
    String s,
    int d,
    int n, {
    String paused = '',
  }) async {}
  @override
  Future<void> end() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('jobs_qa'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test(
    'an unreadable checkpoint is skipped and removed; others load',
    () async {
      final store = ImportJobStore(folder: () async => tmp);
      await store.save(ImportJob(docId: 1, step: JobStep.check, tag: 'good'));
      // A file left half written by an older build, or damaged on disk.
      final bad = File('${tmp.path}/2.json')..writeAsStringSync('{"docId": 2,');
      final wrongShape = File('${tmp.path}/3.json')
        ..writeAsStringSync('{"docId": "x", "step": "nope"}');

      final jobs = await store.all();
      expect(jobs.map((j) => j.docId), [1]);
      expect(bad.existsSync(), isFalse);
      expect(wrongShape.existsSync(), isFalse);
    },
  );

  test('a second start while a job runs never runs that job twice', () async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repo = DocumentRepository(db);
    final edges = _GatedEdges();
    final runner = ImportJobRunner(
      edges: edges,
      docRepo: repo,
      store: ImportJobStore(folder: () async => tmp),
      phone: _QuietPhone(),
    );
    final a = (await repo.createDocument('A')).id;
    final b = (await repo.createDocument('B')).id;

    await runner.startCheck(a);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await runner.startCheck(b); // asks the runner to pump again
    await runner.resume(a); // and again
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(edges.started, [(a, 11)], reason: 'one page of one job at a time');

    while (edges.pageWaiting || runner.views.any((v) => v.running)) {
      if (edges.pageWaiting) edges.release();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(edges.started.where((s) => s.$1 == a).map((s) => s.$2), [
      11,
      12,
      13,
    ]);
    await db.close();
  });
}
