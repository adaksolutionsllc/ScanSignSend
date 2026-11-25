// Import jobs (plan 1.3.2): the long steps of an import run outside the
// screens, are saved after every page, can be paused and resumed, survive a
// restart, skip a page that stopped the app twice, run one at a time, and
// hold the screen on only while they run.

import 'dart:async';
import 'dart:convert';
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

/// Pages 11, 12 and 13 of every document. Each page waits for the test to
/// [release] it, unless [auto].
class _FakeEdges implements EdgeCheckService {
  final pageIds = [11, 12, 13];

  /// Pages the check finds worth a crop.
  var worth = {11, 12};
  var auto = false;
  var pdf = false;
  final started = <int>[];
  final ended = <int>[];
  final discarded = <String>[];
  final knownSeen = <Map<int, List<double>?>>[];
  Map<int, EdgeQuad>? applied;
  String? appliedTag;
  final _waiting = <Completer<void>>[];

  Future<void> _gate() {
    if (auto) return Future.value();
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  bool get pageWaiting => _waiting.isNotEmpty;

  void release() => _waiting.removeAt(0).complete();

  EdgeCandidate _candidate(int page) =>
      EdgeCandidate(pageId: page, imagePath: '/p/$page.jpg', quad: _quad);

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
    knownSeen.add(Map.of(known));
    final out = <EdgeCandidate>[];
    for (final (i, page) in pageIds.indexed) {
      if (stop?.call() ?? false) return const [];
      if (hold?.call() ?? false) return out;
      onProgress?.call(i, pageIds.length);
      if (known.containsKey(page)) {
        if (known[page] != null) out.add(_candidate(page));
        continue;
      }
      await onStart?.call(page);
      started.add(page);
      await _gate();
      final quad = worth.contains(page) ? _quad : null;
      if (quad != null) out.add(_candidate(page));
      await onPage?.call(page, quad);
    }
    return out;
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
    appliedTag = tag;
    final todo = [
      for (final p in crops.keys.toList()..sort())
        if (!done.contains(p)) p,
    ];
    var finished = done.length;
    for (final page in todo) {
      if ((stop?.call() ?? false) || (hold?.call() ?? false)) break;
      await onStart?.call(page);
      started.add(page);
      await _gate();
      await onDone?.call(page);
      onProgress?.call(++finished, crops.length);
    }
    return const [];
  }

  @override
  Future<bool> isPdfBacked(int docId) async => pdf;

  @override
  Future<void> discardStaged(int docId, String tag) async => discarded.add(tag);

  @override
  void begin(int docId) {}

