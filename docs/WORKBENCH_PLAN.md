# PDF Workbench — Technical Plan

**Goal:** Evolve ScanSignSend from a flatten-only "completion tool" into a
**PDF workbench** ("iScanner + Adobe"): faithful viewing, filling *real*
AcroForm fields, authoring new fillable forms, and exporting to **either** a
flattened/locked PDF **or** a live AcroForm PDF (user's choice).

**Status legend:** ☐ not started · ◐ in progress · ☑ done

> This file is the durable source of truth for the workbench effort. It's
> written so any session (or teammate) can resume mid-phase. Update the status
> boxes and the "Progress log" at the bottom as work lands.

---

## Ground truth (verified against the code, 2026-07-31)

- **Fields table** (`lib/core/db/app_database.dart:38`): `type`, `boundingBoxJson`
  (normalised 0..1 of the *display rect*), `label`, `value`, `isChecked`,
  `isFilled`, `signatureId?`. **No** field name, **no** required flag, **no**
  back-reference to a source AcroForm widget.
- **Export today** = flatten only (`press_service.dart`, runs in a `compute`
  isolate). Draws pixels; kills all interactivity. There is no second exporter.
- **Imported PDFs** are stored as opaque `"$path#page=$N"` refs. Existing
  AcroForm fields are *detected* (`__has_form_fields__` sentinel in
  `import_service.dart`) then **routed around** — the app tells the user to add
  their own fields manually. It never reads or fills the real ones.
- **Syncfusion `syncfusion_flutter_pdf` 27.2.x has the needed API:**
  `PdfDocument.form` → `PdfForm.fields` (`PdfFormFieldCollection`), field
  classes `PdfTextBoxField`, `PdfCheckBoxField`, `PdfComboBoxField`,
  `PdfRadioButtonListField`, `PdfSignatureField`, `PdfField.bounds` (get/set,
  **PDF points**), and `PdfXfdfDocument`. Page import as vector template
  (`page.createTemplate()` + `gfx.drawPdfTemplate`) already used in
  `press_service.dart`.

### The load-bearing risk (read before coding)
The API *existing* ≠ its output *rendering correctly everywhere*. **Phase A is
gated on a 1-day spike** proving a Syncfusion-authored AcroForm opens correctly
in **Adobe Acrobat, Apple Preview, and Chrome**. If it doesn't, the fix is a
different PDF engine (e.g. `pdfrx`/pdfium bindings, or a native platform
channel to PDFKit/PdfBox) — a roadmap-altering decision we want *cheap and
early*, not after building UI on a broken foundation.

---

## Cross-cutting model shift (applies to all phases)

A field now has **three representations that must stay in sync**:
1. **Source AcroForm widget** — inside an imported PDF (Adobe/other made it).
2. **Our `Fields` row** — the editor's working copy.
3. **Exported AcroForm widget** — what we write at "Save as Fillable".

And the document is no longer a one-way pipeline. It's a **durable, re-editable
workspace** that resolves to one of two exits:
- **Flatten & Sign** → dead pixels, permanent (current `press_service`).
- **Save as Fillable Form** → live AcroForm (new `FillableFormExportService`).

**UX mandate:** "Save as Fillable" is the *safe default*; "Flatten & Sign" is a
*deliberate, irreversible act* (confirm dialog, plain-language warning: "This
locks the document — nobody can edit it afterward, including you"). Never render
the two exits as two equal-weight buttons.

---

## Coordinate transform (the thing naive implementations get wrong)

- **Our bbox:** normalised `{x,y,w,h}` in `[0,1]`, origin **top-left**, relative
  to the on-screen display rect of the page.
- **PDF/AcroForm bounds:** `Rect` in **PDF points** (1/72"), **per page**.
  Syncfusion's `PdfField.bounds` and `PdfPage.size` are top-left origin in its
  abstraction (it hides the PDF's native bottom-left origin), so we map to
  Syncfusion space, not raw PDF space — verify this assumption in the spike.

Define one utility, `lib/core/services/pdf_geometry.dart`, with pure functions +
unit tests:

```
// page: PdfPage; pw=page.size.width, ph=page.size.height (points)
Rect normToPdf(BoundingBox b, double pw, double ph) =>
    Rect.fromLTWH(b.x*pw, b.y*ph, b.w*pw, b.h*ph);

BoundingBox pdfToNorm(Rect r, double pw, double ph) =>
    BoundingBox(x: r.left/pw, y: r.top/ph, w: r.width/pw, h: r.height/ph);
```

For **imported** PDFs the page's own point size is the reference frame (not A4).
For **scanned** pages we synthesise an A4 page, so A4 points are the frame.
Round-trip test: `pdfToNorm(normToPdf(b)) ≈ b` within epsilon.

---

# Phase A — Fill *real* AcroForm fields  ☐

**Why first:** highest App-Store search demand ("fill PDF form"), and it forces
the three-way field mapping + coordinate transform before any UI is stacked on
top. Ships as a standalone release.

### A0 — Library spike (GATE) ☐
- New throwaway `tool/acroform_spike.dart` (or a test): author a PDF with a
  text field, checkbox, and signature field via Syncfusion; write to disk.
- Manually open in Acrobat, Preview, Chrome. Confirm fields are fillable and
  correctly placed.
- **Decision:** PASS → continue Phase A. FAIL → open `docs/PDF_ENGINE_EVAL.md`,
  evaluate alternatives, do not proceed.

### A1 — Schema: make Fields AcroForm-aware ☐
Add columns to `Fields` (`app_database.dart`), bump `schemaVersion`, add a
migration in `onUpgrade`:
- `pdfFieldName TEXT NULL` — the AcroForm field's fully-qualified name (the key
  for round-tripping into an imported form).
- `isRequired BOOLEAN DEFAULT false`.
- `sourceKind TEXT DEFAULT 'app'` — `'acroform'` (read from imported PDF) vs
  `'app'` (user/heuristic created). Drives which export path can keep it live.
- `optionsJson TEXT NULL` — for combo/radio/list choices (forward-looking).
Run `dart run build_runner build --delete-conflicting-outputs`.
**Migration must be additive + tested** (open an old DB, confirm no data loss).

### A2 — Read existing AcroForm fields on import ☐
In `import_service.dart` `_importPdf`, when `pdfDoc.form.fields.count > 0`:
- Iterate `pdfDoc.form.fields`; for each supported field type
  (`PdfTextBoxField`, `PdfCheckBoxField`, `PdfComboBoxField`,
  `PdfRadioButtonListField`, `PdfSignatureField`), read `.name`, `.bounds`,
  page index, current value, required flag.
- Map bounds → our normalised bbox via `pdf_geometry.dart` using that page's
  point size.
- Insert a `Fields` row per widget with `sourceKind='acroform'`, `pdfFieldName`
  set. **Do not** set the `__has_form_fields__` sentinel to "skip" anymore —
  invert it: imported AcroForms are the *best* input, not a thing to avoid.
- Map unsupported types to a read-only visual so nothing silently vanishes.

### A3 — Fill UI reuses the existing editor ☐
- `field_detection_screen.dart` / `fill_mode_screen.dart` already render
  draggable, typed field overlays. Feed the `sourceKind='acroform'` fields into
  the same UI. For v1, **acroform fields are fill-only, not movable** (moving a
  real field's geometry is an authoring action — Phase C). Gate drag/resize on
  `sourceKind=='app'`.
- Combo/radio need a picker input (new small sheet); text/checkbox/signature
  reuse current inputs.

### A4 — Second exporter: `FillableFormExportService` ☐
New `lib/core/services/fillable_form_export_service.dart`, structured like
`press_service.dart` (isolate via `compute`, serializable job):
- **Imported-PDF case:** load the original bytes, get `pdfDoc.form`, find each
  field by `pdfFieldName`, set its value (`PdfTextBoxField.text`,
  `PdfCheckBoxField.isChecked`, etc.). For `sourceKind='app'` fields the user
  added, *create* new widgets on the matching page (Phase C authoring logic —
  can stub to "flatten these extras" in A if authoring isn't ready).
- **Scanned-page case:** build pages from images (reuse press logic) then add
  live widgets at transformed bounds.
- Save → new PDF path; store on the document (needs a `fillablePdfPath?` column,
  or reuse a generic `exportPath` — decide in A1).

### A5 — Two exits wired (minimal) ☐
- Replace the single "Press & Lock" CTA with a choice. Default action =
  **Save as Fillable**; secondary/confirmed = **Flatten & Sign** (keep the
  existing confirm dialog, strengthen the copy).
- Both land on `send_screen` (already generic over a PDF path).

### A6 — Tests ☐
- `pdf_geometry` round-trip unit tests.
- Export service: author → re-open with Syncfusion → assert field count/values
  match (programmatic, no human needed).
- Migration test (old DB → new schema, data intact).

**Phase A ships when:** import an Acrobat form → fill it → export live → it
opens filled in Acrobat/Preview/Chrome; AND the same doc can alternatively be
flattened. Analyze clean, tests green, debug build passes both platforms.

---

# Phase B — Faithful viewing as a first-class surface  ☐

Mostly integration of the already-embedded `SfPdfViewer`; low novel risk.

- **B1** Dedicated viewer route/screen (not just the tiny review thumbnail):
  pinch-zoom, page nav, thumbnail rail.
- **B2** Text selection + **search-in-document**: you already persist OCR text
  (`Pages.ocrText`, `Documents.ocrText`) — wire it to find/highlight matches;
  for born-digital PDFs use the viewer's own text layer.
- **B3** Annotations (highlight/note) *if* cheap via the viewer; otherwise defer.
- **B4** Open-in-place from Library so viewing is a primary verb, not a step in
  a pipeline.

**Ships when:** any imported PDF renders faithfully, is searchable, and is
reachable as a first-class action from the Library.

---

# Phase C — Authoring (create fillable forms)  ☐

Only after A proves the field round-trip. Authoring = A's export path + a
placement canvas you mostly already have.

- **C1** Promote the `field_detection_screen` overlay editor to a full authoring
  canvas: add/drag/resize/delete typed fields on scanned *or* imported pages,
  set field name, required, default value, options (combo/radio/list).
  (`sourceKind='app'`, movable.)
- **C2** Field inspector panel (name, type, required, tab order).
- **C3** Export via `FillableFormExportService` → a PDF whose fields work in
  Adobe/Preview/Chrome (same acceptance bar as A0).
- **C4** "Turn a scan into a fillable form" flow — the headline authoring story;
  the heuristic detector seeds initial fields, user refines.

**Ships when:** a user can author a multi-field form from a blank scan and the
exported PDF is fillable in all three target renderers.

---

# Phase D — Two-exit resolution & mode clarity  ☐

Harden the "both modes" UX so users never destroy work by accident.

- **D1** Persistent document mode indicator (Draft / Fillable / Flattened) in
  Library + doc header. You already have status pills — extend the enum.
- **D2** "Flatten & Sign" = deliberate, irreversible, explained. "Save as
  Fillable" = default/save. Never equal-weight buttons.
- **D3** Guardrails: warn before flattening a doc that has live acroform fields;
  offer "keep a fillable copy too".
- **D4** Signature semantics honesty: a drawn+flattened signature is **not** a
  certified e-signature. Add plain-language framing (and decide with legal
  whether an audit trail is in scope). Cross-ref the strategy notes.

**Ships when:** a non-expert user understands, at every step, whether their
document is still editable and what each exit does.

---

## Open strategic questions (resolve alongside, not after)

1. **Library viability (eng, spike A0):** does Syncfusion-authored AcroForm
   render correctly in Acrobat + Preview + Chrome? Governs everything.
2. **Scope of "faithful" (founder/PM):** arbitrary real-world PDFs (encrypted,
   XFA, broken fonts) or "PDFs that behave"? First is a multi-year cost.
3. **Pricing collision (founder):** a workbench is a *service* (perpetual PDF-
   engine + OS-churn maintenance); $14.99 one-time funds a *product*. Adobe
   charges monthly for this surface *because* it's a maintenance well. Resolve
   the pricing-model question **before** committing Phase C+.
4. **Differentiator (PM):** does the workbench strengthen "offline + one-time +
   private" (a genuinely compelling private Adobe alternative) or dilute it
   into "a worse Adobe"? Determines whether this is strategy or feature-chasing.

---

## Progress log
- 2026-07-31 — Plan created. A0 spike built (byte-level round-trip proven;
  3-app render check still manual).
- 2026-08-01 — **Phase A complete** (A1 schema+migration, pdf_geometry, A2
  reader, A4 FillableFormExportService, A3/A5 fill UI + two exits). analyze
  clean, 16 tests pass, debug APK builds. Branch `pdf-workbench`. Committed per
  phase. Next: **Phase B** (faithful viewer).
- ⚠️ Still-open gate: human must confirm `docs/acroform_spike.pdf` renders/fills
  correctly in Acrobat + Preview + Chrome before relying on fillable export in
  production. And stakeholder Qs (pricing/scope) remain for Phase C+.
