# State and Data Flow

Back to [[Index]] · Related: [[Native Bridges and Plugins]] · [[UI and Design System]]

## Paradigm

**Riverpod 2 (`flutter_riverpod ^2.5.1`), hand-written providers.** There are
no Riverpod code generation (`riverpod_annotation` / `riverpod_generator` were
removed as unused on 2026-10-01). The only `.g.dart` file
is drift's `lib/core/db/app_database.g.dart`.

There is **no network layer and no API data**. The single source of truth is a
local SQLite database (drift). "Data flows down" means:

```
SQLite (drift, scan_sign_send.db)
   │  .watch() streams
   ▼
Repositories (Provider<…Repository>)           lib/core/services/*_repository.dart
   │  Stream<List<Row>> / Future<Row>
   ▼
Screens: StreamBuilder / FutureBuilder + ref.read(...)   lib/features/*/presentation/
   │  user edits
   ▼
Repository writes (Companion objects) ──► drift ──► streams re-emit ──► UI rebuilds
```

Most screens consume repository streams with `StreamBuilder`/`FutureBuilder`
directly rather than through `StreamProvider`s (17 builder usages across
`lib/features`; one `StreamProvider` in the whole app: `isPurchasedProvider`).

## ProviderScope root

`lib/main.dart` wraps the app in a single `ProviderScope` with no overrides.
At launch `_ScanSignSendAppState.initState` eagerly reads `iapServiceProvider`
(so pending store purchases are acknowledged) and applies the backup setting
via `backupServiceProvider`.

## Provider inventory

| Provider | Kind | File | Depends on |
|---|---|---|---|
| `appDatabaseProvider` | `Provider<AppDatabase>` (closes DB on dispose) | `lib/core/db/database_provider.dart` | — |
| `documentRepositoryProvider` | `Provider` | `lib/core/services/document_repository.dart` | DB |
| `pageRepositoryProvider` | `Provider` | same file | DB |
| `fieldRepositoryProvider` | `Provider` | same file | DB |
| `profileRepositoryProvider` | `Provider` | `lib/core/services/profile_repository.dart` | DB |
| `signatureRepositoryProvider` | `Provider` | `lib/core/services/signature_repository.dart` | DB |
| `fieldHintRepositoryProvider` | `Provider` | `lib/core/services/field_hints.dart` | DB |
| `templateServiceProvider` | `Provider` | `lib/core/services/template_service.dart` | doc/page/field repos |
| `pressServiceProvider` | `Provider` | `lib/core/services/press_service.dart` | doc/page/field repos |
| `fillableFormExportServiceProvider` | `Provider` | `lib/core/services/fillable_form_export_service.dart` | repos |
| `importServiceProvider` | `Provider` | `lib/core/services/import_service.dart` | repos |
| `pageLayoutServiceProvider` | `Provider` | `lib/core/services/page_layout_service.dart` | OCR, raster |
| `pageRasterServiceProvider` | `Provider` | `lib/core/services/page_raster_service.dart` | — |
| `ocrServiceProvider` | `Provider` (disposes recognizer) | `lib/core/services/ocr_service.dart` | — |
| `fieldDetectionEngineProvider` | `Provider` | `lib/core/services/field_detection_engine.dart` | — |
| `aiEnhancerServiceProvider` | `Provider` | `lib/core/services/ai_enhancer_service.dart` | profile repo |
| `pdfAssemblyServiceProvider` | `Provider` | `lib/core/services/pdf_assembly_service.dart` | (unused — see debt) |
| `freeUsageServiceProvider` | `Provider` | `lib/core/services/free_usage_service.dart` | profile + doc repos |
| `iapServiceProvider` | `Provider` (disposes purchase stream sub) | `lib/core/services/iap_service.dart` | profile repo |
| `isPurchasedProvider` | `StreamProvider<bool>` | same file | `ProfileRepository.watch()` |
| `scanServiceProvider` | `Provider` | `lib/core/services/scan_service.dart` | channel |
| `backupServiceProvider` | `Provider` | `lib/core/services/backup_service.dart` | channel |
| `privacyScreenServiceProvider` | `Provider` | `lib/core/services/privacy_screen_service.dart` | channel |
| `biometricServiceProvider` | `Provider` | `lib/core/services/biometric_service.dart` | `local_auth` |
| `appLockProvider` | `StateNotifierProvider<AppLockNotifier, bool>` | `lib/core/services/app_lock_provider.dart` | biometric, profile, privacy |
| `fieldDetectionNotifierProvider` | `StateNotifierProvider.autoDispose.family<…, int docId>` | `lib/features/field_detection/presentation/field_detection_notifier.dart` | layout, hints, AI, doc/page repos |
| `routerProvider` | `Provider<GoRouter>` | `lib/core/utils/router.dart` | — |

