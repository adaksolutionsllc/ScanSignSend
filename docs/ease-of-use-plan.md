# Ease of use (1.3.0) — plan

Status: **draft for review** (2026-10-23). Nothing here is built yet.
Arun, 2026-10-23: **one release** (1.3.0). Documents are **sorted
automatically by what they are**: by the on-device language model where the
phone has one, otherwise by keyword rules (§3.9).

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

One release, 1.3.0 (≈ 24 days, with voice). The headings below group the work;
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
  and other apps.
- **iOS Share Extension (decided 2026-10-23, +3–4 d):** a `ShareExtension`
  target (bundle `com.adakventures.scansignsend.ShareExtension`) that accepts
  images and PDFs from any app, Photos included. It copies the files into an
  App Group container (`group.com.adakventures.scansignsend`), writes a small
  manifest, and opens the main app via a URL scheme
  (`scansignsend://import?batch=<uuid>`). The main app imports the batch
  through the same path as Android `SEND`, then deletes it. The extension holds
  no Flutter code (memory limit ~120 MB), no UI beyond a progress sheet, and
  no access to the database. Fastlane gets the second App ID, App Group
  capability and provisioning profile. Strings for the extension go in its own
  `Localizable.strings` × 7.

### A real library

#### 3.8 Add pages to an existing document (1.5 d)
- Review and the document menu get **Add pages** → scanner or photo import.
  New pages are appended, existing fields are untouched, and `pageCount`
  plus the OCR text are updated in one transaction (same pattern as capture).
- Only on drafts and fillable documents. A completed (flattened) document is
  final; there the menu offers "Use as template" or merge instead.
- Free users get the page-limit prompt when the total would go over 2.

#### 3.9 Categories, assigned automatically (5 d)
One concept instead of folders *and* tags: every document has one
**category**. The app picks it from the document's text; the user can change
it, or create their own categories, which then work like folders.

- **Built-in categories** (translated, fixed keys so a language switch never
  breaks them): Tax · Bank & money · Insurance · Medical · Home & rental ·
  Work · School · ID & travel · Agreements & legal · Bills & receipts ·
  Other. User-created ones are added to the list.
- **How it decides:** one Dart interface, `DocumentClassifier.classify(title,
  text) → categoryKey?`, with two engines behind it:
  1. **On-device language model, where the phone has one.** On iOS this is
     Apple's Foundation Models; on Android it's Gemini Nano through ML Kit's
     Prompt API (§3.9a). The model gets the title plus the first ~2,000
     characters and must answer with one built-in key or `none`
     (structured output, so free text is impossible).
  2. **Keyword rules everywhere else**, and whenever the model is unavailable,
     busy, over quota or errors. Built like `PrefillMatcher` (phrase lists per
     category × the Latin-script locales, weighted, with the title and page 1
     counting most). Examples: "W-9", "1040", "PAN", "Form 16", "IRS",
     "impôt" → Tax; "lease", "tenant", "landlord", "rental", "bail" → Home &
     rental.

  Both engines may say "not sure". The document then stays
  **Uncategorised**, because a wrong category is worse than none. Learned
  hints (below) are checked first and win over both engines.
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

Accepted trade-off: the same document can get different categories on two
phones (model vs keywords). The user's own choice always wins, and nothing is
shared between phones, so nobody sees both results.

#### 3.9a The on-device model channel
Facts checked 2026-10-23:
- **Apple Foundation Models:** iOS 26+, Apple Intelligence devices only
  (iPhone 15 Pro and newer), with Apple Intelligence switched on. The
  supported languages include English, French, Spanish and Portuguese, but
  **not Hindi**. Developers report that the model is unavailable when the
  *device* language is unsupported, so a phone set to Hindi, Tamil or Telugu
  falls back to keywords.
- **ML Kit Prompt API (Gemini Nano):** **still beta** (1.0.0-beta4, July
  2026; there is no stable release). Android API 26+, input under 4,000 tokens,
  "AICore enforces an inference quota per app", and it doesn't work on devices
  with an unlocked bootloader. `checkStatus()` returns AVAILABLE /
  DOWNLOADABLE / DOWNLOADING / UNAVAILABLE. Supported phones are recent
  flagships (Pixel 9/10, some Samsung, OnePlus, Xiaomi, etc.).

