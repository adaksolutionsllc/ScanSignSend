import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/document_repository.dart';
import '../../../core/services/import_job.dart';
import '../../../core/services/import_job_runner.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';

/// Connects [ImportJobRunner] to the app: loads the jobs left when the app
/// last stopped, gives the runner its translated text, and lets jobs the
/// system paused go on when the app is back in front.
class ImportJobHost extends ConsumerStatefulWidget {
  const ImportJobHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ImportJobHost> createState() => _ImportJobHostState();
}

class _ImportJobHostState extends ConsumerState<ImportJobHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(importJobRunnerProvider).restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final pages = ref.read(importJobRunnerProvider).onAppResumed();
    if (pages.isEmpty || !mounted) return;
    // iOS showed "Task failed" on the lock screen: say that nothing was lost.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.jobResumedNotice(pages.first)),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.read(importJobRunnerProvider).strings = JobStrings(
      checking: l10n.jobCheckingTitle,
      straightening: l10n.jobStraighteningTitle,
      page: l10n.reviewPageOf,
      paused: l10n.jobPausedBanner,
    );
    return widget.child;
  }
}

/// On the Library: one line for each import job (plan 1.3.2) — running,
/// waiting, paused, or pages waiting for the user — with Pause / Resume or
/// Check now. Tapping a line opens the job.
class ImportJobBar extends ConsumerWidget {
  const ImportJobBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runner = ref.watch(importJobRunnerProvider);
    final views = runner.views;
    if (views.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final v in views)
          _JobLine(key: ValueKey('job-bar-${v.docId}'), view: v),
      ],
    );
  }
}

class _JobLine extends ConsumerWidget {
  const _JobLine({super.key, required this.view});
  final JobView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final runner = ref.read(importJobRunnerProvider);
    final v = view;
    final current = (v.done + 1).clamp(1, v.total < 1 ? 1 : v.total);
    final status = switch (v) {
      JobView(step: JobStep.choose) => l10n.jobPagesToCheck(
        runner.toCheckCount(v.docId),
      ),
      JobView(paused: true) => l10n.jobPaused,
      JobView(running: false) => l10n.jobWaiting,
      JobView(total: <= 1, step: JobStep.check) => l10n.cropChecking,
      JobView(total: <= 1) => l10n.cropTitle,
      JobView(step: JobStep.check) => l10n.cropCheckingPage(current, v.total),
      _ => l10n.cropStraighteningPage(current, v.total),
    };
    final open = jobRouteFor(runner, v.docId);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ListTile(
        leading: v.running
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(
                v.step == JobStep.choose
                    ? Icons.crop
                    : v.paused
                    ? Icons.pause_circle_outline
                    : Icons.schedule,
              ),
        title: StreamBuilder<Document?>(
          stream: ref.read(documentRepositoryProvider).watchById(v.docId),
          builder: (context, snap) => Text(
            snap.data?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Text(status),
        onTap: open == null ? null : () => context.push(open),
        trailing: switch (v) {
          JobView(step: JobStep.choose) => TextButton(
            onPressed: open == null ? null : () => context.push(open),
            child: Text(l10n.jobCheckNow),
          ),
          JobView(paused: true) => IconButton(
            key: ValueKey('job-bar-resume-${v.docId}'),
            tooltip: l10n.jobResume,
            icon: const Icon(Icons.play_arrow),
            onPressed: () => runner.resume(v.docId),
          ),
          _ => IconButton(
            key: ValueKey('job-bar-pause-${v.docId}'),
            tooltip: l10n.jobPause,
            icon: const Icon(Icons.pause),
            onPressed: () => runner.pause(v.docId),
          ),
        },
      ),
    );
  }
}
