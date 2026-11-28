import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a long import job is (plan 1.3.2).
enum JobStep {
  /// Finding the edges of each page (EdgeCheckService.candidatesFor).
  check,

  /// Waiting for the user to look at the pages found (CropScreen).
  choose,

  /// Straightening, or turning a PDF into images (EdgeCheckService.apply).
  straighten,
}

/// The checkpoint of a long import job, saved after every page so that a
/// crash or a kill loses at most the pages in work.
class ImportJob {
  ImportJob({
    required this.docId,
    required this.step,
    required this.tag,
    this.paused = false,
    Map<int, List<double>?>? found,
    Map<int, List<double>?>? choices,
    Set<int>? done,
    Map<int, int>? tries,
    Set<int>? kept,
  }) : found = found ?? {},
       choices = choices ?? {},
       done = done ?? {},
       tries = tries ?? {},
       kept = kept ?? {};

  final int docId;
  JobStep step;

  /// Names the files this job writes, so a resume finds them again and
  /// Cancel can remove them.
  final String tag;

  /// The user paused it, or the app stopped while it ran.
  bool paused;

  /// Step check: page id → corners found (null: nothing to fix). A page not
  /// here is still to check.
  final Map<int, List<double>?> found;

  /// Step choose: page id → the corners to crop to (null: keep whole). A
  /// page not here is still to look at.
  final Map<int, List<double>?> choices;

  /// Step straighten: pages done.
  final Set<int> done;

  /// Pages started and not finished, with how many times they were started.
  final Map<int, int> tries;

  /// Pages kept as they are because they stopped the app twice.
  final Set<int> kept;

  /// A page that stopped the app this many times is not tried again.
  static const maxTries = 2;

  /// Pages the crash guard gives up on: started [maxTries] times and never
  /// finished.
  Set<int> get givenUp => {
    for (final e in tries.entries)
      if (e.value >= maxTries) e.key,
  };

  Map<String, Object?> toJson() => {
    'docId': docId,
    'step': step.name,
    'tag': tag,
    'paused': paused,
    'found': {for (final e in found.entries) '${e.key}': e.value},
    'choices': {for (final e in choices.entries) '${e.key}': e.value},
    'done': done.toList(),
    'tries': {for (final e in tries.entries) '${e.key}': e.value},
    'kept': kept.toList(),
  };

  static ImportJob fromJson(Map<String, dynamic> j) {
    Map<int, List<double>?> quads(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        int.parse(e.key as String): e.value == null
            ? null
            : [for (final x in e.value as List) (x as num).toDouble()],
    };
    return ImportJob(
      docId: j['docId'] as int,
      step: JobStep.values.byName(j['step'] as String),
      tag: j['tag'] as String,
      paused: j['paused'] as bool? ?? false,
      found: quads(j['found']),
      choices: quads(j['choices']),
      done: {for (final x in (j['done'] as List?) ?? const []) x as int},
      tries: {
        for (final e in ((j['tries'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): e.value as int,
      },
      kept: {for (final x in (j['kept'] as List?) ?? const []) x as int},
    );
  }
}

/// Keeps each [ImportJob] as `<docId>.json` in the app's `jobs` folder. A
/// file is written as `.part` and then renamed, so a file with its final
/// name is always whole. Writes go one after another.
class ImportJobStore {
  ImportJobStore({Future<Directory> Function()? folder})
    : _folder = folder ?? _defaultFolder;

  final Future<Directory> Function() _folder;
  Future<void> _last = Future.value();

  static Future<Directory> _defaultFolder() async => Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'jobs'),
  );

  Future<File> _file(int docId) async =>
      File(p.join((await _folder()).path, '$docId.json'));

  /// Every job saved. A file that can't be read is skipped (and removed).
  Future<List<ImportJob>> all() async {
    final dir = await _folder();
    if (!dir.existsSync()) return const [];
    final out = <ImportJob>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        out.add(
          ImportJob.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (e) {
        debugPrint('ImportJobStore: dropping ${f.path}: $e');
        await _deleteQuietly(f);
      }
    }
    return out;
  }

  Future<void> save(ImportJob job) {
    final text = jsonEncode(job.toJson());
    return _queue(() async {
      final file = await _file(job.docId);
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      await part.writeAsString(text, flush: true);
      await part.rename(file.path);
    });
  }

  Future<void> delete(int docId) =>
      _queue(() async => _deleteQuietly(await _file(docId)));

  Future<void> _queue(Future<void> Function() write) {
    final next = _last.then((_) => write()).catchError((Object e) {
      debugPrint('ImportJobStore: $e');
    });
    _last = next;
    return next;
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      await f.delete();
    } catch (_) {}
  }
}