Design:
- Reuse the existing `com.scansignsend/ai_enhancer` channel, renamed
  `com.scansignsend/on_device_ai`, with methods `isAvailable` and
  `classifyDocument`. The field-detection `enhance` stub goes (§3.14).
  Update CLAUDE.md's channel table.
- **iOS:** `import FoundationModels` behind `if #available(iOS 26, *)`. The
  deployment target stays 15.0 (local Xcode is 27.1, and CI uses
  latest-stable). `isAvailable` = `SystemLanguageModel.default.availability
  == .available`. A `@Generable enum DocumentCategory` gives guided
  generation, so the answer is always a valid key. Session instructions: "Pick
  the category for this document, or none if unsure."
- **Android:** a Kotlin handler in `MainActivity` using
  `com.google.mlkit:genai-prompt` with structured output (beta3+). It's used
  only when `checkStatus() == AVAILABLE`, and the app never starts a model
  download itself. **minSdk stays 24.** The library needs API 26, so the
  manifest gets `tools:overrideLibrary` for the genai packages (exact list
  taken from the manifest-merger report at build time). All Prompt API code
  lives in one Kotlin class that's only touched behind
  `Build.VERSION.SDK_INT >= 26`. Android 7.x phones use keywords. Test:
  launch and categorise on an API 24 emulator to prove nothing loads there.
- **When it runs:** after a document is saved, in the foreground, one
  document at a time, with a timeout (about 10 s), then keyword fallback. On
  upgrade, it classifies the 20 most recent documents with the model (quota)
  and the rest with keywords.
- **Settings:** a "Sort documents automatically" switch (default on), shown
  on every device. Its subtitle says which method is in use and, when it's
  keywords, why and what (if anything) the user can do:

  | Reason (from the platform) | Message (English; 7 locales) |
  |---|---|
  | Model available | "Sorted by on-device AI." |
  | iOS: device not eligible (`deviceNotEligible`) | "Sorted by keywords. On-device AI sorting needs iPhone 15 Pro or later." |
  | iOS < 26 on an eligible iPhone | "Sorted by keywords. Update to iOS 26 or later for on-device AI sorting." |
  | iOS: Apple Intelligence off (`appleIntelligenceNotEnabled`) | "Sorted by keywords. Turn on Apple Intelligence in Settings for on-device AI sorting." |
  | iOS: model not ready (`modelNotReady`) / Android DOWNLOADABLE or DOWNLOADING | "Sorted by keywords for now. On-device AI is still being set up on this phone." |
  | iOS: device language not supported | "Sorted by keywords. On-device AI sorting isn't available in your phone's language yet." |
  | Android < 8.0, or UNAVAILABLE | "Sorted by keywords. This phone doesn't support on-device AI sorting." |

- **Telling the user once:** the first time a document is sorted by
  keywords, a dismissible tip on the Library shows the same message with
  "Got it" (stored in prefs, never shown again). It's never repeated or turned
  into a nag, and it never points at buying a new phone. Only the tip and
  Settings mention it.
