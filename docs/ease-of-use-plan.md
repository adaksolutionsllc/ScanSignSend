# Ease of use (1.3.0) — plan

Status: **draft for review** (2026-10-23). Nothing here is built yet.
Arun, 2026-10-23: **one release** (1.3.0); documents should be **sorted
automatically by what they are**, using on-device intelligence (§3.9).

## 1. Goal

Make the everyday path (scan or open a PDF, fill, sign, send) faster and
easier for everyone, including people using large text or a screen reader.
Also make the Library useful as a place to keep documents.

All of it stays offline, with no accounts and no new purchases.

**Out of scope:** two-party Agreements (parked by Arun 2026-10-23), iOS Share
Extension (§3.7), and annotations/highlights (Workbench B3, still deferred).

### What I checked in the code first (2026-10-23)

| Item | Finding |
|---|---|
| Known issues from the 1.1/1.2 notes | 3 of 4 are **already fixed**: onboarding wording (8011832), the rental-form checkbox (covered by a test in `test/field_detection_engine_test.dart`) and the banner wrap (62cbb33). Only one is still open: `_SummaryRow` in `press_screen.dart` builds `'$count $label field(s)'` in English. |
| Document titles | Scans are named `"Document {date}"` (`captureDefaultDocumentName`). OCR (Latin script only) runs only in Detect Fields, so **Save PDF** documents have no OCR text at all. |
| Adding pages later | There's no way to do it. Pages are written only at capture/import (`PageRepository.addPage`), and Review can rotate and delete pages but not add them. |
| Library | It has four status tabs plus title/OCR search. There are no folders or tags. |
| Receiving files | Android takes `VIEW` and `SEND` for `application/pdf` only, so no images and no `SEND_MULTIPLE`. iOS declares `CFBundleDocumentTypes` for `com.adobe.pdf` (Alternate), so the app already appears for PDFs in the share sheet and in Files. |
| Export size | `press_service.dart` embeds each scan at full camera resolution (JPEG q90, or the raw file when the filter is "original"), so a 10-page scan can be several MB. |
| Fill navigation | Fields are tapped one at a time. A page picker exists, but there is no "next field". |
| PreFill | `PrefillMatcher` uses fixed rules only. The `FieldHints` table (schema v6) already learns field *types* from edits (threshold 2), and PreFill learning can copy that pattern. |
| Accessibility | There are 5 `Semantics`/`semanticLabel`/`tooltip` uses in all of `lib/`, and no text-scale handling. **There is no typed signature**, so a VoiceOver or Switch Control user cannot sign at all. |
| AI detection | The iOS Foundation Models call is a stub returning `[]`, there's no Android handler, and the Settings switch was removed in 1.2.0. |
| Workbench plan | Its progress log says phases A–D are **done** (2026-08-01), but the ☐ boxes at the top were never ticked. Only B3 (annotations) was deferred. |
| Password protection | Syncfusion 28.2 has `PdfDocument.security` (AES), but it's Syncfusion's own Dart crypto, not the OS's (§4). |

## 2. Pricing and entitlements

Nothing changes. There are no new products, product IDs or store settings. The
free tier stays at 2 finished documents of up to 2 pages each
(`FreeUsageService`). New paths have to respect it:

- **Add pages** goes through the same page-limit prompt as capture (free
  users: unlock or keep the first 2 pages).
- **Merge** can produce a document of more than 2 pages. It's then gated at
  finish the same way any long document is today.
- **Split, compression, password, quick actions, accessibility and naming**
  are free for everyone. They work on documents the user has already
  finished, or they don't finish anything.

## 3. How it works

One release, 1.3.0 (≈ 15–16 days). The headings below group the work;
each item lists its size in days, with tests and 7 locales included.
Password protection (§3.12) is built last because a spike gates it. If
the spike fails, that item drops without holding the release.

### Faster filling

#### 3.1 Fix the summary text (0.25 d)
Replace the English `field(s)` with a plural ICU key
(`pressFieldCount: {count, plural, one{# field} other{# fields}}`, with the
filled/unfilled label passed in) in all 7 ARB files. Tick the Workbench
boxes and add a one-line "status as of 2026-10-23" note (B3 still deferred).