## Global vs local state

| State | Scope | Where it lives |
|---|---|---|
| Documents, pages, fields, signatures, learned hints | Global, persistent | drift tables (below) |
| Profile (autofill data, settings toggles, `isPurchased`, `scanCount`) | Global, persistent | `UserProfile` table — single row, `ProfileRepository.getOrCreate()` |
| App lock (locked/unlocked) | Global, in-memory | `appLockProvider` (`bool`) |
| Field-editor working set (detected/confirmed boxes per doc) | Screen-scoped, auto-disposed | `FieldDetectionState` in `fieldDetectionNotifierProvider(docId)`; writes through to `FieldRepository` |
| Onboarding seen | Global, persistent | `SharedPreferences` bool, `lib/features/onboarding/presentation/onboarding_screen.dart` (`isOnboardingDone()`) |
| Text controllers, selection, transient UI | Widget-local | `StatefulWidget` / `ConsumerStatefulWidget` `setState` (~48 calls across features) |
| Free-allowance counter (reinstall-proof copy) | Global, persistent, **native** | iOS Keychain / Android Block Store via `com.scansignsend/entitlement` |
| Device-backup opt-in (Android mirror) | Native | Android `SharedPreferences("device_backup")` in `AppBackupAgent.kt` |

## Persistence: drift schema (v7)