- Wording: "on-device AI" is fine (it's true and stays on the phone). Never
  "smart AI that understands your documents".
- **Testing:** Dart tests use a fake channel (model answers, `none`,
  timeout, error → keyword fallback). For accuracy, a tool script runs
  both engines over the sample forms in `tool/store_capture/forms`, plus
  10–15 more labelled samples (tax, lease, medical, insurance, bank, school).
  Target (a goal to tune toward, not a release gate; Arun 2026-10-23: "a
  decent effort"): correct or Uncategorised ≥ 90%, wrong ≤ 10%, for each
  engine. iOS model: the simulator on this Mac with Apple Intelligence on, or
  any eligible iPhone available. Android model: a supported phone if one is
  available. Without one, the Android path ships guarded (AVAILABLE only,
  timeout, keyword fallback), with the fallback paths tested.

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

#### 3.14 AI field detection — remove the stub
The field-detection `enhance` method and `AiEnhancerService` go. The channel
itself lives on for categories (§3.9a). Field detection stays heuristic plus
learning (FieldHints, PrefillHints), which works on every device. The
`aiEnhancedDetection` column stays in the schema unused (drift can't drop it
cheaply). Update CLAUDE.md's Phase 5 line: "on-device model used for
document categories; field detection stays heuristic."

### Voice (added 2026-10-23, ≈ 6 d)

Arun asked for hands-free use after a Vision Pro idea was parked (Vision Pro
camera access is enterprise-only, and Flutter has no visionOS target). Voice
on the phone gets most of that value for everyone, and it pairs with
Next-field filling (§3.3) and the accessibility pass (§3.5).

#### 3.15a "Hey Siri" / Assistant shortcuts (2 d)
- **iOS (App Intents, iOS 16+):** an `AppShortcutsProvider` in Runner with
  three intents that open the app on a route: **Scan a document**, **Open my
  last draft**, **Fill my last draft with my details** (opens Fill mode with
  the PreFill offer showing; nothing is filled until the user taps). Phrases
  in all 7 languages (`AppShortcuts.xcstrings`); Siri shows them in the
  Shortcuts app with no setup. App lock still runs first.
- **Android:** the same three as static shortcuts in `shortcuts.xml` (shared
  with the quick actions in §3.6). "Open" phrases work with Assistant/Gemini
  by name. App Actions built-in intents are still supported through
  `shortcuts.xml` (`actions.xml` is gone); only `actions.intent.OPEN_APP_FEATURE`
  fits, so nothing more is promised on Android.

#### 3.15b Voice filling inside the app (4 d)
- A mic button in Fill mode. While it listens, the user can say:
  - a value: it goes into the current field ("Priya Raman"),
  - **next / back / skip**: moves between empty fields (§3.3 order),
  - **fill my details**: same as tapping the PreFill bar,
  - **tick / untick**: for a checkbox,
  - **sign**: opens the signature sheet (drawing or typing stays manual),
  - **done / stop**: ends listening.
  Commands are matched per locale from a small table (like PrefillMatcher),
  and anything else is treated as a value. Every change shows on screen and
  can be undone; nothing is finished, flattened or sent by voice.
- **On-device recognition only.** iOS: `SFSpeechRecognizer` with
  `requiresOnDeviceRecognition = true` (SpeechAnalyzer on iOS 26 if it
  covers more languages). Android: `SpeechRecognizer.createOnDeviceSpeechRecognizer`
  (API 31+). Audio never leaves the phone, so the privacy labels stay "no
  data collected".
- **Languages:** on-device support differs by phone and OS. Apple's documented
  on-device list includes English, Spanish and Brazilian Portuguese, but
  **not Hindi, Tamil or Telugu**. The app checks at runtime
  (`supportsOnDeviceRecognition` / `checkRecognitionSupport`) for the app's
  language. When it's unsupported, the mic shows a short reason, like the
  sorting messages in §3.9a, instead of falling back to a server.
- **Permissions:** iOS `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` (localized ×7, saying audio stays on
  the phone); Android `RECORD_AUDIO`, asked the first time the mic is tapped,
  never at launch. Without permission everything else works as before.
- **Accessibility:** the mic button has a label, and each change is announced
  (`SemanticsService.announce`), so VoiceOver/TalkBack users hear what was
  filled.

## 4. Store review — risks and mitigations

| # | Risk | Source | Mitigation |
|---|---|---|---|
| 1 | Password export uses non-OS encryption → export documentation needed, plus a French import declaration if sold in France | App Store Connect asks for documentation when an app uses "standard encryption algorithms instead of, or in addition to, using or accessing the encryption within Apple's operating system" ([Apple forums summary](https://developer.apple.com/forums/thread/849352)) | Use PDFKit on iOS (§3.12) so encryption stays within the OS. Keep `ITSAppUsesNonExemptEncryption = false` only after re-answering the questionnaire for the new build. |
| 2 | Claiming accessibility features that don't fully work | "users must be able to complete all of the common tasks of your app using that feature… providing these labels will be voluntary to start" ([Apple: Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)) | Declare only what passed a full device run (§3.5). VoiceOver only after scan→sign→send works end to end. |
| 3 | New features not described in review notes | Guideline 2.3.1(a) | The review notes for each release list each new path, with steps on the sample forms. |
| 4 | Listing over-claims ("secure", "protects your documents") | 2.3 / Play Misrepresentation | Wording table below. |
| 5 | New file types received on Android | Play: no permission needed for shared content URIs | No new permissions. Data safety is unchanged (nothing leaves the device). |
| 6 | Typed-signature font licence | — | OFL font with its licence file bundled, registered with `LicenseRegistry`, and a new Settings → Support → Licences row (`showLicensePage`); there's no such row today. |
| 8 | Reviewer can't see model sorting (no Apple Intelligence on the review device) | 2.1(a) Reviewability | Sorting works on every device via keywords, so there's nothing hidden. The review notes say it uses the on-device model where available and keywords otherwise. |
| 9 | Trademarks in metadata | 2.3.7 / Play Metadata | Don't name Apple Intelligence or Gemini in the listing or keywords. |
| 10 | Foundation Models acceptable use | Apple's acceptable-use requirements for the framework | Classifying the user's own document into fixed categories is an ordinary use. Re-read the requirements at build time. |
| 11 | Microphone/speech permission and privacy labels | Apple 5.1.1, Play User Data | Ask only on first mic tap, with localized purpose strings; on-device recognition only, so no audio is collected; privacy policy line added. |
| 12 | Voice wording | 2.3 | "Fill by voice", never "AI assistant" or "understands everything you say". |
| 7 | Privacy policy | Apple 5.1.1 / Play User Data | PrefillHints, categories and CategoryHints stay on the device, and the on-device model runs on the phone (document text is never sent anywhere). Add one line ("the app remembers which of your details you choose for a form label, on this device only") to the My Details section. |

**Wording rules** (all 7 locales; translations must not make the claim stronger):

| Never say | Say instead |
|---|---|
| Secure / encrypted / protected PDF | Password-protected PDF |
| Unbreakable, military-grade | (nothing; just the password note) |
| Legally binding typed signature | Type your signature |
| Smart AI naming / AI detection | Names your scan from its title |
| AI sorts your documents / understands your documents | Sorts your documents into categories you can change |
| Apple Intelligence / Gemini (in name, subtitle, keywords, short description) | (nothing; describe the result, not the model) |
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
   keyword classifier and its tests (§3.9), then the `on_device_ai` channel
   on iOS and Android with the fallback tests and the accuracy script (§3.9a).
3. **Filling:** Next field (§3.3), typed signature (§3.4), PreFill learning
   (§3.13).
4. **Library:** category chips, change category, multi-select (§3.9 UI),
   add pages (§3.8), merge and split with the delete-safety test (§3.10).
5. **Getting files in and out:** quick actions and receiving images (§3.6–3.7),
   smaller files (§3.11), removing the field-detection stub (§3.14).
5b. **Voice:** Siri/Assistant shortcuts (§3.15a), then voice filling (§3.15b).
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
- Documents are sorted automatically into categories (one per document,
  changeable, user can add their own) instead of manual folders or tags.
- Sorting uses the on-device language model where available, and keyword
  rules otherwise (§3.9, §3.9a).
- The Android model path ships while the Prompt API is beta, guarded.
- minSdk stays 24. Android 7.x uses keywords (`tools:overrideLibrary` +
  version guard).
- Where keywords are used, the user is told why (hardware, OS, setting,
  language), in Settings and once as a Library tip.
- Accuracy is a best-effort target, not a release gate.

- **iOS Share Extension: build it** (§3.7). Photos → Share → Scan Sign Send.
- **Accessibility labels:** declare only what passes a device run; VoiceOver
  only after a full scan→fill→sign→send run.
- **Password on iOS through PDFKit**, after the spike (§3.12).
- **Smaller files by default** (200 dpi) plus the Send switch, after measuring
  on the Phase 1 batch (§3.11).

- **Voice is in 1.3.0** (Arun, 2026-10-23): shortcuts + in-app voice filling, on-device recognition only (§3.15).

No open decisions remain.