#### 3.2 Names scans automatically from their content (1 d)
- After a scan is saved, OCR page 1 in the background (it reuses
  `OcrService`, Latin only, and doesn't block the UI).
- Title = the largest-text line in the top third of page 1 (form titles are
  big and near the top), cleaned up (≤ 40 characters, no trailing
  punctuation), plus the short date: "Rental Application – 23 Oct".
- Only applied while the title is still the default. A new column,
  `Documents.titleEdited` (schema v9), is set on any rename, so a user's name
  is never overwritten.
- If OCR finds no usable line (Indic scripts, handwriting, photos), the title
  stays "Document {date}". It never guesses.
- Imported PDFs keep their file name, as today.

#### 3.3 "Next field" guided filling (1.5 d)
- Reading order = page, then top to bottom, then left to right (rows grouped
  by vertical overlap, the same banding the detector already uses).
- The text input sheet gets **Next** (the keyboard action becomes "next"),
  which saves, goes to the next *empty* field, switches page if needed, and
  opens it. The last field shows **Done**.
- The fill-mode bottom row gets a "N left →" button that jumps to the first
  empty field. A signature or checkbox field is selected and highlighted
  rather than auto-opened, so a checkbox is never ticked by accident.
- Required fields (AcroForm `isRequired`) don't change the order, but Review
  & Finish lists them first.

#### 3.4 Typed signature and initials (1 d)
- The signature screen gets two tabs, **Draw** and **Type**. Type renders the
  name in a bundled script font (OFL licence, e.g. Dancing Script, plus its
  licence file) to the same transparent PNG that drawing produces. Everything
  downstream (Signatures table, press, export) stays the same.
- Indic names fall back to the system font for that script through Flutter's
  normal shaping. That's not cursive, but it's correct.
- It defaults to My Details' full name if one is set.
- Why it's in this release: it's the only way a VoiceOver/Switch Control user
  can sign (§3.5), and many people also prefer it on a small phone.
- Wording: "Type your signature", not "a legal signature" (see the wording
  rules in `two-party-signing.md` §4).

#### 3.5 Large text and screen readers (2 d)
- **Larger text:** test every screen at 200% text size on the iPhone SE /
  small-Android emulator and fix any clipping. Fixed-height buttons and rows
  become min-height, button rows wrap into columns, and there's no
  `textScaler` clamp except on field overlays drawn *on the page* (those must
  match the PDF, so they keep page-relative sizes).
- **Screen readers:**
  - Every field overlay gets `Semantics(label: "<label>, <type>, <filled
    value or 'empty'>, page N", button: true)`.
  - Every icon-only button gets a tooltip or label.
  - Page images get "Page N of M".
  - Decorative images are excluded.
  - The fill bar and PreFill bar announce changes (`SemanticsService.announce`
    after a fill or undo).
- **Field editor (Edit Fields):** drag/resize can't be done with VoiceOver.
  Add "Move" and "Resize" custom semantics actions (nudge by 1% steps) so it
  can at least be operated.
- **Store:** Apple's Accessibility Nutrition Labels are voluntary for now.
  Only declare a feature once *all common tasks* (first launch, scan, fill,
  sign, purchase, settings) work with it. Plan to declare **Larger Text**,
  **Dark Interface** (already supported) and **Sufficient Contrast** after
  testing. Declare **VoiceOver** only if a full scan→fill→sign→send run passes
  on a device; if it doesn't, leave it undeclared.

#### 3.6 Home-screen quick actions (0.5 d)
- The `quick_actions` package (flutter.dev) adds **Scan**, **Open PDF** and
  **Fill my last draft** (shown only when there is a draft).
- Titles are set from Dart at startup in the current locale. The app lock
  (`AppLockGate`) still runs first: the action is held and routed only after
  unlock.

#### 3.7 Receive images and several files (1 d)
- **Android:** add `SEND` and `SEND_MULTIPLE` for `image/*` and
  `SEND_MULTIPLE` for `application/pdf`. Images become pages of one new
  document, in the order received, through the existing import path. Several
  PDFs become one document *each*, unless the user chooses to merge (§3.10).
  No storage permission is needed, because the URIs come with read grants.
- **iOS:** add `public.jpeg`, `public.png` and `public.heic` to
  `CFBundleDocumentTypes` (Alternate rank) so images can be opened from Files
  and other apps. Photos' share sheet lists only share extensions, so photos
  shared from **Photos** still need the in-app import. A real Share Extension
  (new target, App Group, extra signing profiles in fastlane) is not worth its
  maintenance cost yet. That gets revisited if users ask for it.

### A real library

#### 3.8 Add pages to an existing document (1.5 d)
- Review and the document menu get **Add pages** → scanner or photo import.
  New pages are appended, existing fields are untouched, and `pageCount`
  plus the OCR text are updated in one transaction (same pattern as capture).
- Only on drafts and fillable documents. A completed (flattened) document is
  final; there the menu offers "Use as template" or merge instead.
- Free users get the page-limit prompt when the total would go over 2.

#### 3.9 Categories, assigned automatically (3 d)
One concept instead of folders *and* tags: every document has one
**category**. The app picks it from the document's text; the user can change
it, or create their own categories, which then work like folders.

- **Built-in categories** (translated, fixed keys so a language switch never
  breaks them): Tax · Bank & money · Insurance · Medical · Home & rental ·
  Work · School · ID & travel · Agreements & legal · Bills & receipts ·
  Other. User-created ones are added to the list.
- **How it decides, on every device:** a keyword classifier over the
  document's text, built like `PrefillMatcher` (phrase lists per category ×
  the Latin-script locales, weighted, with the title and page 1 counting
  most). Examples: "W-9", "1040", "PAN", "Form 16", "IRS", "impôt" → Tax;
  "lease", "tenant", "landlord", "rental", "bail" → Home & rental. It only
  assigns a category when one clearly wins; otherwise the document stays
  **Uncategorised**. A wrong category is worse than none.
