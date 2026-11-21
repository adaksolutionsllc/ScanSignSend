# Scan Sign Send 1.4.0 — plan

Status: draft, 2026-11-21. Branch `plan/1.4.0` (off `release/1.3.0`). No code yet.

1.3.0 shipped automatic categories, naming, search through page text, the
edge check for imported photos and skip-fields saving. Everything else from
`docs/ease-of-use-plan.md` moved here, plus what we learned while shipping
1.3.0. The detail for each carried item is still in that plan; this file says
what changes, in what order, and what still needs a decision.

## 1. What goes in

### A. Faster filling (≈ 4 d)
| # | Item | Size | Notes |
|---|---|---|---|
| A1 | "Next field" guided filling | 1.5 d | ease-of-use-plan §3.3. Reading order, Next/Done on the input sheet, "N left →" in Fill mode. |
| A2 | Typed signature and initials | 1 d | §3.4. Draw / Type tabs, bundled OFL script font. Needed for screen-reader users (C1). |
| A3 | PreFill learns from your picks | 1.5 d | §3.13. `PrefillHints` table (schema v10), phrase → slot, never the value. |

### B. A real library (≈ 4.5 d)
| # | Item | Size | Notes |
|---|---|---|---|
| B1 | Add pages to a document | 1.5 d | §3.8. Scanner or photo import, appended. Photos go through the 1.3.0 edge check. Drafts and fillable only. |
| B2 | Merge and split | 2 d | Restored below (§3). Uses 1.3.0 multi-select. |
| B3 | Search inside forms with their own fields | 1 d | New. Form PDFs are found only by name today, because `ocrText` holds the form marker. Move the marker to its own column (schema v10, with A3) and store the text. |

### C. Getting files in and out (≈ 6 d)
| # | Item | Size | Notes |
|---|---|---|---|
| C1 | iOS Share Extension | 3–4 d | §3.7. Photos → Share → Scan Sign Send. Reuses the 1.3.0 batch import and edge check. Second App ID, App Group, profile. |
| C2 | Home-screen quick actions | 0.5 d | §3.6. Scan, Open PDF, Fill my last draft. |
| C3 | Smaller files | 1 d | Restored below (§3). 200 dpi default + "Smaller file" switch on Send. |
| C4 | Password-protected PDF | 1.5 d + 0.5 d spike | Restored below (§3). PDFKit on iOS; dropped if the spike fails. |

### D. Voice (≈ 6 d)
| # | Item | Size | Notes |
|---|---|---|---|
| D1 | Siri / Assistant shortcuts | 2 d | §3.15a. Shares `shortcuts.xml` with C2. |
| D2 | Voice filling in Fill mode | 4 d | §3.15b. On-device recognition only. Needs A1 (field order). No hi/ta/te on iOS. |

### E. Quality and store (≈ 4 d)
| # | Item | Size | Notes |
|---|---|---|---|
| E1 | Accessibility pass | 2 d | §3.5. Goes last so it covers every new screen. Declare only what passes a device run. |
| E2 | Android emulator working again | 0.5 d | New. emulator-5554 has no package service and /data is 92% full; it holds another app's data, so ask before wiping. Without it, no Android device check runs. |
| E3 | Store screenshots + preview video | 1 d | New. Show categories, the edge check and the 1.4.0 features. The 1.2.0 preview file was lost to `flutter clean`: keep a copy outside `build/`. |
| E4 | 1.3.0 review leftover | 0.25 d | New. Backfill re-reads category hints and the sort setting per document; load them once. |

**Total ≈ 25 working days** if everything stays in one release.

## 2. Order

Each step ends with the pre-commit routine (analyze, tests, iOS + Android
device check, screenshots).

1. E2 (emulator) first: every later step needs an Android run.
2. Schema v10 in one migration: `PrefillHints` (A3) and the form-marker
   column (B3), with a migration test from v9.