  @override
  void end(int docId) => ended.add(docId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePhone extends BackgroundWorkService {
  final screen = <bool>[];
  final calls = <String>[];
  final pausedTitles = <String>[];

  @override
  Future<void> keepScreenOn(bool on) async => screen.add(on);

  @override
  Future<void> begin(
    String title,
    String subtitle,
    int done,
    int total, {
    String paused = '',
  }) async {
    calls.add('begin $title | $subtitle');
    pausedTitles.add(paused);
  }

  @override
  Future<void> progress(
    String title,
    String subtitle,
    int done,
    int total, {
    String paused = '',
  }) async {
    calls.add('progress $done/$total');
    pausedTitles.add(paused);
  }

  @override
  Future<void> end() async => calls.add('end');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tmp;
  late _FakeEdges edges;
  late _FakePhone phone;
  late ImportJobStore store;
  late ImportJobRunner runner;
  late int doc;

  ImportJobRunner newRunner() =>
      ImportJobRunner(
          edges: edges,
          docRepo: DocumentRepository(db),
          store: store,
          phone: phone,
        )
        ..strings = JobStrings(
          checking: (t) => 'Checking $t',
          straightening: (t) => 'Straightening $t',
          page: (c, t) => 'Page $c of $t',
          paused: (t) => 'Paused $t',
        );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('jobs');
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    edges = _FakeEdges();
    phone = _FakePhone();
    store = ImportJobStore(folder: () async => tmp);
    runner = newRunner();
    doc = (await DocumentRepository(db).createDocument('Tax form')).id;
  });
  tearDown(() async {
    // Let a job still writing finish before its folder goes.
    edges.auto = true;
    while (edges.pageWaiting) {
      edges.release();
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  // The checkpoints are real file writes: wait in real time.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  Map<String, dynamic>? saved(int id) {
    final f = File('${tmp.path}/$id.json');
    return f.existsSync()
        ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
        : null;
  }

  test('check, choose, straighten: saved after every page', () async {
    await runner.startCheck(doc);
    await settle();
    expect(saved(doc)!['step'], 'check');
    expect(saved(doc)!['tries'], {'11': 1}, reason: 'page 11 in work');
    expect(runner.view(doc)!.running, isTrue);

    edges.release();
    await settle();
    expect((saved(doc)!['found'] as Map).keys, ['11']);
    expect(saved(doc)!['tries'], {'12': 1});
    // Page 12 finishes; page 13 runs at once.
    edges
      ..auto = true
      ..release();
    await settle();

    expect(runner.view(doc)!.step, JobStep.choose);
    expect(runner.toCheckCount(doc), 2);
    expect(runner.takeResult(doc)!.found, 2);
    final (candidates, chosen) = await runner.toChoose(doc);
    expect(candidates.map((c) => c.pageId), [11, 12]);
    expect(chosen, isEmpty);

    await runner.choose(doc, 11, _quad);
    await runner.choose(doc, 12, null);
    await settle();
    expect(saved(doc)!['choices'], {'11': _quad.toList(), '12': null});
    expect(runner.toCheckCount(doc), 0);

    await runner.startStraighten(doc);
    await settle();
    expect(edges.applied!.keys, [11], reason: 'page 12 kept whole');
    expect(
      edges.appliedTag,
      saved(doc) == null ? isNotNull : saved(doc)!['tag'],
    );
    expect(runner.hasJob(doc), isFalse);
    expect(saved(doc), isNull, reason: 'the checkpoint goes with the job');
    expect(edges.ended, [doc]);
    expect(runner.takeResult(doc)!.skipped, isFalse);
    expect(phone.screen.last, isFalse);
    expect(phone.calls.last, 'end');
  });

  test('pause: no new page; resume goes on from the next page', () async {
    await runner.startCheck(doc);
    await settle();
    await runner.pause(doc);
    expect(saved(doc)!['paused'], isTrue);
    edges.release(); // page 11 in work finishes
    await settle();
    expect(edges.started, [11], reason: 'no page after the pause');
    expect(runner.view(doc)!.paused, isTrue);
    expect(runner.view(doc)!.running, isFalse);
    expect(phone.screen.last, isFalse, reason: 'paused lets the phone lock');

    edges.auto = true;
    await runner.resume(doc);
    await settle();
    expect(edges.started, [11, 12, 13]);
    expect(edges.knownSeen.last.keys, contains(11));
    expect(runner.view(doc)!.step, JobStep.choose);
  });

  test('after a restart the job is paused and goes on where it was', () async {
    await store.save(
      ImportJob(
        docId: doc,
        step: JobStep.check,
        tag: 'abcd1234',
        found: {11: _quad.toList()},
        tries: {12: 1},
      ),
    );
    final after = newRunner();
    await after.restore();
    expect(after.view(doc)!.paused, isTrue, reason: 'not by itself');
    expect(edges.started, isEmpty);

    edges.auto = true;
    await after.resume(doc);
    await settle();
    expect(edges.started, [12, 13], reason: 'page 11 was done');
    expect(after.view(doc)!.step, JobStep.choose);
    expect(after.toCheckCount(doc), 2);
  });

  test('a restored job of a deleted document is dropped', () async {
    await store.save(ImportJob(docId: 999, step: JobStep.check, tag: 't'));
    final after = newRunner();
    await after.restore();
    expect(after.hasJob(999), isFalse);
    expect(saved(999), isNull);
  });

  test('a page that stopped the app twice is kept as it is', () async {
    await store.save(
      ImportJob(
        docId: doc,
        step: JobStep.check,
        tag: 'abcd1234',
        found: {11: _quad.toList()},
        tries: {12: 2},
      ),
    );
    final after = newRunner();
    await after.restore();
    edges.auto = true;
    await after.resume(doc);
    await settle();
    expect(edges.started, [13], reason: 'page 12 not tried again');
    expect(after.toCheckCount(doc), 1, reason: 'page 12 offered no crop');
    expect(after.takeResult(doc)!.kept, {12});
  });

  test('straightening: a crashing photo page is skipped', () async {
    await store.save(
      ImportJob(
        docId: doc,
        step: JobStep.straighten,
        tag: 'abcd1234',
        choices: {11: _quad.toList(), 12: _quad.toList()},
        done: {},
        tries: {12: 2},
      ),
    );
    final after = newRunner();
    await after.restore();
    edges.auto = true;
    await after.resume(doc);
    await settle();
    expect(edges.applied!.keys, [11]);
    expect(after.takeResult(doc)!.kept, {12});
  });

  test('straightening: a crashing PDF page keeps the whole PDF', () async {
    edges.pdf = true;
    await store.save(
      ImportJob(
        docId: doc,
        step: JobStep.straighten,
        tag: 'abcd1234',
        choices: {11: _quad.toList()},
        tries: {12: 2},
      ),
    );
    final after = newRunner();
    await after.restore();
    await after.resume(doc);
    await settle();
    expect(edges.applied, isNull, reason: 'nothing converted');
    expect(edges.discarded, ['abcd1234']);
    expect(after.hasJob(doc), isFalse);
  });

  test('a resumed straighten skips the pages done', () async {
    await store.save(
      ImportJob(
        docId: doc,
        step: JobStep.straighten,
        tag: 'abcd1234',
        choices: {11: _quad.toList(), 12: _quad.toList(), 13: null},
        done: {11},
      ),
    );
    final after = newRunner();
    await after.restore();
    edges.auto = true;
    await after.resume(doc);
    await settle();
    expect(edges.started, [12]);
    expect(edges.appliedTag, 'abcd1234', reason: 'finds the files again');
  });

  test('one job at a time; the next waits', () async {
    final second = (await DocumentRepository(db).createDocument('Lease')).id;
    await runner.startCheck(doc);
    await runner.startCheck(second);
    await settle();
    expect(runner.view(doc)!.running, isTrue);
    expect(runner.view(second)!.waiting, isTrue);
    edges.auto = true;
    for (var i = 0; i < 3; i++) {
      if (edges.pageWaiting) edges.release();
      await settle();
    }
    expect(runner.view(doc)!.step, JobStep.choose);
    expect(runner.view(second)!.step, JobStep.choose);
    expect(runner.views.map((v) => v.docId), [doc, second]);
  });

  test('Skip ends a paused job; a straighten discards its files', () async {
    await store.save(
      ImportJob(
        docId: doc,
        step: JobStep.straighten,
        tag: 'abcd1234',
        choices: {11: _quad.toList()},
        paused: true,
      ),
    );
    final after = newRunner();
    await after.restore();
    await after.skip(doc);
    expect(after.hasJob(doc), isFalse);
    expect(edges.discarded, ['abcd1234']);
    expect(after.takeResult(doc)!.skipped, isTrue);
    expect(edges.ended, [doc]);
  });

  test('Skip while checking goes on without the rest', () async {
    await runner.startCheck(doc);
    await settle();
    await runner.skip(doc);
    edges.release();
    await settle();
    expect(runner.hasJob(doc), isFalse);
    expect(edges.started, [11]);
    expect(runner.takeResult(doc)!.skipped, isTrue);
  });

  test('the system pause goes on when the app is back', () async {
    await runner.startCheck(doc);
    await settle();
    phone.onExpired!();
    await settle();
    edges.release();
    await settle();
    expect(runner.view(doc)!.paused, isTrue);
    edges.auto = true;
    runner.onAppResumed();
    await settle();
    expect(runner.view(doc)!.step, JobStep.choose);
  });

  test('after a system pause: the page it goes on from', () async {
    await runner.startCheck(doc);
    await settle();
    phone.onExpired!();
    await settle();
    edges.release(); // page 11 done, then the job pauses
    await settle();
    expect(runner.view(doc)!.paused, isTrue);
    // The progress still names page 1 (told when a page starts); the job
    // goes on from page 2.
    expect(runner.view(doc)!.done, 0);
    expect(runner.onAppResumed(), [2]);
    await settle();
    expect(runner.view(doc)!.paused, isFalse);
    // Back again with nothing paused by the system: nothing to tell.
    expect(runner.onAppResumed(), isEmpty);
  });

  test('nothing paused by the system: no page to tell', () async {
    await runner.startCheck(doc);
    await settle();
    expect(runner.onAppResumed(), isEmpty);
  });

  test('the phone gets the paused title with the progress', () async {
    await runner.startCheck(doc);
    await settle();
    edges.release();
    await settle();
    expect(phone.pausedTitles, isNotEmpty);
    expect(phone.pausedTitles.toSet(), {'Paused Tax form'});
  });

  test('time left: from page times, not from time away from the app', () async {
    await runner.startCheck(doc);
    await settle();
    expect(runner.view(doc)!.left, isNull, reason: 'no page timed yet');
    edges.release(); // page 11: about 150 ms
    await settle();
    // Page 12 is in work when the user comes back after the screen was off.
    runner.onAppResumed();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    edges.release();
    await settle();
    // Page 13 is left: one page at page 11's time, not page 12's.
    final left = runner.view(doc)!.left!;
    expect(left, greaterThan(const Duration(milliseconds: 100)));
    expect(left, lessThan(const Duration(milliseconds: 500)));
  });

  test('the screen is held only while a job runs', () async {
    await runner.startCheck(doc);
    await settle();
    expect(phone.screen, [true]);
    expect(phone.calls.first, 'begin Checking Tax form | Page 1 of 3');
    edges.auto = true;
    edges.release();
    await settle();
    expect(phone.screen, [true, false]);
    expect(phone.calls.last, 'end');
  });
}