- **Text source:** scans use the page-1 OCR that auto-naming (§3.2) already
  runs, plus the detection OCR when there is one. Imported PDFs use their text
  layer (`PdfTextExtractor`, already used in `page_layout_service.dart`) and
  fall back to OCR. Hindi/Tamil/Telugu text isn't OCR'd (ML Kit Latin only),
  so those documents stay Uncategorised unless they contain English (as
  most Indian government and bank forms do).
- **The user is in charge:** a category chip on each card ("Tax ✎") changes
  it in one tap. Once set by hand, the app never changes it again
  (`Documents.categoryManual`). Its "Changed by you" tooltip makes the
  automatic ones distinguishable for screen readers.
- **It learns:** when a user changes an automatic category, the document's
  distinctive title words are recorded against the chosen category in
  `CategoryHints` (same threshold-of-2 rule as `FieldHints`). Cleared by the
  same Settings control.
- **Schema v9:** `Categories` (`id`, `builtInKey?`, `name?`, `createdAt`),
  `Documents.categoryId` (nullable) and `Documents.categoryManual`. Built-ins
  are seeded in the migration, and existing documents are classified once in
  the background after upgrade. Deleting a user category moves its documents to
  Uncategorised and **never deletes documents**.
- **Library:** a chip row above the status tabs (All · Tax · Medical · … · +),
  showing only categories that have documents. Tabs and search work inside the
  chosen category, and search matches category names. Long-press menu and
  multi-select: **Change category**.
- **Multi-select** in the Library (long-press → select): Change category,
  Merge, Delete.

**Why not an on-device language model for this.** Apple's Foundation Models
need iOS 26 on an iPhone 15 Pro or newer, and Android's Gemini Nano Prompt API
is an alpha, limited to a short list of flagships (Pixel 9/10, some Samsung,
OnePlus, Xiaomi and others). Most users would get nothing. The same document
could also land in different categories on two phones, and results can't be
pinned by tests. The keyword classifier works offline on every device, is
explainable and is testable against the sample forms. If its accuracy
on real documents turns out poor, a model can be added later as an *optional
upgrade* behind the same `classify(text) → category?` interface on devices
that have one, without changing the UI.

#### 3.10 Merge and split (2 d)
- **Merge:** select 2 or more documents → Merge → a new draft with their pages
  in selection order (user can reorder in Review) and every field copied with
  its `pageIndex` offset. The originals are kept. The user can delete them.
  - Completed (flattened) documents join as imported pages of their
    exported PDF (`path#page=N` refs), with no fields.
  - Page files are referenced, not copied, so the existing
    `_isFolderStillReferenced` / unreferenced-file checks in
    `DocumentRepository` must cover the shared files. That needs a test that
    deletes an original and then opens the merge.
