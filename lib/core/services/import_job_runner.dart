import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'background_work_service.dart';
import 'document_edges.dart';
import 'document_repository.dart';
import 'edge_check_service.dart';
import 'import_job.dart';

final importJobRunnerProvider = ChangeNotifierProvider<ImportJobRunner>(
  (ref) => ImportJobRunner(
    edges: ref.watch(edgeCheckServiceProvider),
    docRepo: ref.watch(documentRepositoryProvider),
    store: ImportJobStore(),
    phone: BackgroundWorkService(),
  ),
);

/// Translated text for the phone's own progress (Android notification, iOS
/// system progress). The runner has no BuildContext, so the app sets it.
class JobStrings {
  const JobStrings({
    required this.checking,
    required this.straightening,
    required this.page,
    required this.paused,
  });

  /// "Checking the edges of “{title}”".
  final String Function(String title) checking;

  /// "Straightening “{title}”".
  final String Function(String title) straightening;

  /// "Page {current} of {total}".
  final String Function(int current, int total) page;

  /// "“{title}” paused. Open the app to go on.": the system's progress
  /// title once it has ended the background time.
  final String Function(String title) paused;

  static final fallback = JobStrings(
    checking: (t) => t,
    straightening: (t) => t,
    page: (c, t) => '$c / $t',
    paused: (t) => t,
  );
}

/// What a screen shows for one job.
class JobView {
  const JobView({
    required this.docId,
    required this.step,
    required this.paused,
    required this.running,
    required this.done,
    required this.total,
    this.left,
  });

  final int docId;
  final JobStep step;
  final bool paused;
  final bool running;

  /// Pages done, of [total]. Zero of zero before the job has run (a job
  /// waiting, or one restored after the app stopped).
  final int done, total;

  /// About how long the rest takes, from the time of recent pages. Null
  /// until a page was timed.
  final Duration? left;

  /// Ready to run, but another job runs first.
  bool get waiting => !paused && !running && step != JobStep.choose;
}

/// How a job ended, for the screen that shows it.
class JobResult {
  const JobResult({
    this.found = 0,
    this.failed = const [],
    this.kept = const {},
    this.skipped = false,
  });

  /// Pages the check found worth a crop (none: nothing to fix).
  final int found;

  /// Pages whose crop failed (kept whole).
  final List<int> failed;

  /// Pages kept as they are because they stopped the app twice.
  final Set<int> kept;

  /// The user tapped Skip.
  final bool skipped;
}

/// Runs the long steps of an import outside any screen (plan 1.3.2, J1–J3,
/// J5): checking the edges and straightening. The user can leave the
/// screen, use the app, pause, resume and skip. Every page is saved
/// ([ImportJobStore]), so after a crash or a kill the job shows as paused
/// and goes on from where it was.
///
/// One job runs at a time: each page holds a large image in memory. While
/// one runs, the screen stays on and the phone is asked to keep the app
/// running ([BackgroundWorkService]).
class ImportJobRunner extends ChangeNotifier {
  ImportJobRunner({
    required EdgeCheckService edges,
    required DocumentRepository docRepo,
    required ImportJobStore store,
    required BackgroundWorkService phone,
  }) : _edges = edges,
       _docRepo = docRepo,
       _store = store,
       _phone = phone {
    _phone.onExpired = _systemPause;
  }

  final EdgeCheckService _edges;
  final DocumentRepository _docRepo;
  final ImportJobStore _store;
  final BackgroundWorkService _phone;

  /// Set by the app whenever its language may have changed.
  JobStrings strings = JobStrings.fallback;

  /// In the order started: the first ready one runs next.
  final _jobs = <int, ImportJob>{};
  int? _running;
  final _progress = <int, (int, int)>{};
  // The time of each page, for the time left. Not the time since the job
  // started: that counts the time the phone stopped the app (screen off).
  final _pageTimes = <int, List<Duration>>{};
  final _pageClock = Stopwatch();
  var _pageTimed = false;
  final _skipped = <int>{};
  final _systemPaused = <int>{};
  final _results = <int, JobResult>{};
  final _titles = <int, String>{};
  bool _phoneBusy = false;

  /// Loads the jobs left when the app last stopped. A job that was running
  /// then shows as paused: if a page stopped the app, starting again by
  /// itself could stop it again.
  Future<void> restore() async {
    for (final job in await _store.all()) {
      if (await _docRepo.getById(job.docId) == null) {
        await _store.delete(job.docId);
        continue;
      }
      if (job.step != JobStep.choose) job.paused = true;
      _jobs.putIfAbsent(job.docId, () => job);
    }
    notifyListeners();
  }

  bool hasJob(int docId) => _jobs.containsKey(docId);

  JobView? view(int docId) {
    final job = _jobs[docId];
    if (job == null) return null;
    final (done, total) = _progress[docId] ?? (0, 0);
    return JobView(
      docId: docId,
      step: job.step,
      paused: job.paused,
      running: _running == docId,
      done: done,
      total: total,
      left: _timeLeft(docId, total - done),
    );
  }

