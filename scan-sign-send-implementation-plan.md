# Scan Sign Send — Implementation Plan

**Product:** Offline scanner + on-device AI form-filling + e-signature. One-time purchase. No cloud, no account, no subscription.

**Positioning:** "Sign unlimited documents forever for less than one month of DocuSign." Target the everyday-paperwork segment (leases, waivers, intake forms, permission slips, invoices, simple NDAs) — not enterprise audit-trail workflows.

---

## 1. Screen-by-Screen User Flow

### S1 — Library (Home)
- Grid/list of documents with status chips: **Draft** (amber), **Pressed** (green lock), **Template** (blue)
- Primary FAB: "+ New Scan" · Secondary: "Import PDF/Image"
- Search bar (searches OCR'd text — all local)
- Empty state teaches the 3-step loop: Scan → Sign → Send

### S2 — Capture
- Live camera with real-time edge detection and auto-snap
- Batch mode: keep shooting pages, running page counter
- Flash, grayscale/color toggle
- Alternative entry: system file picker (PDF, JPG, PNG, HEIC)

### S3 — Review & Correct
- Per-page: drag corner handles for perspective correction, rotate, retake, reorder, delete
- Filters: original / enhanced / B&W document
- "Detect Fields →" primary CTA

### S4 — Field Detection (the magic moment)
- Progress: "Reading your document…" (OCR + CV pass, <2s)
- Detected fields render as colored overlays on the document: text lines, checkboxes, date fields, signature lines
- Each overlay is tappable: confirm, resize, retype (Text ⇄ Date ⇄ Checkbox ⇄ Signature), or delete
- Toolbar to add missed fields manually: **[T] Text · [✓] Check · [📅] Date · [✍] Signature**
- Optional toggle (v1.1): "Enhanced AI detection" — runs the on-device model for semantic labels and tricky layouts

### S5 — Fill Mode
- Tap a field → keyboard/date-picker/check toggle
- Signature field → S6
- Smart fill chips above keyboard: saved profile values (name, address, phone, today's date)
- Auto-save to Draft on every change; back out anytime, resume later

### S6 — Signature Capture
- Full-width draw canvas (finger/stylus), undo, thickness, ink color (black/blue)
- "Save as my signature" → reused across all future docs (stored locally, optionally behind Face ID/biometric)
- Support multiple saved signatures + initials

### S7 — Press (lock & flatten)
- Review summary: all fields listed with values, unfilled fields flagged
- Confirmation modal: "Pressing embeds your entries permanently. The filled copy can't be edited. Your blank original is kept as a template."
- On confirm: fields are burned into a flattened PDF; a signing-date stamp and optional local certification page are appended
- Output: **Pressed copy** (immutable) + **original preserved as reusable Template**

### S8 — Send
- Native share sheet: Mail, Messages, WhatsApp, AirDrop, Files/Drive, print
- Post-share prompt: "Save as reusable template?" (if not already)
- Return to Library; Pressed doc shows lock badge

### Settings
- My profile (autofill values), signatures manager, default filters, biometric app lock, AI model toggle/download, restore purchase

---

## 2. Revenue Model

### Pricing structure
| Tier | Price | Contents |
|---|---|---|
| Free | $0 | 3 full Scan→Sign→Send cycles (full quality, no watermark — let the product sell itself) |
| Full unlock | **$14.99 one-time** | Unlimited docs, templates, multiple signatures, profile autofill |
| Launch price | $9.99 intro → raise to $14.99 | Creates urgency, seeds early reviews |

Rationale: DocuSign Personal is ~$120/yr for 5 envelopes/month; Adobe personal signing ~$15/mo. Your one-time price equals ~1 month of the incumbent. Do not subscribe-ify — the anti-subscription stance *is* the brand.

### Conversion math (conservative)
- Paid conversion of free installers for utility apps with hard paywalls after real value delivery: 2–5%
- Blended ASP after store fees (15% small-business rate): ~$12.70 net per sale at $14.99

| Monthly downloads | Conv. | Sales/mo | Net revenue/mo |
|---|---|---|---|
| 3,000 | 2% | 60 | ~$760 |
| 10,000 | 3% | 300 | ~$3,800 |
| 30,000 | 4% | 1,200 | ~$15,200 |

Downloads are the whole game → ASO keywords ("sign PDF", "fill form", "scan and sign", "offline signature"), privacy-angle content marketing, and Microsoft Lens–refugee targeting (retired 2026).

### Cost base
- No servers, no per-user cost. Fixed: developer accounts (~$124/yr combined), optional analytics (privacy-safe/local), your time.
- Break-even is effectively immediate; every sale is margin.

---

## 3. Build Plan (phased)

**Stack recommendation:** Flutter (single codebase, both stores) + platform channels to native ML:
- iOS: VisionKit (document camera), Vision (OCR + rectangle/line detection), PDFKit, Apple Foundation Models (iOS 26+) for the AI toggle
- Android: ML Kit Document Scanner + ML Kit Text Recognition, PdfRenderer/pdfbox-android, Gemini Nano via ML Kit GenAI where available
- Shared: pdf generation/flattening lib (e.g., syncfusion_flutter_pdf or native passes)

### Phase 0 — Foundation (week 1)
Project setup, CI, local storage schema (docs, pages, fields, signatures, profile), biometric lock plumbing.

### Phase 1 — Scan core (weeks 2–3)
Capture with edge detection, batch, review/correct, filters, multi-page PDF assembly, Library CRUD. *Exit test: 10-page batch scan to clean PDF in under 60 seconds.*

### Phase 2 — Field engine (weeks 4–6)
OCR pass → geometry heuristics (underscores/rules → text fields; small squares → checkboxes; "X ____" / "Signature" labels → signature fields; date-adjacent labels → date fields). Manual field toolbar. Field overlay editor. *Exit test: ≥80% field recall on a 25-form test corpus of common US forms.*

### Phase 3 — Sign & Press (weeks 7–8)
Signature capture/storage, fill mode with profile chips, flattening pipeline, date stamp + certification page, template preservation, share sheet. **This completes the sellable MVP.**

### Phase 4 — Monetization & launch (weeks 9–10)
Paywall (after 3rd Press), StoreKit 2 / Play Billing, restore purchase, onboarding, ASO assets, beta (TestFlight/Play internal), launch at $9.99 intro.

### Phase 5 — AI enhancement (v1.1)
"Enhanced detection" toggle: platform-native model first (zero download); optional downloadable small vision model (Gemma-class) for older devices — app picks size by device RAM, user never chooses. Semantic labeling + autofill mapping.

### Phase 6 — Moat features (v1.2+)
Reusable template library, initials/multi-signer on one device (hand the phone over), folder org, on-device search, iPad/tablet layouts.

---

## 4. Claude Code Orchestrator Workflow (how this gets built)

Delegation policy for every phase above:

| Task type | Route to |
|---|---|
| Architecture, storage schema, flattening design, tricky CV heuristics, security review | **Opus** (deep reasoning) |
| Screen scaffolding, CRUD, tests, refactors, platform-channel boilerplate, docs | **Sonnet** (mechanical work) |
| Planning, task decomposition, code review of merged results | **Orchestrator** (Fable 5; Opus if Fable unavailable) |

Per-phase loop: Orchestrator drafts the phase task list → fans out mechanical tickets to Sonnet subagents (parallel where independent) → routes design/algorithm tickets to Opus → reviews diffs → integrates → runs exit test.

See the project's `.claude/` config (CLAUDE.md + agents/) — defined in the chat setup — for the automatic version of this.
