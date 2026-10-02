# Native Bridges and Plugins

Back to [[Index]] · Related: [[State and Data Flow]] · [[Mobile Ops and CI]]

All custom bridges are **`MethodChannel`s** using the standard codec under the
`com.scansignsend/` prefix. There are **no `EventChannel`s, no Pigeon, and no
`dart:ffi` bindings** in app code (drift's `sqlite3` FFI is inside the package).

## Channel matrix

| Channel | Dart caller | Methods | iOS handler | Android handler |
|---|---|---|---|---|
| `com.scansignsend/scanner` | `lib/core/services/scan_service.dart` | `scanAvailable` → `bool`; `scan({pageLimit?})` → `List<String>` paths | `ios/Runner/DocumentScannerPlugin.swift` (VisionKit `VNDocumentCameraViewController`) | `android/app/src/main/kotlin/com/adakventures/scansignsend/DocumentScannerPlugin.kt` (ML Kit `GmsDocumentScanning`) |
| `com.scansignsend/entitlement` | `lib/core/services/free_usage_service.dart` (`PersistentCounter`) | `getFreeUsed` → `int`; `setFreeUsed({value})` → `bool` | `ios/Runner/EntitlementPlugin.swift` (Keychain) | `MainActivity.kt` inline handler (Play services Block Store) |
| `com.scansignsend/backup` | `lib/core/services/backup_service.dart` | `apply({include, path})` | `ios/Runner/BackupPlugin.swift` (`isExcludedFromBackup`) | `MainActivity.kt` inline → `AppBackupAgent.setEnabled` + `BackupManager.dataChanged()` |
| `com.scansignsend/privacy` | `lib/core/services/privacy_screen_service.dart` | `setSecure({enabled})` | **none** (iOS uses always-on `PrivacyOverlay`) | `MainActivity.kt` inline (`FLAG_SECURE`) |
| `com.scansignsend/ai_enhancer` | `lib/core/services/ai_enhancer_service.dart` | `isAvailable` → `bool`; `enhance({ocrText})` → `List<Map>` | `ios/Runner/AiFieldEnhancerPlugin.swift` (**stub**, returns `[]`) | **none** |

Every Dart caller wraps calls in `try/catch` and degrades silently
(`MissingPluginException` → default value), so a missing handler never crashes.

## Registration

- **iOS** — `ios/Runner/AppDelegate.swift`: implements
  `FlutterImplicitEngineDelegate.didInitializeImplicitFlutterEngine`, calls
  `GeneratedPluginRegistrant.register` then registers `DocumentScannerPlugin`,
  `AiFieldEnhancerPlugin`, `BackupPlugin`, `EntitlementPlugin` by registrar name.
  `didFinishLaunching` activates `PrivacyOverlay.shared`. Scene-based lifecycle:
  `ios/Runner/SceneDelegate.swift` is an empty `FlutterSceneDelegate` subclass.
- **Android** — `MainActivity.kt` extends **`FlutterFragmentActivity`**
  (required by `local_auth`) and in `configureFlutterEngine` adds
  `DocumentScannerPlugin()` (a full `FlutterPlugin` + `ActivityAware` +
  `ActivityResultListener`) and three inline `MethodChannel` handlers.

## Per-bridge detail

### Scanner (`com.scansignsend/scanner`)
| | iOS | Android |
|---|---|---|
| API | VisionKit `VNDocumentCameraViewController` | `play-services-mlkit-document-scanner:16.0.0`, `SCANNER_MODE_FULL`, JPEG, gallery import allowed |
| Page cap | Not supported — Dart re-checks count afterwards | `pageLimit` arg, clamped 1..20 (default 20) |
| Output | JPEG q=0.92 to `tmp/scan_staging/scan_<uuid>_page_<i>.jpg`; also deletes legacy `Documents/scan_staging` | copied from content URI to `cacheDir/scan_page_<uuid>.jpg` |
| Cancel | `[]` | `[]` |
| Errors | `UNAVAILABLE`, `ALREADY_ACTIVE`, `NO_PRESENTER`, `SCAN_FAILED` | `NO_ACTIVITY`, `ALREADY_ACTIVE`, `SCAN_FAILED` |
| Presentation | from top-most presented VC (avoids silent failure under sheets/overlay) | `startIntentSenderForResult`, request code `0x5CA3` |

Dart (`ScanService.scan`) maps `UNAVAILABLE` → empty list and rethrows other
`PlatformException`s. The capture flow wraps the call in
`AppLockNotifier.whileExternal` so the lock doesn't re-arm mid-scan.

### Entitlement (`com.scansignsend/entitlement`)
- iOS: generic-password Keychain item, service
  `com.adakventures.scansignsend.allowance`, account `freeDocumentsUsed`,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (not synced; survives
  reinstall).
- Android: Block Store key `com.adakventures.scansignsend.freeDocumentsUsed`,
  `setShouldBackupToCloud(false)`; failures resolve to `0` / `false`.

### Backup (`com.scansignsend/backup`)
- iOS sets `URLResourceValues.isExcludedFromBackup = !include` on the
  Documents directory passed from Dart.
- Android persists the flag in native `SharedPreferences("device_backup")`
  because `AppBackupAgent` runs without a Flutter engine.
  `AppBackupAgent.onFullBackup` writes nothing unless enabled; manifest sets
  `fullBackupOnly="true"`, rules in `android/app/src/main/res/xml/backup_rules.xml`
  (pre-12, `clientSideEncryption` required) and `data_extraction_rules.xml`
  (12+, `disableIfNoEncryptionCapabilities="true"`).
- Dart re-applies the setting on every launch (`main.dart`).

### Privacy
- Android: `FLAG_SECURE` toggled from the biometric-lock setting via
  `AppLockNotifier` → `PrivacyScreenService`; re-asserted post-first-frame by
  `AppLockGate.syncPrivacyScreen()`.
- iOS: `ios/Runner/PrivacyOverlay.swift` adds a `.systemThickMaterial` blur with
  a `lock.doc.fill` glyph on `didEnterBackground`, removes it on
  `willEnterForeground`/`didBecomeActive`. Always on; not tied to the setting.
  Deliberately avoids `willResignActive` so the Face ID sheet doesn't trigger it.

### AI enhancer
iOS returns `isAvailable = true` on iOS 26+, but `runFoundationModel` is a stub
returning `[]`, so `AiEnhancerService.detect` always falls back to heuristics.

## Third-party plugins with native code

| Package | Native backing | Notes |
|---|---|---|
| `google_mlkit_text_recognition` | ML Kit TextRecognition (`GoogleMLKit/TextRecognition 6.0.0`, `MLKitTextRecognition 4.0.0` pods on iOS; ML Kit on Android) | Used by `OcrService` |
| `local_auth` | LocalAuthentication / BiometricPrompt | Requires `FlutterFragmentActivity` on Android |
| `in_app_purchase` | StoreKit (`in_app_purchase_storekit`) / Play Billing | `IapService` |
| `file_picker` | UIDocumentPicker / SAF `ACTION_GET_CONTENT` | `ImportService.pickFiles`, extensions pdf/jpg/jpeg/png/heic/heif |
| `share_plus` | UIActivityViewController / `ACTION_SEND` | `lib/shared/utils/share_pdf.dart` |
| `printing` | Platform PDF rasteriser via `Printing.raster` | `PageRasterService` (PDF page → PNG, cached under `page_raster/`) |
| `sqlite3_flutter_libs` | Bundled SQLite | drift backend |
| `path_provider`, `shared_preferences` | standard | |
| `syncfusion_flutter_*` | Pure Dart (pdfviewer uses platform rendering) | PDF build/view, signature pad |

Android extra Gradle deps (`android/app/build.gradle.kts`):
`play-services-mlkit-document-scanner:16.0.0`,
`play-services-auth-blockstore:16.4.0`.

## Custom native file inventory

| File | Lines | Role |
|---|---|---|
| `ios/Runner/AppDelegate.swift` | 23 | Plugin registration, activates privacy overlay |
| `ios/Runner/SceneDelegate.swift` | 6 | Empty `FlutterSceneDelegate` |
| `ios/Runner/DocumentScannerPlugin.swift` | 133 | VisionKit scanner |
| `ios/Runner/EntitlementPlugin.swift` | 74 | Keychain counter |
| `ios/Runner/BackupPlugin.swift` | 42 | iCloud backup exclusion |
| `ios/Runner/AiFieldEnhancerPlugin.swift` | 70 | Foundation Models stub |
| `ios/Runner/PrivacyOverlay.swift` | 94 | App-switcher blur |
| `ios/Runner/Runner-Bridging-Header.h` | — | Bridging header |
| `ios/Runner/PrivacyInfo.xcprivacy` | — | Required-reason APIs: FileTimestamp `C617.1`, UserDefaults `CA92.1`, DiskSpace `E174.1` |
| `android/.../MainActivity.kt` | 100 | Fragment activity, privacy/backup/entitlement channels |
| `android/.../DocumentScannerPlugin.kt` | 139 | ML Kit scanner |
| `android/.../AppBackupAgent.kt` | 56 | Opt-in backup agent |

(`android/...` = `android/app/src/main/kotlin/com/adakventures/scansignsend/`.)
`GeneratedPluginRegistrant.*` files are Flutter-generated, not custom.

## Technical Debt Observations

- **AI enhancer is a stub that claims availability.** iOS 26+ reports
  `isAvailable = true` while `enhance` always returns `[]`; Android has no
  handler at all. Net effect is harmless (heuristic fallback), but the Settings
  toggle `aiEnhancedDetection` currently changes nothing. The Dart doc comment
  mentions "Android without Gemini Nano" — no Gemini Nano code exists.
- **Asymmetric channel coverage**: `privacy` has no iOS handler and
  `ai_enhancer` has no Android handler; both rely on swallowed exceptions.
- **Stale comment**: `privacy_screen_service.dart` says the iOS blur is
  "handled entirely in `SceneDelegate`"; it actually lives in
  `PrivacyOverlay.swift`, activated from `AppDelegate`.
- **Misleading pubspec comment**: `google_mlkit_text_recognition` is annotated
  "wraps VisionKit on iOS" — `ios/Podfile.lock` shows it uses Google ML Kit pods.
- **Android scan staging in `cacheDir`** is not explicitly cleaned on the native
  side (relies on Dart moving files and OS cache eviction); iOS cleans legacy
  staging but not `tmp/scan_staging` itself.
- **Android scanner swallows per-page copy errors** (`catch (e: Exception) {}`),
  so a partially failed scan returns fewer pages without signalling it.
- **`scanAvailable` on Android always returns `true`**, even on devices
  without the required Play services module; failure surfaces only at `scan`.
- **Inconsistent registration styles on Android**: one proper `FlutterPlugin`
  class vs three inline handlers in `MainActivity`.
