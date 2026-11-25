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

- One JSON file per job in `Documents/jobs/<docId>.json` (`ImportJobStore`):
  step, paused, per-page results, tries. The file goes when the job ends.
  **Changed (2026-11-23):** not a drift table. `release/1.4.0` already uses
  schema versions 10 and 11; a 1.3.2 version 10 would make users who update
  from 1.3.2 skip 1.4.0's own version 10 step.
- The job saves after **every page**:
  - A: the corners found for that page.
  - B: the user's choice for that page (crop with these corners, or keep).
  - C: the page's new image. Photo pages: as now, plus the row. PDF pages:
    images go to a staging folder next to the PDF and stay there until the
    last page. The switch-over stays one transaction (all or none).
  - D: **not checkpointed (changed).** Reading the text for search stays in
    `DocumentSorter`, as in 1.3.1. A kill during D leaves the later pages out
    of search until fields are detected. Small, and outside the user's wait.
- Each image is written to `name.part` and then renamed. A file with its
  final name is always complete.
- On start, the app reads `ImportJobs`. A job left by a crash or a kill shows
  on its document card and in the Library bar as **Paused** with **Resume**
  and **Cancel**. It does not start by itself (see decision 3).
- Crash loop guard: the row counts tries on the current page. When the same
  page stops the app twice, that page is kept as is, the job goes on, and the
  user sees "Page 9 was kept as is".
- **Changed:** no separate Cancel. Skip already means "go on without the
  rest": the PDF stays a PDF, photo pages already straightened stay
  straightened, and the job's staged files are removed.

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
notification ("Straightening “Tax form”", "Page 7 of 18"). **Changed:** no
Pause action in the notification: without the notification permission
(decision 2) most Android 13+ users would not see it. Tap opens the app.
- Type `dataSync` on Android 14+ (`FOREGROUND_SERVICE_DATA_SYNC`; on 15+ a
  6-hour limit in 24 hours, shared). Below 14: no type.
  **Changed (build 28, 2026-11-25):** build 27 used `mediaProcessing` on 15+.
  Android 16 rejected it ("Starting FGS with type none"), so 27 had no
  service on 15+. `dataSync` was checked on the API 36 emulator: foreground,
  and the job went from page 2 to 14 while the app was away.
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
| 3 | Foreground service type must fit the work | Play foreground service policy; Android 14+ type rules | `dataSync`, use case "Local processing: Import or export" (build 28); declaration + video in Play Console |
| 4 | New Android permissions | Manifest strips other permissions on purpose | Add only the two FGS permissions; no notification permission (decision 2) |

To verify during the build (not guessed): the exact Info.plist keys for
`BGContinuedProcessingTask` (`BGTaskSchedulerPermittedIdentifiers` with a
wildcard id), and the current Play declaration form.

### J7 — No network at all (Arun, 2026-11-23: "This shouldn't be there")

iOS Settings shows a **Cellular Data** switch for the app. iOS shows it for
any app that uses the network. Our code does not, but Google ML Kit (the text
reader) does:

- The built app holds `https://play.googleapis.com/log`,
  `https://jmt17.google.com/log` and an experiments/config URL (from
  `MLKitCommon`, `GoogleDataTransport`, `GTMSessionFetcher`).
- ML Kit terms: images and text stay on the device, but the APIs "send
  metrics about the performance and utilization of the APIs" to Google
  (device info, app version, latency).
- The Android release manifest gets `INTERNET` and `ACCESS_NETWORK_STATE`
  from the ML Kit libraries.

So "Nothing is sent", the PrivacyInfo comment and the "Data Not Collected"
label are not fully true today. Documents never leave the phone, but usage
metrics do. The fix makes the claim true; the claim does not change.

- **iOS:** read text with Apple Vision (`VNRecognizeTextRequest`, on the
  device) through a new `com.scansignsend/ocr` channel. Remove the
  `google_mlkit_text_recognition` package, so no ML Kit code is in the iOS app.
  The app reads only Latin script today, and Vision reads all four Latin
  locales (en, fr, es, pt).
