import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/import_job.dart';
import '../../../core/services/import_job_runner.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/router.dart';
import '../../../shared/utils/time_left.dart';

/// A long import job of one document (plan 1.3.2): checking the edges, or
/// straightening. Shows the progress, with Pause / Resume, Skip and Keep
/// using the app. The job itself runs in [ImportJobRunner], so leaving this
/// screen does not stop it.
///
/// When the check finds pages to look at, goes on to the crop screen; when
/// the job ends, to Review (or back to it, when opened from there).
class JobScreen extends ConsumerStatefulWidget {
  const JobScreen({super.key, required this.docId, this.popWhenDone = false});

  final int docId;

  /// Opened from Review (Straighten pages): return to it when done.
  final bool popWhenDone;

  @override
  ConsumerState<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends ConsumerState<JobScreen> {
  bool _leaving = false;

  /// Moves on once the job no longer needs this screen. Called after each
  /// build, since the job changes while the screen shows.
  void _moveOn(JobView? view) {
    if (_leaving) return;
    final runner = ref.read(importJobRunnerProvider);
    final router = GoRouter.of(context);
    final back = widget.popWhenDone ? '?back=1' : '';
    if (view != null && view.step == JobStep.choose) {
      _leaving = true;
      router.pushReplacement(
        '${AppRoutes.crop.replaceAll(':docId', '${widget.docId}')}$back',
      );
      return;
    }
    if (view != null) return;
    _leaving = true;
    final result = runner.takeResult(widget.docId);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (result != null && !result.skipped) {
      final message = result.kept.isNotEmpty
          ? l10n.jobKeptAsIs(result.kept.length)
          : result.failed.isNotEmpty
          ? l10n.cropFailed
          : widget.popWhenDone && result.found == 0
          ? l10n.reviewStraightenNone
          : null;
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
    if (widget.popWhenDone && router.canPop()) {
      router.pop();
    } else {
      router.pushReplacement(
        AppRoutes.review.replaceAll(':docId', '${widget.docId}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final runner = ref.watch(importJobRunnerProvider);
    final view = runner.view(widget.docId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _moveOn(runner.view(widget.docId));
    });
    final checking = view?.step != JobStep.straighten;
    final (done, total) = (view?.done ?? 0, view?.total ?? 0);
    final current = (done + 1).clamp(1, total < 1 ? 1 : total);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cropTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (view == null || view.running)
                const CircularProgressIndicator()
              else
                Icon(
                  view.paused ? Icons.pause_circle_outline : Icons.schedule,
                  size: 48,
                ),
              const SizedBox(height: 20),
              Text(
                total > 1
                    ? (checking
                          ? l10n.cropCheckingPage(current, total)
                          : l10n.cropStraighteningPage(current, total))
                    : (checking ? l10n.cropChecking : l10n.cropTitle),
                textAlign: TextAlign.center,
              ),
              if (view != null && view.paused) ...[
                const SizedBox(height: 8),
                Text(l10n.jobPausedHint, textAlign: TextAlign.center),
              ] else if (view != null && view.waiting) ...[
                const SizedBox(height: 8),
                Text(l10n.jobWaiting),
              ] else if (view != null && view.running && total > 1) ...[
                if (view.left case final left?) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeLeftText(l10n, left),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.jobScreenOn,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                // iOS may stop the work when the phone is locked, and then
                // shows "Task failed" on the lock screen (tester, build 26).
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.jobLockHint,
                    key: const ValueKey('job-lock-hint'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              const SizedBox(height: 20),
              if (view != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (view.paused)
                      FilledButton.icon(
                        key: const ValueKey('job-resume'),
                        onPressed: () => runner.resume(widget.docId),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.jobResume),
                      )
                    else
                      OutlinedButton.icon(
                        key: const ValueKey('job-pause'),
                        onPressed: () => runner.pause(widget.docId),
                        icon: const Icon(Icons.pause),
                        label: Text(l10n.jobPause),
                      ),
                    // Go on without the rest of the job.
                    TextButton(
                      key: ValueKey(
                        checking
                            ? 'edge-check-skip'
                            : 'straighten-progress-skip',
                      ),
                      onPressed: () => runner.skip(widget.docId),
                      child: Text(l10n.actionSkip),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextButton.icon(
                key: const ValueKey('job-keep-using'),
                onPressed: () {
                  _leaving = true;
                  context.go(AppRoutes.library);
                },
                icon: const Icon(Icons.home_outlined),
                label: Text(l10n.jobKeepUsing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