`lib/core/db/app_database.dart`, file `<Documents>/scan_sign_send.db`, opened
with `NativeDatabase.createInBackground` (drift's own background isolate).

| Table | Purpose | Notable columns |
|---|---|---|
| `Documents` | One per document/template | `status` (`draft`/`pressed`/`fillable`/`template`, enum in `lib/core/models/document_model.dart`), `pressedPdfPath`, `fillablePdfPath`, `isTemplate`, `textSize`, `countedFree` |
| `Pages` | Ordered pages | `documentId`, `pageIndex`, `imagePath` (may carry `#page=N` for PDF pages), `activeFilter`, `ocrText` |
| `Fields` | Fill-in boxes | `type`, `boundingBoxJson` (normalised 0..1 to page content), `value`, `isChecked`, `signatureId`, `pdfFieldName`, `sourceKind` (`app` / AcroForm), `optionsJson` |
| `Signatures` | Saved signatures/initials | `imagePath`, `isDefault`, `isInitials` |
| `UserProfile` | Single-row settings | `biometricLockEnabled`, `aiEnhancedDetection`, `scanCount`, `isPurchased`, `includeInDeviceBackup` |
| `FieldHints` | On-device learning from user edits | `phrase`, `type`, `accepted`, `rejected` |

Migrations are additive (`from < N` blocks, v1→v7). Tests:
`test/migration_test.dart`, `test/migration_v1_to_v2_test.dart`. After touching
the schema: `dart run build_runner build --delete-conflicting-outputs`.

## Persistence: files

All under the app Documents directory, in four owned roots: `pages/`,
`pressed/`, `fillable/`, `signatures/` (`lib/core/utils/path_resolver.dart`).
`PathResolver.init()` runs in `main()` before `runApp`; `PathResolver.resolve()`
rebases any stored absolute path onto the current container because the iOS
container UUID changes across reinstall/restore. Scanner output is staged in
temp/cache and moved into `pages/` by Dart (see
[[Native Bridges and Plugins]]). Deletion cleanup lives in
`DocumentRepository._purgeFilesFor` / `PageRepository._deleteFileIfUnreferenced`
(test: `test/document_delete_cleanup_test.dart`).

No Hive, MMKV, or `flutter_secure_storage` is used. Secrets-like state (free
counter) goes through the custom entitlement channel instead.

## Heavy work off the UI isolate

| Work | Mechanism | File |
|---|---|---|
| Flatten ("Press") PDF | `compute(_buildPressedPdf, job)` with serialisable `_PagePlan`/`_FieldPlan` (no drift types cross) | `lib/core/services/press_service.dart` |
| Fillable PDF export | `compute(_buildFillablePdf, job)` | `lib/core/services/fillable_form_export_service.dart` |
| PDF import parse, RGBA→JPEG | `compute(_parsePdf)`, `compute(_encodeRgbaJpeg)` | `lib/core/services/import_service.dart` |
| PDF text layer, ruled-line detection | `compute(pdfTextLayout)`, `compute(detectRules)` | `lib/core/services/page_layout_service.dart` |
| Page rotation | `compute(_rotateJpegClockwise)` | `lib/core/services/document_repository.dart` |
| Signature crop/transparency | `compute(_cropAndMakeTransparent)` | `lib/features/signature/presentation/signature_capture_screen.dart` |

Constraint: anything needing `dart:ui` text shaping or localized strings is
prepared on the main isolate first. Indic text is rendered to PNG by
`lib/core/services/shaped_text.dart` and certificate strings are passed in as
`PressCertificateStrings` (`press_service.dart`), because a `compute()` isolate
has no Flutter engine or intl locale data.

## Key flows

### Field detection
`PageLayoutService` builds a `PageLayout` (text lines + ruled lines,
normalised) from either the PDF text layer or ML Kit OCR on a raster →
`FieldDetectionEngine.detect(layout, hints)` (pure Dart heuristics) →
optionally `AiEnhancerService` replaces results if `profile.aiEnhancedDetection`
**and** the native model reports available; any failure falls back to the
heuristic result → `FieldDetectionNotifier` holds the editable set and writes
through to `FieldRepository`; user accept/reject updates `FieldHints`.

### Free tier & purchase
```
PressScreen ─► FreeUsageService.checkFinish(doc, pageCount)
                 ├─ isPurchased? → allowed
                 ├─ pageCount > 2 → tooManyPages
                 ├─ doc.countedFree → allowed (already counted)
                 └─ usedCount() ≥ 2 → allowanceUsed → PaywallScreen
usedCount() = max(UserProfile.scanCount, PersistentCounter.read())  # heals the lower copy
recordFinish(docId) → countedFree=true, scanCount++, PersistentCounter.write()
IapService purchaseStream → ProfileRepository.update(isPurchased=true) → isPurchasedProvider emits
```
Tests: `test/free_usage_test.dart`.

### App lock
`AppLockNotifier` subscribes to `ProfileRepository.watch()`; when
`biometricLockEnabled` flips it calls `PrivacyScreenService.setSecure`. It
re-locks on `paused`/`hidden`/`detached` unless inside `whileExternal(...)`
(used around scanner, file picker, share sheet, purchase). `AppLockGate`
(inside `MaterialApp.router.builder`) overlays `_LockScreen` with a `Stack`
so underlying screens keep their state.

## Technical Debt Observations

- **Legacy `StateNotifier` API**: `appLockProvider` and
  `fieldDetectionNotifierProvider` use `StateNotifierProvider`, which Riverpod 2
  treats as legacy in favour of `Notifier`/`AsyncNotifier`.
- **Repositories mostly bypass Riverpod for reactivity**: screens subscribe to
  repository streams with `StreamBuilder` rather than providers, so caching
  and deduplication of identical streams don't happen across widgets.
- **`document_repository.dart` hosts three repositories**
  (`DocumentRepository`, `PageRepository`, `FieldRepository`, 458 lines).
- **`PdfAssemblyService` appears dead**: `pdfAssemblyServiceProvider` is
  defined but no other file references it.
- **Dual source of truth for the free counter** (DB + native) is intentional
  (reinstall-proofing) and reconciled by `max()`, but the Android copy depends on
  the user's Google Backup being enabled.
