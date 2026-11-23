# Plan 1.3.2 — big files in the background, with pause and resume

Branch `release/1.3.2`, from `release/1.3.1` (`e76ddb1`, build 23). Build 24.
1.3.1 is in review. The merge into `release/1.4.0` stays on hold until 1.3.1
is live; this branch adds more work to that merge (see "Merge" below).

## What Arun asked for (2026-11-23)

1. A big file can go to the background. The user does not wait on a spinner
   and can use the app while it works.
2. A crash, or the user killing the app, keeps the progress. The user can
   resume from the last checkpoint.
3. Pause and Resume buttons.
4. The phone locks itself during a long job. Can the app stop that?

## Where the time goes today

The long work is the import pipeline. All of it runs inside screen state, so
it stops when the screen goes away:

| # | Step | Code | Runs in |
|---|---|---|---|
| A | Check the edges of each page | `EdgeCheckService.candidatesFor` | `CaptureScreen` / `ReviewScreen` state |
| B | User checks each page | `CropScreen._crops` (memory only) | `CropScreen` state |
| C | Straighten / turn PDF pages into images | `EdgeCheckService.apply` | `CropScreen` state |
| D | Read every page's text for search | `DocumentSorter._storeAllPagesText` | unawaited future |

Facts from the code:

- No step saves progress. A kill during A, B or C loses all of it. A PDF in
  C is all-or-none: the images written so far are deleted.
- B keeps the user's choices in memory only. A kill on page 12 of 18 means 12
  pages to check again.
- C on photo pages already writes each page to the database when it is done.
  Only the list of pages still to do is lost.
- D starts over from page 2 every time.
- The page images for B are in the cache folder
  (`getApplicationCacheDirectory`). The OS can delete them. A resume must
  render them again when they are gone.
- When the phone locks, iOS suspends the app after a few seconds. Android 14+
  freezes a cached app soon after it leaves the screen. This is why the job
  stops when the phone locks.

## Changes

### J1 — One job runner, outside the screens (use the app while it works)

- New `ImportJobRunner` (Riverpod provider, lives for the whole app). It owns
  steps A, C and D. Screens only watch it.
- The progress screen gets a **Keep using the app** button. It goes to the
  Library. The job goes on.
- The Library shows a bar for the running job: title, "Page 7 of 18", time
  left, **Pause**. Tap the bar to open the progress screen again.
- When A finishes and pages need a check, the bar says "5 pages to check" with
  **Check now**. B stays a screen: the user must look at each page.
- A document with a running job opens to its progress screen, not to Review.
  Its pages are changing.
- One job at a time. A second big import waits, and its bar says "Waiting".
  Two jobs would hold four large images in memory at once.

### J2 — Checkpoints (crash and kill safe)

- New drift table `ImportJobs` (schema 9 → 10): document id, step, paused,
  per-page results as JSON, attempts, updated time. One row per document. The
  row goes when the job ends.
- The job saves after **every page**:
  - A: the corners found for that page.
  - B: the user's choice for that page (crop with these corners, or keep).
  - C: the page's new image. Photo pages: as now, plus the row. PDF pages:
    images go to a staging folder next to the PDF and stay there until the
    last page. The switch-over stays one transaction (all or none).
  - D: the text of that page.
- Each image is written to `name.part` and then renamed. A file with its
  final name is always complete.
- On start, the app reads `ImportJobs`. A job left by a crash or a kill shows
  on its document card and in the Library bar as **Paused** with **Resume**
  and **Cancel**. It does not start by itself (see decision 3).
- Crash loop guard: the row counts tries on the current page. When the same
  page stops the app twice, that page is kept as is, the job goes on, and the
  user sees "Page 9 was kept as is".
- Cancel keeps the document as it was before step C (the PDF stays a PDF;
  photo pages already straightened stay straightened, as Skip does now).

### J3 — Pause, Resume, Cancel

- **Pause**: no new page starts. The pages in work (two at most) finish and
  are saved. Then the screen-on hold and the background time are released.
- **Resume**: goes on from the next page not done.
- **Skip** stays as it is now (go on to Review without the rest).
- The time left counts only time spent working, not time paused.