- **Android:** call ML Kit text recognition from Kotlin on the same channel
  (bundled model, as now), and strip `INTERNET` and `ACCESS_NETWORK_STATE`
  from the manifest. The metrics cannot leave without them.
- `OcrService` keeps its interface. Only lines and words are used
  (`PageLayoutService`), and Vision gives both.
- **Gate:** field detection must find as many fields on iOS with Vision as
  with ML Kit, on the test forms and the device check. If Vision is worse,
  stop and tell Arun before going on.
- Check on Android with no `INTERNET`: purchase and restore, the camera
  scanner (Play services), the review prompt.
- The Cellular Data row should not come back on a fresh install. An existing
  install may keep the row: iOS remembers it. Not verified yet.

## Out of scope

- Detect Fields and Save & Share on big files. They were not in the report.
  J6 times them on an 18-page file; if one takes over 30 s, it joins the
  runner in a later build.
- A "done" notification on iOS. The system progress UI ends when the job
  ends.

## Decisions (Arun, 2026-11-23: all recommendations accepted)

1. Android foreground service: **yes**. Arun fills in the Play declaration.
2. Notification permission: **not asked** in 1.3.2.
3. After a crash or kill: **Paused · Resume**, not by itself. A system pause
   (older iOS) resumes by itself.
4. Scope: **import steps only**. Detect Fields and Save are timed first.

## Built (2026-11-23, commits c22dac3, 47235d8, 0e41f13)

- J1–J5 and J7 as above, with the changes marked. Files:
  `import_job.dart`, `import_job_runner.dart`, `background_work_service.dart`,
  `job_screen.dart`, `import_job_bar.dart`, `BackgroundWorkPlugin.swift`,
  `ImportWorkService.kt`, `TextRecognitionPlugin.swift/.kt`.
- Tests: runner (13), edge resume (6), job screen and bar (8), crop and
  Review flows rewritten, OCR answer parsing; 272 in all. Mutation check: 5
  of 5 caught.
- Device check: new step pauses a 6-page straighten, leaves to the Library,
  and finishes it with a second runner (a stand-in for a restarted app).
- OCR gate (4 demo forms rendered as scans; fields from OCR vs from the
  PDF text layer): iOS Vision 38/50 matched, 2 extra; Android ML Kit 38/50
  matched, 4 extra. Vision is not worse: the gate passes. Time per page:
  2.3 s Vision on the simulator (CPU only), 0.76 s ML Kit on the emulator.
  Not measured on a phone yet.
- Device checks green on the iOS simulator and the Android emulator,
  including pause → Library bar → restart → resume (24 pages, none twice).
- Still to do: a real kill on a phone (iOS and Android), the iOS 26 system
  progress on a phone, Play Console foreground-service declaration (Arun),
  What's New ×7, build 24.

## Tester feedback on build 24 (2026-11-23)

- "About 65 minutes left" on page 7 of 18. The time left was the time since
  the job started, divided by the pages done. When the phone stopped the app
  (screen off), that time still grew. Fix: time each page. A page in work
  when the app comes back is not timed. Time left = the middle time of the
  last 5 pages × the pages left.
- The light lines ("Lining up the margins…") confused the user, who had
  already lined up the edges. Removed (6 strings × 7 languages).
- "Save to Files" from the share sheet saved a text file ("Signed with Scan
  Sign Send") next to each PDF. The share sheet now gets the PDF only. The
  email subject stays the document title.
- Screen off: the app holds the screen on during a job. The tester's screen
  went off, so most likely the phone was locked by hand. Below iOS 26 the
  phone gives about 30 s, then the job pauses and goes on when the app is
  back (as decided). On iOS 26 the system progress should keep it going:
  not yet seen on a phone.

## Size

About 7.5 working days: J1 2 d, J2 1.5 d, J3 0.5 d, J4 0.25 d, J5 1.5 d
(iOS and Android), J7 1.5 d, J6 with the device runs and strings.

## Merge

After 1.3.1 and 1.3.2 are live, both merge into `release/1.4.0`. 1.4.0 changed
`edge_check_service.dart`, `crop_screen.dart` and `capture_screen.dart` (F5);
J1 moves code out of those files, so expect a hand merge.
