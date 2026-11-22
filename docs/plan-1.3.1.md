# Plan 1.3.1 — faster imports of big files

Branch `release/1.3.1`, from the 1.3.0 release (`v1.3.0-build21`). Build 22.
After release, merge it into `release/1.4.0`. Expect conflicts in
`edge_check_service.dart`, `crop_screen.dart` and `capture_screen.dart`,
because 1.4.0 changed them (F5).

## The report (premium user, 2026-11-22)

> It takes a very long time to process. May be trying to detect fields. An
> option to just scan and send without detection would be great. I have a 18
> page document and after going through crop, it is spinning for a long time.

The screenshot shows "Check the edges", "Page 18 of 18", and a spinner.

## What is slow

The spinner is **not** field detection. It is the edge step finishing its
work after the user taps through the last page (`EdgeCheckService.apply`).
Field detection runs only when the user taps Detect Fields in Review, and
Review already has **Skip fields · Save & Share**. This user never got to
Review.

An import of an 18-page photo PDF goes through these steps:

| # | Step | When | Work for each page |
|---|---|---|---|
| 1 | Is the PDF only photos? | "Checking the edges…" | Syncfusion reads the text layer of every page |
| 2 | Find the edges | "Checking the edges…" | Render at 150 dpi, then Vision (iOS) or the Dart detector (Android) |
| 3 | User checks each page | Crop screen | 18 taps, one page at a time |
| 4 | **Turn the PDF into images** | Spinner (screenshot) | Render at 200 dpi → PNG → decode PNG in Dart → encode JPEG in Dart. **All 18 pages**, also those that are not cropped |
| 5 | **Crop** | Spinner (screenshot) | Decode JPEG in Dart → straighten in Dart → encode JPEG in Dart |
| 6 | Read text for search | In the background, from the start | ML Kit on every page. It runs at the same time as steps 1–5 and uses the same CPU. After step 4 deletes the PDF, it reads some pages again |

Steps 4 and 5 run one page at a time, in pure Dart (the `image` package).

### Measured (MacBook, AOT build, `image` package, one A4 page at 200 dpi)

| Operation | Time |
|---|---|
| Decode PNG | 331 ms |
| Encode JPEG (q90) | 605 ms |
| Decode JPEG | 268 ms |
| Straighten (`cropToQuad`) | 977 ms |
| Dart edge detector (Android) | 483 ms |

Steps 4 + 5 for one cropped page: about **2.8 s on the Mac**, plus the
platform render. A phone is usually slower than a Mac for this work, and step
6 runs at the same time. For 18 pages, expect a wait of a minute or more on
the spinner. Not measured on a phone yet: item H7 adds this measurement.

## Changes

### H1 — Ask before the edge check on multi-page files (the user decides) ✅

When an import has **2 or more pages** that can be straightened (photos, or a
PDF that is only photos), the app asks first:

> **Straighten the pages?**
> The app finds the edges of each page so you can crop them. For these 18
> pages this takes about 2 minutes.
> [Skip] [Straighten]

- The time is rough. It comes from this phone's own past runs (a running
  average per page, kept in SharedPreferences). Before the first run it is a
  first guess: 1.5 s to check and 4 s to straighten each page.
- One photo: no question. The check is quick, so it runs as before.
- Typed PDFs and PDFs with form fields: no question, no check (as before).
- **Skip** goes straight to Review. Nothing is converted.
- No setting (Arun, 2026-11-22): the app always asks. A forgotten
  "Always" or "Never" setting would confuse users later.

### H2 — Faster straightening (steps 4 and 5) ✅

- Each PDF page is rendered to raw pixels, cropped when chosen, and written
  as a JPEG **once**. No PNG encode or decode, no second JPEG.
- One page per render call, so a long PDF is never all in memory at once.
- Two pages at a time, in background isolates.

### H3 — Progress, time left, Skip ✅

- "Checking page 5 of 18…" and "Straightening page 5 of 18…".
- Below: "About 1 minute left" (from the speed so far), and a light line
  that changes every 3 s ("Squaring up the corners…", "Measuring twice,
  cropping once…"; six lines in each language).
- A **Skip** button on both. Skip while checking: on to Review, nothing
  changed. Skip while straightening: photo pages already done stay done; a
  PDF stays as it was (all or none).

### H4 — "Use whole image for the rest" on the crop screen ✅

Keeps the crops chosen so far; the remaining pages stay as they are.

### H5 — Read text for search after the edge step ✅

Start step 6 only when the edge step ends (or is skipped). Then it does not
slow the edge step, and it reads each page once. Sorting (page 1 only) still
starts at once.

### H6 — No change to field detection

Detect Fields stays a choice in Review, next to **Skip fields · Save &
Share**. Mention the Skip button in What's new so users find it.

### H7 — Tests and a timing check

- Unit tests: the H1 rules (pages, file kinds, the setting), the H2 one-pass
  output (same pixels as before for a cropped page, all-or-none on failure).
- Device check: an 18-page photo PDF; log the time of each step on the
  simulator and the emulator; check the question, Skip, and the progress
  text.
- Real-phone timing (Arun's phone, upgrade in place, never `flutter
  install`): before and after.

## Strings (all 7 locales)

`straightenAskTitle`, `straightenAskBodyMinutes`, `straightenAskBodyQuick`,
`straightenGo`, `cropCheckingPage`, `cropStraighteningPage`,
`cropUseWholeRest`, `progressMinutesLeft`, `progressUnderMinuteLeft`,
`progressQuip1`–`6`. Also fixed: three European Portuguese crop strings from
1.3.0 ("A verificar os contornos…" → "Verificando as bordas…").

## Release

- Version 1.3.1 (22). What's new ×7: faster imports of big files; you choose
  whether to straighten pages; Skip fields · Save & Share.
- Store screenshots do not change.
- Before release, check that iOS 1.3.0 is live (it was in App Review on
  2026-11-20).
- After release: fast-forward `main`, merge into `release/1.4.0`.

## Size

About 2–3 days: H1 1 d, H2 1 d, H3–H5 0.5 d, H7 and release 0.5 d.
