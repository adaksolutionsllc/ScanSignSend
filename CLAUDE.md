# Scan Sign Send — CLAUDE.md

## What this is
Offline document scanner + e-signature iOS/Android app. Flutter + platform channels.
One-time purchase ($9.99 base; per-country pricing — see store/PRICING.md).
No server, no accounts, no subscription.

## Stack
| Layer | Tech |
|---|---|
| Framework | Flutter 3.x (stable) |
| Navigation | go_router |
| State | flutter_riverpod + riverpod_annotation |
| Database | drift (SQLite, pure Dart) |
| PDF | syncfusion_flutter_pdf + syncfusion_flutter_pdfviewer |
| Signature pad | syncfusion_flutter_signaturepad |
| Biometrics | local_auth |
| Permissions | permission_handler |

## Folder layout
```
lib/
  core/
    db/          # AppDatabase, generated .g.dart, providers
    models/      # Thin extensions / enums on generated row types
    services/    # Repositories (DocumentRepository, etc.), BiometricService, AppLockProvider
    utils/       # router.dart, misc helpers
  features/
    library/         # S1 — home grid
    capture/         # S2 — camera
    review/          # S3 — perspective correct, reorder
    field_detection/ # S4 — OCR + geometry heuristics
    fill_mode/       # S5 — tap fields to fill
    signature/       # S6 — draw canvas
    press/           # S7 — flatten PDF
    send/            # S8 — share sheet
    settings/        # profile, biometrics, purchase
  shared/
    theme/           # AppTheme (light/dark, status colours)
    widgets/         # Reusable widgets
```

## Localization
7 locales: **en, fr, es, pt, hi, ta, te**. Source of truth is `lib/l10n/app_en.arb`;
generated classes land in `lib/l10n/app_localizations*.dart` (committed).

```bash
flutter gen-l10n     # after editing any .arb
```

Rules:
- Reach strings via `context.l10n.someKey` (extension in `core/utils/l10n_ext.dart`).
- Resolve strings **before** an `await` — `context` is unsafe across async gaps.
- Code with no BuildContext (services, isolates) must not hold user-facing text.
  Throw a typed exception or take the translated string as a parameter — see
  `ImportException`, `PressCertificateStrings`.
- Adding a key means adding it to **all 7** files;
  `test/l10n_completeness_test.dart` fails the build otherwise.
- Syncfusion must stay on 28.x+ — 27.x caps `intl` below what
  `flutter_localizations` pins.

## Codegen
Always run after touching `app_database.dart` or any `@riverpod` annotation:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Agent delegation policy (from implementation plan)
| Task type | Agent |
|---|---|
| Architecture, schema, flattening design, CV heuristics, security | **Opus** |
| Screen scaffolding, CRUD, tests, boilerplate | **Sonnet** |
| Planning, task decomposition, review | **Orchestrator (Fable 5)** |

## Phase status
- [x] Phase 0 — Foundation (project, DB schema, routing, biometrics, CLAUDE.md)
- [x] Phase 1 — Scan core (camera, edge detection, batch, review, library CRUD)
- [x] Phase 2 — Field engine (OCR, geometry heuristics, overlay editor)
- [x] Phase 3 — Sign & Press (signature capture, fill, flatten, share) ← **sellable MVP**
- [x] Phase 4 — Monetisation (paywall after 3rd Press, StoreKit 2, Play Billing)
- [x] Phase 5 — AI enhancement (on-device model, semantic labels)
- [x] Phase 6 — Moat features (templates, library actions, signatures manager)

## Exit tests
- Phase 1: 10-page batch scan → clean PDF in <60 s
- Phase 2: ≥80% field recall on 25-form test corpus
- Phase 3: full Scan→Sign→Send cycle works end-to-end

## Paywall rule
`ProfileRepository.canScan()` gates every Press action.
Free users get 3 full cycles (scanCount < 3). isPurchased bypasses.
Phase 4 wires StoreKit 2 (iOS) / Play Billing (Android) to set `isPurchased = true`.

## iOS platform channels needed (Phase 1+)
- VisionKit `VNDocumentCameraViewController` → page images
- Vision `VNDetectRectanglesRequest` for real-time edge detection
- PDFKit for final assembly

## Android platform channels needed (Phase 1+)
- ML Kit Document Scanner API → page images
- ML Kit Text Recognition v2 → OCR
- pdfbox-android or iTextG for PDF assembly
