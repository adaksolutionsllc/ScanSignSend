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
| A3 | ✅ PreFill learns from your picks | 1.5 d | §3.13. `PrefillHints` table (schema v10), phrase → slot, never the value. |

### B. A real library (≈ 4.5 d)
| # | Item | Size | Notes |
|---|---|---|---|
| B1 | ✅ Add pages to a document | 1.5 d | §3.8. Scanner or photo import, appended. Photos go through the 1.3.0 edge check. Drafts and fillable only. |
| B2 | ✅ Merge and split | 2 d | Restored below (§3). Uses 1.3.0 multi-select. |
| B3 | Search inside forms with their own fields | 1 d | New. Form PDFs are found only by name today, because `ocrText` holds the form marker. Move the marker to its own column (schema v10, with A3) and store the text. |

### C. Getting files in and out (≈ 6 d)
| # | Item | Size | Notes |
|---|---|---|---|
| C1 | ✅ iOS Share Extension | 3–4 d | §3.7. Photos → Share → Scan Sign Send. Reuses the 1.3.0 batch import and edge check. Second App ID, App Group, profile. |
| C2 | ✅ Home-screen quick actions | 0.5 d | §3.6. Scan, Open PDF, Fill my last draft. |
| C3 | ✅ Smaller files | 1 d | Restored below (§3). 200 dpi default + "Smaller file" switch on Send. |
| C4 | ✅ Password-protected PDF (protect on Send + open protected PDFs) | 1.5 d + 0.5 d spike | Restored below (§3). PDFKit on iOS; dropped if the spike fails. |

### D. Voice — D1 IN, D2 ON HOLD (Arun, 2026-11-21)
D1 shortcuts are needed. D2 voice filling waits for a final answer; the phones' own Voice Control / Voice Access and keyboard dictation already cover much of it once E1 labels every control.
| # | Item | Size | Notes |
|---|---|---|---|
| D1 | ✅ Siri shortcuts (iOS) | 2 d | §3.15a. Same three actions as the C2 quick actions. Android: no new code (see §3.15a). |
| D2 | Voice filling in Fill mode | 4 d | §3.15b. On-device recognition only. Needs A1 (field order). No hi/ta/te on iOS. |

### E. Quality and store (≈ 4 d)
| # | Item | Size | Notes |
|---|---|---|---|
| E1 | Accessibility pass | 2 d | §3.5. Goes last so it covers every new screen. Declare only what passes a device run. |
| E2 | ✅ Android emulator working again (wiped 2026-11-21; 1.3.0 device check green) | done | New. emulator-5554 has no package service and /data is 92% full; it holds another app's data, so ask before wiping. Without it, no Android device check runs. |
| E3 | Store screenshots + preview video | 1 d | New. Show categories, the edge check and the 1.4.0 features. The 1.2.0 preview file was lost to `flutter clean`: keep a copy outside `build/`. |
| E4 | 1.3.0 review leftover | 0.25 d | New. Backfill re-reads category hints and the sort setting per document; load them once. |