- **Split / Extract pages:** in Review, select pages → "Extract to new
  document" (copy, original untouched) or "Split here". Fields go with
  their page.
- AcroForm fields from an imported form keep their `pdfFieldName`. When two
  merged forms share a field name, the second one's name is given a suffix
  on export so the live form doesn't link them.

#### 3.11 Smaller files (1 d)
- **Always:** the press and fillable exports downscale scanned pages to 200
  dpi at the page size (an A4 page is ≈ 1654×2339 px) and re-encode at JPEG
  q85. Scanned documents should shrink a lot with no visible loss; measure
  it with the 10-page Phase 1 test batch before settling the numbers.
- **On Send:** a "Smaller file" switch (150 dpi, q65; grayscale if the page
  filter is B&W) that writes a separate copy for sharing. The Send screen
  shows the file size for both options ("2.1 MB → 640 KB").
- Imported vector PDFs aren't recompressed. The switch is hidden when nothing
  can shrink.

#### 3.12 Password-protected PDF (1.5 d)
- The Send screen gets a "Password-protect" switch: enter it twice, a
  "can't be recovered" note, and a minimum of 6 characters. It writes an
  AES-256 encrypted copy for sharing only. The password is **never stored**,
  and the in-app copy stays unencrypted (it's already behind app lock and the
  sandbox).
- **iOS: use PDFKit** (`PDFDocument.write(to:withOptions:)` with
  `userPasswordOption`/`ownerPasswordOption`) through a small method
  channel. That's the OS's encryption, which keeps the export-compliance
  answer simple (§4).
- **Android: Syncfusion `PdfSecurity`** (AES-256). No questionnaire applies,
  but see the legal flag.
- **Spike first (0.5 d, gates the item):** confirm that a *fillable* export
  encrypted by PDFKit still opens and fills in Acrobat, Preview and Chrome.
  PDFKit rewrites the file and may drop AcroForm appearances. If it fails,
  password protection applies only to completed (flattened) PDFs on iOS.
- Wording: "Password-protect" / "Anyone opening this PDF needs the password".
  Never "secure", "encrypted to military grade" or "unbreakable".

### Learning and AI

#### 3.13 PreFill learns from your picks (1.5 d)
- When the user picks one of their own details from a field's suggestion
  chips (e.g. picks *Phone* for a field labelled "Contact no."), record the
  normalised phrase → slot. Undoing or clearing a PreFilled value records a
  rejection.
- A new table, `PrefillHints(phrase, slot, accepted, rejected, updatedAt)`,
  is modelled on `FieldHints` with the same threshold (2 acceptances, more
  accepts than rejects). It stores **the label phrase and the slot name,
  never the value**.
- Learned matches are added to `matchForm` and never override an explicit
  rule in `_someoneElse` (e.g. "Spouse's name" never learns to fill your name).
- It's cleared by the existing "Clear learned hints" control in Settings
  (renamed to cover both), and also by "Delete my details".

#### 3.14 AI field detection — park it, remove the stub
The plan is to stop carrying a stub. (§3.9 keeps a
`classify` interface a model could plug into later, so nothing is lost.) Apple's on-device model needs iOS 26 on
Apple Intelligence hardware (a small share of users, none on Android). The
heuristics plus learning (FieldHints, PrefillHints) already give the
"gets smarter" story offline on every device. Remove
`AiFieldEnhancerPlugin.swift`, `AiEnhancerService` and the
`aiEnhancedDetection` column. That column stays in the schema (drift can't
drop it cheaply), unused. Update CLAUDE.md's Phase 5 line to "parked".
This can be revisited when Android has an equivalent.

## 4. Store review — risks and mitigations

