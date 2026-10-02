# Scan Sign Send — LLM Wiki Hub

> Generated 2026-10-01 from the source tree at version `1.0.0+8` (`pubspec.yaml`).
> Every claim cites a file path. Where code and docs disagree, see
> **Technical Debt Observations** at the bottom of each page.

## Purpose

Offline document scanner + e-signature app for iOS and Android. The user scans
or imports a document, the app detects fillable places (OCR + geometry
heuristics, optionally AcroForm fields from an imported PDF), the user fills and
signs, and the app either **flattens** the result into a PDF ("Press") or
exports a **fillable** PDF, then shares it through the OS share sheet.

- No server, no accounts, no analytics. All data lives in the app's Documents
  directory (`lib/core/db/app_database.dart` → `scan_sign_send.db`).
- Monetisation: one non-consumable IAP, `com.adakventures.scansignsend.fullaccess`
  (`lib/core/services/iap_service.dart`). Free tier = 2 finished documents of
  up to 2 pages each (`lib/core/services/free_usage_service.dart`).
- 7 locales: en, fr, es, pt, hi, ta, te (`lib/l10n/*.arb`, `l10n.yaml`).

## Tech stack map

```
┌──────────────────────────── Flutter 3.41.9 (stable) · Dart SDK ^3.11.5 ───────────────────────────┐
│ UI         Material 3 (AppTheme seed #1A73E8)  ·  go_router ^14  ·  flutter_localizations        │
│ State      flutter_riverpod ^2.5 (manual Provider/StateNotifierProvider — no codegen in use)     │
│ Data       drift ^2.20 + sqlite3_flutter_libs (schema v7) · shared_preferences (onboarding flag) │
│ Files      path_provider · PathResolver (rebases stored paths onto current Documents dir)        │
│ PDF        syncfusion_flutter_pdf / _pdfviewer / _signaturepad ^28.2.12 · printing (raster)       │
│ OCR        google_mlkit_text_recognition ^0.13 (ML Kit on BOTH platforms)                        │
│ Commerce   in_app_purchase ^3.2 (StoreKit / Play Billing)                                        │
│ Security   local_auth ^2.3 · custom privacy/backup/entitlement channels                           │
│ Import/Out file_picker ^8 · share_plus ^10                                                       │
├──────────────────────────────── Platform channels (com.scansignsend/*) ───────────────────────────┤
│ iOS (Swift, ios/Runner/*.swift)            │ Android (Kotlin, android/app/src/main/kotlin/...)   │
│ VisionKit doc camera · Keychain · iCloud    │ ML Kit Doc Scanner · Block Store · FLAG_SECURE ·    │
│ backup flag · Foundation Models stub ·      │ BackupAgent                                        │
│ PrivacyOverlay (blur in app switcher)       │                                                    │
└─────────────────────────────────────────────┴──────────────────────────────────────────────────────┘
```

Shared vs native split: **all product logic is Dart** (`lib/`). Native code is
~740 lines total and limited to camera capture, OS storage that survives
reinstall, OS backup flags, screenshot/app-switcher privacy, and an AI stub.
Details: [[Native Bridges and Plugins]].

## Link tree

| Page | File | Covers |
|---|---|---|
| [[State and Data Flow]] | `state-and-data-flow.md` | Riverpod graph, drift schema, repositories, file storage, isolates, free-tier/IAP state |
| [[Native Bridges and Plugins]] | `native-bridges-and-plugins.md` | Every MethodChannel, per-platform handlers, third-party plugins with native code |
| [[UI and Design System]] | `ui-and-design-system.md` | Theme, routes/screens, shared widgets, l10n, fonts, icons, splash |
| [[Mobile Ops and CI]] | `mobile-ops-and-ci.md` | Toolchain, build/release commands, Fastlane lanes, GitHub Actions, permission map |

### Feature → code map