### J4 — Keep the screen on (yes, this is possible)

- While a job runs and the app is on the screen, the phone does not lock by
  itself. iOS: `UIApplication.isIdleTimerDisabled`. Android:
  `FLAG_KEEP_SCREEN_ON`. No permission, no setting.
- The hold ends on pause, done, cancel, or when the user leaves the app.
- A small line under the progress: "The screen stays on until this is done."
- A new method on a small `com.scansignsend/awake` channel. No new package.
- Limit: the user can still lock the phone with the side button. J5 covers
  that.

### J5 — Keep working when the user leaves the app or locks the phone

**iOS 26 and later:** `BGContinuedProcessingTask`. It is for work the user
started in the app. The system shows its own progress, and the user can stop
it there. The job runs in Dart as now; the task only keeps the app awake and
reports progress (Apple DTS: the task can be used only to report progress).

**iOS 15–18:** `beginBackgroundTask` gives about 30 seconds. Then the job
pauses itself at a page boundary, saves, and resumes by itself when the user
comes back.

Known limits (Apple forums, not Apple docs — check on a device):
- Heavy CPU work can run several times slower in the background.
- The system can end the task early. The checkpoint covers this: the job
  pauses and resumes on return.

**Android:** a foreground service while a job runs, with a progress
notification ("Straightening Tax form · 7 of 18") and a Pause action.
- Type `mediaProcessing` on Android 15+ (permission
  `FOREGROUND_SERVICE_MEDIA_PROCESSING`; a 6-hour limit in 24 hours, shared).
  Type `dataSync` on Android 14 (`FOREGROUND_SERVICE_DATA_SYNC`).
  Below 14: no type.
- The service only keeps the process alive. The job still runs in Dart.
- Swiping the app away from Recents ends the Flutter engine. The checkpoint
  covers this: the job shows as Paused on the next start.
- Play Console: a foreground service declaration (App content) with a
  description and a video of the feature. Arun must fill it in.

### J6 — Tests and checks

- Unit: checkpoint written after each page; resume skips done pages; a
  `.part` file is never read; crash guard keeps a page after two tries; PDF
  staging is all-or-none across a resume; pause stops new pages.
- Widget: Library bar (running, paused, waiting, pages to check), progress
  screen buttons, screen-on hold on and off.
- Device check: start an 18-page job, kill the app mid-step C
  (`xcrun simctl terminate` / `adb shell am force-stop`), start it again,
  Resume, and check that the result has 18 pages and no page twice.
- Mutation check on the resume and crash-guard logic.
- New strings in all 7 locales. What's New in all 7 (Play limit 500).

## Store rules

| # | Risk | Source | Mitigation |
|---|---|---|---|
| 1 | Background use must match its purpose | App Review 2.5.4 (task completion is allowed) | Only user-started import work; system progress UI; ends when done |
| 2 | Screen kept on for no reason | One 2.5.1 rejection of a clock app (forum anecdote) | Hold only while a job runs and the app is open; released on pause |
| 3 | Foreground service type must fit the work | Play foreground service policy; Android 14+ type rules | `mediaProcessing` fits (processing media files); declaration + video in Play Console |
| 4 | New Android permissions | Manifest strips other permissions on purpose | Add only the two FGS permissions; no notification permission (decision 2) |

To verify during the build (not guessed): the exact Info.plist keys for
`BGContinuedProcessingTask` (`BGTaskSchedulerPermittedIdentifiers` with a
wildcard id), and the current Play declaration form.

## Out of scope

- Detect Fields and Save & Share on big files. They were not in the report.
  J6 times them on an 18-page file; if one takes over 30 s, it joins the
  runner in a later build.
- A "done" notification on iOS. The system progress UI ends when the job
  ends.

## Size

About 6 working days: J1 2 d, J2 1.5 d, J3 0.5 d, J4 0.25 d, J5 1.5 d
(iOS and Android), J6 with the device runs and strings.

## Merge

After 1.3.1 and 1.3.2 are live, both merge into `release/1.4.0`. 1.4.0 changed
`edge_check_service.dart`, `crop_screen.dart` and `capture_screen.dart` (F5);
J1 moves code out of those files, so expect a hand merge.
