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

### H1 — Ask before the edge check on multi-page files (the user decides)

When an import has **2 or more pages** that can be straightened (photos, or a
PDF that is only photos), ask before step 1–2:

> **Straighten the pages?**
> The app finds the edges of each page so you can crop them. This takes
> longer for bigger files. This file has 18 pages.
> [Skip] [Straighten]

- One photo: no question. The check is quick, so it runs as now.
- Typed PDFs and PDFs with form fields: no question, no check (as now).
- **Skip** goes straight to Review. Nothing is converted.
- Settings: a new switch **"Straighten imported pages"** with three
  choices: Ask (default) · Always · Never. (Decision 1.)

### H2 — Faster straightening (steps 4 and 5)

- Render each PDF page to raw pixels and write the JPEG **once**. No PNG
  encode or decode.
- Crop a chosen page from those same pixels, in the same pass. No JPEG
  decode and second encode.
- Do two pages at the same time, in background isolates.
- Expected: about 3× faster for a fully cropped file (from the Mac numbers).
  H7 measures the real result before release.

### H3 — Show progress

- "Checking page 5 of 18…" during steps 1–2.
- "Straightening page 5 of 18…" during steps 4–5, in place of the bare
  spinner.

### H4 — "Use whole image for the rest" on the crop screen

On a multi-page file, the user must now tap 18 times. Add a text button
that keeps the crops chosen so far and leaves the remaining pages as they
are. (Decision 2.)

### H5 — Read text for search after the edge step

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

`straightenAskTitle`, `straightenAskBody` (with page count), `straightenSkip`,
`straightenGo`, `edgeCheckingPage`, `straighteningPage`, `cropUseWholeRest`,
`settingsStraightenTitle`, `settingsStraightenAsk`, `settingsStraightenAlways`,
`settingsStraightenNever`, What's new.

## Release

- Version 1.3.1 (22). What's new ×7: faster imports of big files; you choose
  whether to straighten pages; Skip fields · Save & Share.
- Store screenshots do not change.
- Before release, check that iOS 1.3.0 is live (it was in App Review on
  2026-11-20).
- After release: fast-forward `main`, merge into `release/1.4.0`.

## Size

About 2–3 days: H1 1 d, H2 1 d, H3–H5 0.5 d, H7 and release 0.5 d.