3. A1 → A2 → A3.
4. B1 → B2 → B3.
5. C2 → C3 → C4 spike → C4 → C1.
6. D1 → D2.
7. E4, then E1 across all screens.
8. E3, What's New ×7, review notes, privacy line for voice, encryption
   questionnaire (only if C4 ships).

## 3. Restored detail (lost from ease-of-use-plan.md in 42b60f8)

### 3.10 Merge and split (2 d)
- **Merge:** select 2 or more documents → Merge → a new draft with their pages
  in selection order (user can reorder in Review) and every field copied with
  its `pageIndex` offset. The originals are kept. The user can delete them.
  - Completed (flattened) documents join as imported pages of their
    exported PDF (`path#page=N` refs), with no fields.
  - Page files are referenced, not copied, so the existing
    `_isFolderStillReferenced` / unreferenced-file checks in
    `DocumentRepository` must cover the shared files. That needs a test that
    deletes an original and then opens the merge.
  - New since 1.3.0: a merge must not mix image pages and `#page=` pages of
    different PDFs in a way the exports can't handle (they assume one source
    PDF). Either convert PDF pages to images on merge (as the edge check
    does) or teach both exports several sources. Decide in the spike.
- **Split / Extract pages:** in Review, select pages → "Extract to new
  document" (copy, original untouched) or "Split here". Fields go with
  their page.
- AcroForm fields from an imported form keep their `pdfFieldName`. When two
  merged forms share a field name, the second one's name is given a suffix
  on export so the live form doesn't link them.

### 3.11 Smaller files (1 d)
- **Always:** the press and fillable exports downscale scanned pages to 200
  dpi at the page size (an A4 page is ≈ 1654×2339 px) and re-encode at JPEG
  q85. Measure with the 10-page Phase 1 batch before settling the numbers.
- **On Send:** a "Smaller file" switch (150 dpi, q65; grayscale if the page
  filter is B&W) that writes a separate copy for sharing. The Send screen
  shows both sizes ("2.1 MB → 640 KB").
- Imported vector PDFs aren't recompressed. The switch is hidden when nothing
  can shrink.

### 3.12 Password-protected PDF (1.5 d)
- The Send screen gets a "Password-protect" switch: enter it twice, a
  "can't be recovered" note, and a minimum of 6 characters. It writes an
  AES-256 encrypted copy for sharing only. The password is **never stored**,
  and the in-app copy stays unencrypted.
- **iOS: PDFKit** (`PDFDocument.write(to:withOptions:)` with
  `userPasswordOption`/`ownerPasswordOption`) through a small method channel,
  so the encryption is the OS's and the export-compliance answer stays simple.
- **Android: Syncfusion `PdfSecurity`** (AES-256).
- **Spike first (0.5 d, gates the item):** a *fillable* export encrypted by
  PDFKit must still open and fill in Acrobat, Preview and Chrome. If it
  fails, password protection applies only to completed PDFs on iOS.
- Wording: "Password-protect" / "Anyone opening this PDF needs the password".
  Never "secure", "military grade" or "unbreakable".

## 4. Still decided (from 2026-10-23, unchanged)
- Share Extension: build it. Voice: on-device recognition only.
- Password on iOS through PDFKit, after the spike.
- Smaller files by default (200 dpi) plus the Send switch, after measuring.
- Accessibility: declare only what passes a device run; VoiceOver only after
  a full scan → fill → sign → send run.

## 5. Decisions needed
1. **One release or two?** ≈ 25 days in one 1.4.0, or 1.4.0 (A + B + C2/C3 +
   E, ≈ 12 d) then 1.5.0 (C1, C4, D, ≈ 13 d). Recommendation: two — 1.3.0
   showed that a shorter release ships sooner and gets tested better.
2. **Voice still wanted?** It is the biggest item (6 d) and works in only
   4 of the 7 languages on iOS. Recommendation: keep it, in the second release.
3. **Android emulator:** may I wipe emulator-5554 (it holds
   com.adak.market_edge data), or should I create a new AVD?