  /// The middle time of the last 5 pages, times the pages left: one slow
  /// page does not change it much.
  Duration? _timeLeft(int docId, int pagesLeft) {
    final times = _pageTimes[docId];
    if (times == null || times.isEmpty || pagesLeft <= 0) return null;
    final recent = times.sublist(math.max(0, times.length - 5))..sort();
    return recent[recent.length ~/ 2] * pagesLeft;
  }

  List<JobView> get views => [for (final id in _jobs.keys) view(id)!];

  /// Step choose: how many pages wait for the user.
  int toCheckCount(int docId) {
    final job = _jobs[docId];
    if (job == null) return 0;
    return job.found.entries
        .where((e) => e.value != null && !job.choices.containsKey(e.key))
        .length;
  }

  /// How the job of [docId] ended, once; null while it runs.
  JobResult? takeResult(int docId) => _results.remove(docId);

  /// Starts checking the edges of [docId]'s pages. Nothing new when the
  /// document already has a job.
  Future<void> startCheck(int docId) async {
    if (_jobs.containsKey(docId)) return;
    final job = ImportJob(
      docId: docId,
      step: JobStep.check,
      tag: const Uuid().v4().substring(0, 8),
    );
    _jobs[docId] = job;
    _results.remove(docId);
    _edges.begin(docId);
    await _store.save(job);
    notifyListeners();
    _pump();
  }

  /// The pages to look at in the crop screen, in page order, and the user's
  /// choices so far (page id → corners, or null for keep whole).
  Future<(List<EdgeCandidate>, Map<int, EdgeQuad?>)> toChoose(int docId) async {
    final job = _jobs[docId];
    if (job == null || job.step != JobStep.choose) {
      return (const <EdgeCandidate>[], const <int, EdgeQuad?>{});
    }
    // Every page is known, so nothing is checked again: this only finds
    // each page's image.
    final candidates = await _edges.candidatesFor(docId, known: job.found);
    return (
      candidates,
      {for (final e in job.choices.entries) e.key: EdgeQuad.fromList(e.value)},
    );
  }

  /// The user's choice for one page: crop to [quad], or keep it whole.
  Future<void> choose(int docId, int pageId, EdgeQuad? quad) async {
    final job = _jobs[docId];
    if (job == null) return;
    job.choices[pageId] = quad?.toList();
    await _store.save(job);
  }

  /// The user has looked at the pages: straighten the ones chosen.
  Future<void> startStraighten(int docId) async {
    final job = _jobs[docId];
    if (job == null) return;
    job
      ..step = JobStep.straighten
      ..paused = false;
    await _store.save(job);
    notifyListeners();
    _pump();
  }

  Future<void> pause(int docId) async {
    final job = _jobs[docId];
    if (job == null || job.step == JobStep.choose) return;
    job.paused = true;
    await _store.save(job);
    notifyListeners();
  }

  Future<void> resume(int docId) async {
    final job = _jobs[docId];
    if (job == null) return;
    _systemPaused.remove(docId);
    job.paused = false;
    await _store.save(job);
    notifyListeners();
    _pump();
  }

  /// Skip: go on without the rest of the job. Pages already straightened
  /// stay straightened; a PDF stays a PDF (all or none).
  Future<void> skip(int docId) async {
    final job = _jobs[docId];
    if (job == null) return;
    _skipped.add(docId);
    notifyListeners();
    // A job that isn't running ends here; a running one at its next page.
    if (_running != docId) {
      if (job.step == JobStep.straighten) {
        await _edges.discardStaged(docId, job.tag);
      }
      await _finish(job, JobResult(kept: job.kept, skipped: true));
    }
  }

  /// The app is in front again: jobs the system paused go on. Returns the
  /// page each of them goes on from, for a message that nothing was lost.
  List<int> onAppResumed() {
    // The phone may have stopped the app while away: don't time this page.
    _pageTimed = false;
    final pages = <int>[];
    for (final id in [..._systemPaused]) {
      final job = _jobs[id];
      if (job == null) continue;
      // From the pages finished: the progress is told only when a page
      // starts, and the paused job has not started the next one.
      final finished = job.step == JobStep.straighten
          ? job.done.length
          : job.found.length;
      final (_, total) = _progress[id] ?? (0, 0);
      final page = math.min(finished + 1, math.max(total, 1));
      pages.add(page);
      unawaited(resume(id));
    }
    return pages;
  }

  /// The system ended the app's background time: pause at the next page,
  /// and go on when the user is back.
  void _systemPause() {
    final id = _running;
    if (id == null) return;
    _systemPaused.add(id);
    unawaited(pause(id));
  }

  void _pump() {
    if (_running != null) return;
    final next = _jobs.values
        .where((j) => !j.paused && j.step != JobStep.choose)
        .firstOrNull;
    if (next == null) {
      unawaited(_phoneIdle());
      return;
    }
    _running = next.docId;
    notifyListeners();
    unawaited(
      _run(next).whenComplete(() {
        _running = null;
        notifyListeners();
        _pump();
      }),
    );
  }