### F. Scanner tools from the competitor review (≈ 7 d) — added 2026-11-21, see §6
| # | Item | Size | Notes |
|---|---|---|---|
| F1 | ✅ Copy text | 1 d | Correction: `Pages.ocrText` was never written; only the document's joined text was. Now `PageTextService` reads a page on demand (PDF text layer, else OCR, one page at a time) and keeps it in `Pages.ocrText`; Rotate and Crop clear it. A "Text" button in the Review and Viewer app bars opens one sheet for the whole document: each page's selectable text, Copy all, Share as .txt. A page with no text says that scans are read in Latin script only (ML Kit runs `TextRecognitionScript.latin`), so a Hindi, Tamil or Telugu scan gets that note, not a blank. F2 reuses the same text. |
| F2 | Share as images, text or Word | 1.5 d | The Send screen gets a "Format" choice: PDF (default), Images (one JPG per page), Text (.txt), Word (.docx, text only, one heading per page). The .docx is built in Dart (it is a zip of XML), with no new package. |
| F3 | Receipt details + CSV | 3 d | For documents in Receipts: date, merchant, total, tax and currency, read on the device from the page text. The user can correct them. Select receipts, then "Export to spreadsheet" writes a .csv that Excel, Sheets and Numbers open. Schema v11: a `ReceiptDetails` table. Amount formats in all 7 locales (₹, "1.234,56"). Goes last in F, so it can move to 1.5 if the release runs long. |
| F4 | ✅ Better page filters | 1.5 d | **Clean** removes shadows and whitens the paper (divide by the paper's brightness, found by shrink → max filter → blur). It scales with the image, so the Review preview (1000 px, made off the UI thread) matches the export. **Apply to all pages** sits under each page's filters (image pages only). The fillable-export filter bug was already fixed in C3: every export goes through `pageImageForPdf`. Fill mode still shows the unfiltered photo, as before. |
| F5 | ✅ Crop any page in Review | 0.5 d | Reuses the 1.3.0 `CropScreen` from a Crop button next to Rotate. Image pages only: a PDF page is vector and has no Rotate either. It starts on the whole image: a page in Review was already cropped by the scanner or offered the import edge check, so a second guess is more often wrong. The page's fields move with the crop; a field in the cut-away part is deleted. A crop replaces the image (no undo, the same as Rotate). |

Considered and left out:
- **Watermark:** declined 2026-10-10 (memory `no-watermark`).
- **Add Text:** already exists. Any text field placed in the field editor does this job.
- **Adjust sliders:** F4's presets cover the need.
- **Curvature correction:** neither VisionKit nor the ML Kit scanner flattens curved book pages. A dewarp model is research work, not a release item.
- **Convert to Excel:** general table recognition is not reliable enough to claim. Only receipts (F3) produce a spreadsheet.
- **Edit the text inside a scan:** not possible without retyping the page. Copy text (F1) and Word export (F2) cover the real need.

### G. New store screenshots (replaces E3, ≈ 2 d)
See §7.

**Total ≈ 27 working days** without voice (≈ 33 with it). Before F and G it was ≈ 19.

## 2. Order

Each step ends with the pre-commit routine (analyze, tests, iOS + Android
device check, screenshots).

1. E2 (emulator) first: every later step needs an Android run.
2. Schema v10 in one migration: `PrefillHints` (A3) and the form-marker
   column (B3), with a migration test from v9.
3. A1 → A2 → A3.
4. B1 → B2 → B3.
5. C2 → C3 → C4 spike → C4 → C1.
6. D1 (shortcuts). D2 only if it comes off hold.
7. F5 → F4 → F1 → F2 → F3. F3 is last so it can move to 1.5 if needed.
8. E4, then E1 across all screens, the F screens included.
9. G screenshots and video, What's New ×7, review notes, privacy line for
   receipt details, and the encryption questionnaire (only if C4 ships).

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
  - **Built (2026-11-21):** page files are *copied*, not shared (the edge
    crop deletes a page's old file without checking other documents), and PDF
    pages are rendered to images, so the exports see one kind of page. A
    form's own fields become app fields. Radio groups get a per-document tag.
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
- **Measured 2026-11-21** (10 synthetic camera-size pages, noisy): camera
  28.6 MB → standard 3.9 MB → smaller 1.3 MB. JPEG 4:2:0; B&W stays three
  equal channels (this encoder's one-channel JPEG decodes red).
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
- **Spike result (2026-11-21).** A real fillable export (text, date,
  checkbox, radio pair, signature) was encrypted both ways, then opened,
  filled and saved in PDFium 159 (Chrome's engine) and PDFKit (Preview, iOS
  Files). Acrobat isn't on this Mac: still to check by hand.
  | | PDFKit (iOS path) | Syncfusion (Android path) |
  |---|---|---|
  | Strength | AES-128 (V4 R4) | AES-256 (V5 R6, `aesx256BitRevision6`) |
  | Wrong password refused / right one opens | yes / yes | yes / yes |
  | Values kept; type into a field and save, password kept (PDFium, PDFKit) | yes | yes |
  | Radio buttons | **broken**: PDFKit moves the radio flag from the field to its buttons and sets the value to an empty name; PDFium then draws squares and the group doesn't work | intact |
  PDFKit reads radios correctly; it's only what it *writes*. Every iOS
  password-protected fillable PDF would go through that write.
- **Decided (Arun, 2026-11-21):** iOS uses PDFKit (the OS's encryption)
  for completed PDFs and fillable forms without radio buttons; it isn't
  offered for a fillable form with radio buttons on iOS. Android uses
  Syncfusion AES-256 R6 for everything.
- **Added (Arun, 2026-11-21): opening protected PDFs.** Import asks for the
  password (again after a wrong one), keeps the app's copy without it, and
  the form comes in ready to fill. Both directions verified: PDFKit opens the
  Android file; the app opens the iPhone file (fixture
  `test/fixtures/pdfkit_protected_form.pdf`).
- **Found:** any form PDFKit writes (Preview, iOS Files, our iOS protection)
  has no /P on its widgets and the annotation list is indirect; Syncfusion
  then gives fields no page and the import dropped them all. Fixed with
  `widgetPagesByName` (pdf_widget_pages.dart, Syncfusion internals, pinned
  28.2.x).
- **Release docs to do:** privacy policy line (password never stored; an
  opened protected PDF is kept without its password on the device), and
  App Store Connect's encryption questions for 1.4.0.
- Export compliance: not verified. Apple's pages didn't load when checked
  (2026-11-21). Confirm in App Store Connect's encryption questions before
  choosing a bundled-library path on iOS.
- Wording: "Password-protect" / "Anyone opening this PDF needs the password".
  Never "secure", "military grade" or "unbreakable".

### 3.7 iOS Share Extension (3–4 d) — ✅ 2026-11-21
- Photos (or Files, Mail) → Share → Scan Sign Send, for photos and PDFs. A
  native extension copies them into the App Group inbox and opens the app,
  which imports them through the "Open in…" path: one share = one document.
  Design and test notes: `docs/.llm_wiki/native-bridges-and-plugins.md`.
- Verified on the iOS 26.5 simulator with a UI test driving Photos: the
  extension is in the share sheet's app row, opens the app with no prompt,
  and the photo arrives under its own name. The device check covers the
  app side (inbox → import → 2-page document).
- **Fixed on the way:** the app's inbox check first used
  `sceneDidBecomeActive`, which Flutter never passes to the plugin.
- **Release to do:**
  - First signed build registers the App ID
    `com.adakVentures.scanSignSend.ShareExtension` and App Group
    `group.com.adakVentures.scanSignSend` (Xcode, automatic signing). Ask
    Arun first: it changes the developer account.
  - Test on a real iPhone (TestFlight): share from Photos, also with the app
    killed and with App Lock on.
  - The CI `beta` lane needs a second provisioning profile; the local
    release script doesn't.
  - Found, not caused by C1: on the iOS simulator, Vision returns a wrong
    strip (bottom quarter) from about the third edge check of a run, for
    the same test photo it found correctly before; macOS Vision is right
    every time. Check on a real iPhone: import the same photo 4–5 times.
  - App Review risk (judgement, not verified): opening the app from a share
    extension uses the responder chain, which Apple doesn't document for
    share extensions. Many apps ship it; if it stops working, the extension
    says "Open Scan Sign Send to continue" and the app collects the share
    the next time it comes to the front.

### 3.15a Siri shortcuts (2 d) — ✅ iOS, 2026-11-22
- **iOS:** App Intents (iOS 16+) in `ios/Runner/AppShortcuts.swift`: Scan a
  document, Open a PDF, Fill my last draft — the C2 quick actions, through
  the same Dart handler (app lock first). "Fill my form with my details" is
  a second phrase of Fill my last draft: Fill mode already offers PreFill,
  and nothing is filled until the user taps. With no draft, the app says so.
  Titles and phrases in all 7 languages (`Localizable.strings`,
  `AppShortcuts.strings`); the l10n test checks them against the Swift
  source. Siri itself has no Tamil or Telugu; Spotlight and the Shortcuts
  app still show the shortcuts.
- **Verified:** the build extracts the 3 intents and 5 phrases; iOS indexes
  them (Spotlight's Top Hit for "Fill my last draft" is "Fill my last draft
  in Scan Sign Send"); widget test for the Dart side (queued at launch,
  pinged later, no-draft message).
- **Not verified:** running one. On the iOS 26.5 simulator every App
  Shortcut fails with "Couldn't find shortcut" (linkd: "Couldn't find
  AppShortcutsProvider"), a minimal SwiftUI control app too. Check on a real
  iPhone (TestFlight): Siri, Spotlight and the Shortcuts app, cold and warm,
  with App Lock on.
- **Android — no new code (decided 2026-11-22):** App Actions survive only
  through `shortcuts.xml` (`actions.xml` is retired), with no confirmation
  that Gemini uses them; Google points to AppFunctions (Android 16) instead.
  "Hey Google, open Scan Sign Send" works anyway, and the C2 quick actions
  cover the shortcuts. Revisit with AppFunctions in a later release.

## 4. Still decided (from 2026-10-23, unchanged)
- Share Extension: build it. Voice: on-device recognition only.
- Password on iOS through PDFKit, after the spike.
- Smaller files by default (200 dpi) plus the Send switch, after measuring.
- Accessibility: declare only what passes a device run; VoiceOver only after
  a full scan → fill → sign → send run.

## 5. Decisions

**Decided (Arun, 2026-11-21):** one release — everything above ships as 1.4.0.
**Decided (Arun, 2026-11-21, after the competitor review):**
- F3 receipts ships in this release.
- Screenshot 8 says "Pay once. Keep it." in both stores.
- All of A–G ships in one release. If it turns out big, the version may become 2.0 instead of 1.4.0. Decide that at release time.

**Still open:**
2. **Voice filling (D2):** on hold; shortcuts (D1) are in. Started building on `release/1.4.0` 2026-11-21.


**Decided:** emulator-5554 wiped (Arun, 2026-11-21).

## 6. Competitor review (2026-11-21)

Arun shared five App Store screenshots from a scanner app: Recognize Text,
Report Expenses, Save as PDF or IMG, Convert to PDF/Word/JPG, and Extract and
Edit Text.

**Opinion:** that app is a general scanner with a subscription. We sell fill and
sign, offline, paid once. Copy the tools that make a scan more useful. Do not
copy the "convert anything" promise, because it can't be delivered well.
- **F1, F2 and F4** are cheap. They reuse what we already store, and they
  close the gaps a buyer sees when comparing apps.
- **F3** is the biggest item, and it is the only one that moves us toward
  expense apps. It suits the receipts the 1.3.0 categories already collect,
  but it has no demand signal yet. Ship it as a small test: five fields and a
  CSV. No mileage tracking, no reports, no totals across months.

**What we can claim:**
- **Copy text:** we can claim it for English and other Latin-script text. We
  can't claim it for Hindi, Tamil or Telugu.
- **Word export:** "Text exported to Word". The layout is not kept. Never say
  "convert to Word".
- **Receipt details:** "read on your device; check before you export". They
  are suggestions. We never claim they are accurate or ready for tax use.

| Never say | Say instead |
|---|---|
| Convert to Word / Excel | Share text as Word · Export receipts to a spreadsheet |
| Edit text in your scans | Copy text from your scans |
| Accurate / automatic expense reports | Receipt details read on your device. Check and export. |
| Tax-ready, accountant-approved | (nothing) |
| Any competitor's name, in metadata or screenshots | (nothing) |

Translations must not strengthen these claims (for example, fr "convertir"
for Word export).

**Privacy:** receipt details are new data that stays on the device. Add a line
to `store/PRIVACY_POLICY.md`. The App Privacy and Data safety answers do not
change, because nothing leaves the device.

## 7. New store screenshots (G)

**Goal:** catchy, one feature per screen, with a big two-line headline over a
real app screen, like the competitor's set. Use our colours. Show the pay-once
model without breaking the price rules.

**Store rules (fetched live 2026-11-21):**
- Apple 2.3.7: screenshots "should not include prices, terms, or descriptions
  that are not specific to the metadata type".
- Apple 2.3.14: creative assets should not include "specific or discounted
  pricing information".
- Google Play Metadata policy, a violation example: "Images or text that
  indicate price and promotional information". It is mandatory for the title
  and icon.
- Google Play preview assets, for screenshots: no price or promotional info,
  no call to action, and taglines on at most 20% of the image.

**So:**
- No price, no "$", and no "Free", "Lifetime", "Sale" or "Best" in any image.
- The pay-once message goes in the **last** screenshot. It shows the real
  Unlimited screen, which already says "one-time purchase" as part of the app.
  Its headline is about ownership, not price: **"Pay once. Keep it."** On Play,
  the fallback is **"No subscription. No account."** (both kinds of
  promotional text are "Highly recommended" there, not mandatory).
- The title, subtitle and description already say "no subscription" and
  "own it forever", which is allowed in text. Keep the word "lifetime" out:
  it promises something about the future we can't control.

**Proposed set (8, the same order in both stores):**
1. **Scan. Fill. Sign.** The library with categories, plus a finished form.
2. **Finds the blanks for you.** Field detection on a real form.
3. **Fill it in seconds.** Next field, with My Details suggestions.
4. **Sign by hand or by typing.** The Type tab (A2).
5. **Clean, shadow-free scans.** Before and after with the Clean filter (F4).
6. **Copy the text. Share as Word.** The Text sheet (F1/F2).
7. **Everything stays on your phone.** Search through page text, with a no-cloud badge.
8. **Pay once. Keep it.** The Unlimited screen.

Captions are written for all 7 locales and checked for length in
`tool/store_capture/creative.py`. A new preview video follows the same order.
Keep a copy outside `build/`.
