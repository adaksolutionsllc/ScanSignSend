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
| State | flutter_riverpod (hand-written `Provider`/`StateNotifierProvider`; no codegen) |
| Database | drift (SQLite, pure Dart) |
| PDF | syncfusion_flutter_pdf + syncfusion_flutter_pdfviewer |
| Signature pad | syncfusion_flutter_signaturepad |
| Biometrics | local_auth |
| OCR | google_mlkit_text_recognition (ML Kit on both platforms) |
| Purchases | in_app_purchase |

## Folder layout
```
lib/
  core/
    db/          # AppDatabase, generated .g.dart, providers
    models/      # Thin extensions / enums on generated row types
    services/    # Repositories (document_repository.dart holds Document/Page/FieldRepository),
                 # detection, PDF press/export, import, IAP, free tier, platform-channel services
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
    settings/        # profile, biometrics, purchase, signatures manager
    onboarding/      # first-run pages (shown by main.dart, not routed)
    viewer/          # in-app PDF viewer
  shared/
    theme/           # AppTheme (light/dark, status colours)
    widgets/         # Reusable widgets (PageCanvas, FieldBox, PaywallScreen)
    utils/           # share_pdf.dart
```

Architecture reference: `docs/.llm_wiki/` (index, state, native bridges, UI, ops).

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
Always run after touching `app_database.dart` (drift is the only codegen in use):
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
- [x] Phase 4 — Monetisation (free tier → paywall, StoreKit 2, Play Billing)
- [~] Phase 5 — AI enhancement: channel + fallback wired; iOS Foundation Models call is a stub returning [], no Android handler
- [x] Phase 6 — Moat features (templates, library actions, signatures manager)

## Exit tests
- Phase 1: 10-page batch scan → clean PDF in <60 s
- Phase 2: ≥80% field recall on 25-form test corpus
- Phase 3: full Scan→Sign→Send cycle works end-to-end

## Paywall rule
`FreeUsageService` (`core/services/free_usage_service.dart`) gates finishing a document
(Flatten & Sign or Save as Fillable): 2 free documents of up to 2 pages each, counted once per
document (`Documents.countedFree`). Used count = max(`UserProfile.scanCount`, Keychain/Block Store
copy) so reinstalling doesn't reset it. `isPurchased` (set by `IapService` from StoreKit / Play
Billing, product `com.adakventures.scansignsend.fullaccess`) bypasses.

## Platform channels (`com.scansignsend/*`, all MethodChannel)
| Channel | iOS (`ios/Runner/`) | Android (`MainActivity.kt` / plugin) |
|---|---|---|
| `scanner` | `DocumentScannerPlugin.swift` — VisionKit doc camera | `DocumentScannerPlugin.kt` — ML Kit Document Scanner |
| `entitlement` | `EntitlementPlugin.swift` — Keychain free-use counter | Block Store |
| `backup` | `BackupPlugin.swift` — `isExcludedFromBackup` | `AppBackupAgent` opt-in flag |
| `privacy` | — (always-on `PrivacyOverlay.swift`) | `FLAG_SECURE` |
| `ai_enhancer` | `AiFieldEnhancerPlugin.swift` — stub | — |
| `open_file` | `OpenFilePlugin.swift` — PDFs opened via "Open in…" (CFBundleDocumentTypes) | `OpenFileHandler.kt` — VIEW/SEND `application/pdf` intents |

OCR is the `google_mlkit_text_recognition` plugin; PDFs are built in Dart with Syncfusion.
Details: `docs/.llm_wiki/native-bridges-and-plugins.md`.