| # | Risk | Source | Mitigation |
|---|---|---|---|
| 1 | Password export uses non-OS encryption → export documentation needed, plus a French import declaration if sold in France | App Store Connect asks for documentation when an app uses "standard encryption algorithms instead of, or in addition to, using or accessing the encryption within Apple's operating system" ([Apple forums summary](https://developer.apple.com/forums/thread/849352)) | Use PDFKit on iOS (§3.12) so encryption stays within the OS. Keep `ITSAppUsesNonExemptEncryption = false` only after re-answering the questionnaire for the new build. |
| 2 | Claiming accessibility features that don't fully work | "users must be able to complete all of the common tasks of your app using that feature… providing these labels will be voluntary to start" ([Apple: Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)) | Declare only what passed a full device run (§3.5). VoiceOver only after scan→sign→send works end to end. |
| 3 | New features not described in review notes | Guideline 2.3.1(a) | The review notes for each release list each new path, with steps on the sample forms. |
| 4 | Listing over-claims ("secure", "protects your documents") | 2.3 / Play Misrepresentation | Wording table below. |
| 5 | New file types received on Android | Play: no permission needed for shared content URIs | No new permissions. Data safety is unchanged (nothing leaves the device). |
| 6 | Typed-signature font licence | — | OFL font with its licence file bundled, registered with `LicenseRegistry`, and a new Settings → Support → Licences row (`showLicensePage`); there's no such row today. |
| 7 | Privacy policy | Apple 5.1.1 / Play User Data | PrefillHints, categories and CategoryHints stay on the device. Add one line ("the app remembers which of your details you choose for a form label, on this device only") to the My Details section. |

**Wording rules** (all 7 locales; translations must not make the claim stronger):

| Never say | Say instead |
|---|---|
| Secure / encrypted / protected PDF | Password-protected PDF |
| Unbreakable, military-grade | (nothing; just the password note) |
| Legally binding typed signature | Type your signature |
| Smart AI naming / AI detection | Names your scan from its title |
| AI sorts your documents / understands your documents | Sorts your documents into categories you can change |
| Fully accessible | Supports larger text and VoiceOver (only what's declared) |
| Compresses without any loss | Smaller file for email |

**Legal flags (for a lawyer, not decided here):** whether PDF password
encryption on Android (Syncfusion AES) needs any export self-classification
(mass-market encryption under US EAR); and whether a typed signature is
acceptable for a given use. The app makes no claim either way.

## 5. Build phases

One release, 1.3.0. Each phase ends with the pre-commit review routine
(analyze, tests, simulator + emulator run, screenshots).

1. **Schema v9 in one migration:** `Documents.titleEdited`, `Categories` +
   `categoryId` + `categoryManual`, `CategoryHints`, `PrefillHints`, with a
   migration test from v8. Summary text fix and Workbench doc tidy (§3.1).
2. **Text and sorting:** page-1 OCR after save, auto-naming (§3.2), the
   category classifier and its tests on the sample forms (§3.9 logic, no UI).
3. **Filling:** Next field (§3.3), typed signature (§3.4), PreFill learning
   (§3.13).
4. **Library:** category chips, change category, multi-select (§3.9 UI),
   add pages (§3.8), merge and split with the delete-safety test (§3.10).
5. **Getting files in and out:** quick actions and receiving images (§3.6–3.7),
   smaller files (§3.11), removing the AI stub (§3.14).
6. **Accessibility pass (§3.5)** across *all* the new screens. It goes last
   so it covers everything that shipped in phases 1–5.
7. **PDFKit spike, then password protection (§3.12).** Dropped from 1.3.0
   if the spike fails.
8. **Store:** What's New ×7, review notes for every new path, privacy policy
   line, re-answer the encryption questionnaire, accessibility labels, and
   screenshots (Library with categories, "Fill field by field").

## 6. Decisions

**Decided (Arun, 2026-10-23):**
- One release (1.3.0).
- Documents are sorted automatically by what they are. The plan uses
  categories (one per document, auto-assigned and changeable, user can add
  their own) instead of manual folders or multiple tags (§3.9).

Open, with my recommendation:

1. **How documents are sorted.** Recommend a keyword classifier on every
   device rather than an on-device language model (§3.9, last paragraph).
2. **iOS Share Extension.** Recommend not now; images from Files only on
   iOS (§3.7).
3. **AI detection stub.** Recommend removing it (§3.14).
4. **Accessibility labels.** Recommend declaring only the features that pass
   testing. VoiceOver goes in only after a full device run.
5. **Password on iOS through PDFKit.** Recommend yes. The spike decides
   whether it covers fillable PDFs too.
6. **Default compression on every export.** Recommend yes, after measuring
   on the Phase 1 batch. It changes the output of existing flows.