  Future<void> _run(ImportJob job) async {
    final id = job.docId;
    _titles[id] = (await _docRepo.getById(id))?.title ?? '';
    _pageTimed = false;
    try {
      // Pages that stopped the app twice are not tried again.
      for (final page in job.givenUp) {
        job.tries.remove(page);
        job.kept.add(page);
        if (job.step == JobStep.check) job.found[page] = null;
      }
      switch (job.step) {
        case JobStep.check:
          await _check(job);
        case JobStep.straighten:
          await _straighten(job);
        case JobStep.choose:
          break;
      }
    } catch (e) {
      debugPrint('ImportJobRunner: $e');
      if (_jobs.containsKey(id)) {
        await _finish(
          job,
          JobResult(kept: job.kept, failed: job.choices.keys.toList()),
        );
      }
    }
  }

  Future<void> _check(ImportJob job) async {
    final id = job.docId;
    final candidates = await _edges.candidatesFor(
      id,
      known: job.found,
      onProgress: (done, total) => _onProgress(job, done, total),
      stop: () => _skipped.contains(id),
      hold: () => job.paused,
      onStart: (page) => _started(job, page),
      onPage: (page, quad) async {
        _timed(id);
        job.tries.remove(page);
        job.found[page] = quad?.toList();
        await _store.save(job);
      },
    );
    if (job.paused && !_skipped.contains(id)) return;
    if (_skipped.contains(id) || candidates.isEmpty) {
      await _finish(
        job,
        JobResult(kept: job.kept, skipped: _skipped.contains(id)),
      );
      return;
    }
    job.step = JobStep.choose;
    await _store.save(job);
    _results[id] = JobResult(found: candidates.length, kept: job.kept);
  }

  Future<void> _straighten(ImportJob job) async {
    final id = job.docId;
    final crops = <int, EdgeQuad>{
      for (final e in job.choices.entries)
        if (!job.kept.contains(e.key) && e.value != null)
          e.key: EdgeQuad.fromList(e.value)!,
    };
    // A PDF turns into images all at once: a page that can't be rendered
    // keeps the whole file as it is.
    if (crops.isEmpty ||
        (job.kept.isNotEmpty && await _edges.isPdfBacked(id))) {
      await _edges.discardStaged(id, job.tag);
      await _finish(job, JobResult(kept: job.kept));
      return;
    }
    var failed = const <int>[];
    try {
      failed = await _edges.apply(
        id,
        crops,
        onProgress: (done, total) => _onProgress(job, done, total),
        stop: () => _skipped.contains(id),
        hold: () => job.paused,
        done: job.done,
        tag: job.tag,
        onStart: (page) => _started(job, page),
        onDone: (page) async {
          _timed(id);
          job.tries.remove(page);
          job.done.add(page);
          await _store.save(job);
        },
      );
    } catch (e) {
      debugPrint('ImportJobRunner: straighten failed: $e');
      failed = crops.keys.toList();
    }
    if (job.paused && !_skipped.contains(id)) return;
    await _finish(
      job,
      JobResult(failed: failed, kept: job.kept, skipped: _skipped.contains(id)),
    );
  }

  Future<void> _started(ImportJob job, int page) async {
    _pageClock
      ..reset()
      ..start();
    _pageTimed = true;
    job.tries[page] = (job.tries[page] ?? 0) + 1;
    await _store.save(job);
  }

  void _timed(int docId) {
    if (_pageTimed) {
      _pageTimes.putIfAbsent(docId, () => []).add(_pageClock.elapsed);
    }
    _pageTimed = false;
  }

  void _onProgress(ImportJob job, int done, int total) {
    final id = job.docId;
    _progress[id] = (done, total);
    notifyListeners();
    final title = _titles[id] ?? '';
    final heading = job.step == JobStep.check
        ? strings.checking(title)
        : strings.straightening(title);
    final line = strings.page((done + 1).clamp(1, total), total);
    final paused = strings.paused(title);
    if (_phoneBusy) {
      unawaited(_phone.progress(heading, line, done, total, paused: paused));
    } else {
      _phoneBusy = true;
      unawaited(_phone.keepScreenOn(true));
      unawaited(_phone.begin(heading, line, done, total, paused: paused));
    }
  }

  Future<void> _phoneIdle() async {
    if (!_phoneBusy) return;
    _phoneBusy = false;
    await _phone.keepScreenOn(false);
    await _phone.end();
  }

  Future<void> _finish(ImportJob job, JobResult result) async {
    final id = job.docId;
    _jobs.remove(id);
    _progress.remove(id);
    _pageTimes.remove(id);
    _skipped.remove(id);
    _systemPaused.remove(id);
    _results[id] = result;
    await _store.delete(id);
    _edges.end(id);
    notifyListeners();
  }
}