| Flow step | Route (`lib/core/utils/router.dart`) | Screen | Key services |
|---|---|---|---|
| Library (home) | `/` | `lib/features/library/presentation/library_screen.dart` | `DocumentRepository`, `TemplateService` |
| Search | `/search` | `lib/features/library/presentation/search_screen.dart` | `DocumentRepository.watchByQuery` |
| Capture / import | `/capture?action=scan\|import` | `lib/features/capture/presentation/capture_screen.dart` | `ScanService`, `ImportService` |
| Review pages | `/review/:docId` | `lib/features/review/presentation/review_screen.dart` | `PageRepository` |
| Field detection / editor | `/field-detection/:docId` | `lib/features/field_detection/presentation/field_detection_screen.dart` + `field_detection_notifier.dart` | `PageLayoutService`, `FieldDetectionEngine`, `AiEnhancerService`, `FieldHintRepository` |
| Fill | `/fill/:docId` | `lib/features/fill_mode/presentation/fill_mode_screen.dart` | `FieldRepository` |
| Sign | `/signature/:docId/:fieldId[?initials=1]` | `lib/features/signature/presentation/signature_capture_screen.dart` | `SignatureRepository` |
| Press / export | `/press/:docId` | `lib/features/press/presentation/press_screen.dart` | `PressService`, `FillableFormExportService`, `FreeUsageService` |
| Send | `/send/:docId` | `lib/features/send/presentation/send_screen.dart` | `lib/shared/utils/share_pdf.dart` |
| Viewer | `/viewer/:docId` | `lib/features/viewer/presentation/document_viewer_screen.dart` | syncfusion pdfviewer |
| Settings | `/settings`, `/settings/signatures` | `lib/features/settings/presentation/*.dart` | `ProfileRepository`, `BackupService`, `IapService` |
| Onboarding | (not routed — shown by `main.dart`) | `lib/features/onboarding/presentation/onboarding_screen.dart` | `SharedPreferences` |
| Paywall | (pushed as a widget) | `lib/shared/widgets/paywall_screen.dart` | `IapService` |

## Deployment variants & environments

| Variant | Exists? | Evidence |
|---|---|---|
| Staging vs Production **flavors** | **No.** Single flavor. | No `productFlavors` in `android/app/build.gradle.kts`; only `Runner.xcscheme`; no `lib/main_*.dart` |
| Build modes | Debug / Profile / Release (Flutter defaults) | `ios/Podfile` project config; `android/app/src/{debug,profile,main}/AndroidManifest.xml` |
| Testing track | TestFlight (internal) / Play **internal** track (`release_status: draft`) | `ios/fastlane/Fastfile` `beta`, `local_testflight`; `android/fastlane/Fastfile` `internal` |
| Production | Manual promotion in App Store Connect / Play Console (`promote_to_production` lane exists for Play) | `.github/DEPLOYMENT.md`, `scripts/release.sh` header |

There are no environment variables, API base URLs, or backend endpoints — the
app has no server. "Environment" differences are limited to signing:

| | iOS | Android |
|---|---|---|
| App ID | `com.adakVentures.scanSignSend` (team `T995T8G6Z2`) | `com.adakventures.scansignsend` |
| Min OS | iOS 15.0 (`IPHONEOS_DEPLOYMENT_TARGET`, `ios/Podfile`) | `flutter.minSdkVersion` (launcher-icon config says 21) |
| Release signing | Automatic signing on dev Mac; manual p12 + profile in CI | `android/key.properties` (git-ignored); falls back to **debug** signing if missing |
| Release hardening | — | `isMinifyEnabled` + `isShrinkResources`, `proguard-rules.pro` |

Versioning: `version: 1.0.0+8` in `pubspec.yaml`. Local releases require a
manual `+N` bump; CI releases override with `--build-number=${{ github.run_number }}`.
See [[Mobile Ops and CI]].

## Technical Debt Observations (project-wide doc drift)

Resolved 2026-10-01: `README.md` price (now $9.99 base, matching
`store/PRICING.md`); `CLAUDE.md` paywall rule, stack table, folder layout,
codegen note and platform-channel section now match the code.

Also resolved 2026-10-01: stale code comments (pubspec OCR note,
`privacy_screen_service.dart`, `ai_enhancer_service.dart`, `ci.yml`,
`ios/Podfile`) and the unused `riverpod_annotation` / `riverpod_generator`
dependencies were removed.
