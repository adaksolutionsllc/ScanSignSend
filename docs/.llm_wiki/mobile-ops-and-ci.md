# Mobile Ops and CI

Back to [[Index]] · Related: [[Native Bridges and Plugins]] · [[UI and Design System]]

This is a Flutter app — no Node, Metro, or npm toolchain is involved.

## Toolchain versions

| Tool | Version | Source |
|---|---|---|
| Flutter | **3.41.9** stable | `FLUTTER_VERSION` in `.github/workflows/ci.yml`, `release.yml` |
| Dart SDK | `^3.11.5` | `pubspec.yaml` |
| Java (Android build) | 17 (Temurin in CI) | `compileOptions` / `jvmTarget` in `android/app/build.gradle.kts` |
| Android Gradle Plugin | 8.11.1 | `android/settings.gradle.kts` |
| Kotlin | 2.2.20 | `android/settings.gradle.kts` |
| Android compile/min/target SDK | `flutter.compileSdkVersion` / `flutter.minSdkVersion` / `flutter.targetSdkVersion` | `android/app/build.gradle.kts` |
| iOS deployment target | 15.0 | `ios/Podfile`, `project.pbxproj` |
| Xcode | 15+ per `README.md`; CI uses `macos-14` default | |
| Ruby (CI) | 3.2 (`ruby/setup-ruby`), `gem install fastlane` (no Gemfile) | `release.yml` |
| CocoaPods | any; `pod install --repo-update` in CI | `release.yml` |
| Python 3 | for `store/listings/check_limits.py`, `branding/*.py`, icon preflight | |

## Local setup

```bash
flutter pub get                                   # also runs gen-l10n (generate: true)
dart run build_runner build --delete-conflicting-outputs   # after editing app_database.dart
flutter gen-l10n                                  # after editing any .arb
cd ios && pod install && cd ..                    # after plugin changes
flutter run -d <device>
```

Android release signing locally: copy `android/key.properties.example` →
`android/key.properties` (git-ignored). Without it, `--release` builds are
**debug-signed**.

> Project rule (memory): never `flutter install` onto the maintainer's phone — it
> uninstalls first and wipes data. Use `flutter run --release` to upgrade in place.

## Quality gates

```bash
flutter analyze          # flutter_lints ^6 (analysis_options.yaml, no custom rules)
flutter test             # 15 files in test/
python3 store/listings/check_limits.py
dart format .            # CI reports but does not enforce
```

## Build commands

| Target | Command |
|---|---|
| Android debug APK | `flutter build apk --debug` |
| Android release AAB | `flutter build appbundle --release [--build-number=N]` → `build/app/outputs/bundle/release/app-release.aab` |
| iOS unsigned (CI) | `flutter build ios --release --no-codesign [--build-number=N]` |
| iOS IPA (local, automatic signing) | `flutter build ipa --release` → `build/ios/ipa/*.ipa` |
| Launcher icons | `dart run flutter_launcher_icons` |
| Splash | `dart run flutter_native_splash:create` |

## Fastlane lanes

| Platform | Lane | Does | File |
|---|---|---|---|
| iOS | `beta` | CI: temp keychain, import p12 + profile from base64 env, `build_app` (manual signing, app-store export, `ScanSignSend.ipa`), `upload_to_testflight` (internal) | `ios/fastlane/Fastfile` |
| iOS | `local_testflight` | Upload a locally built IPA (`IPA_PATH`) with ASC key file | same |
| Android | `internal` | Upload AAB to Play **internal** track as `draft` | `android/fastlane/Fastfile` |
| Android | `promote_to_production` | Promote internal → production (manual use) | same |

## Release paths

1. **Local (current primary path)** — `scripts/release.sh ios|android|all|ios-upload`.
   Reads credentials from `~/.config/scansignsend/release.env`
   (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, `GOOGLE_PLAY_JSON_KEY`).
   Requires a clean git tree, runs analyze/test/listing-limits, verifies iOS
   app icons (1024×1024, no alpha), builds, uploads with 3 retries (treats
   "UPLOAD SUCCEEDED" or "previously uploaded version" as success). Build
   number comes from `pubspec.yaml` — bump `+N` first.
2. **CI** — push a `v*` tag → `.github/workflows/release.yml`: Android job
   (decode keystore → `key.properties` → AAB → `fastlane internal`) and iOS job
   (`pod install` → unsigned build → `fastlane beta`). Build number =
   `github.run_number`. Secrets documented in `.github/DEPLOYMENT.md`.
3. Production submission is manual in both consoles
   (`store/SUBMISSION_CHECKLIST.md`).

## CI workflow (`.github/workflows/ci.yml`)

Push/PR to `main`: `analyze-and-test` (ubuntu: pub get, non-blocking format,
analyze, `flutter test --coverage`, listing limits, upload `lcov.info`) →
parallel `build-android` (debug APK) and `build-ios` (macos-14, debug,
no codesign). `concurrency` cancels superseded runs.

## Permission map

### iOS — `ios/Runner/Info.plist` (localized in `ios/Runner/*.lproj/InfoPlist.strings`)

| Key | Why (from the shipped string / code) |
|---|---|
| `NSCameraUsageDescription` | VisionKit document camera (`DocumentScannerPlugin.swift`) |
| `NSPhotoLibraryUsageDescription` | Import existing photos/images as pages. Required even though imports use `FileType.custom`: `file_picker` links the Photos framework, and App Store processing rejects binaries that reference it without this key |
| `NSFaceIDUsageDescription` | Biometric app lock (`local_auth`, `BiometricService`) |

Other relevant keys: `ITSAppUsesNonExemptEncryption = false`,
`UIApplicationSceneManifest` → `SceneDelegate`. Privacy manifest
`ios/Runner/PrivacyInfo.xcprivacy` declares FileTimestamp (`C617.1`),
UserDefaults (`CA92.1`), DiskSpace (`E174.1`). Keychain use (entitlement
counter) needs no Info.plist key.

### Android — `android/app/src/main/AndroidManifest.xml`

| Permission | Status | Why |
|---|---|---|
| `android.permission.CAMERA` | declared | Camera capture (`uses-feature camera required=false`) |
| `android.permission.USE_BIOMETRIC` | declared | `local_auth` app lock |
| `com.android.vending.BILLING` | declared | Play Billing (`in_app_purchase`) |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` | **removed** (`tools:node="remove"`) | Imports use SAF via `file_picker`; scanner writes to app cache; avoids Play's Photo & Video declaration |
| `android.permission.INTERNET` | debug & profile manifests only | Flutter tooling (hot reload / DevTools) |

Application attributes: `allowBackup="true"`, `backupAgent=".AppBackupAgent"`,
`fullBackupOnly="true"`, `fullBackupContent="@xml/backup_rules"`,
`dataExtractionRules="@xml/data_extraction_rules"`,
`enableOnBackInvokedCallback="true"`. `<queries>` for `PROCESS_TEXT`.

## Technical Debt Observations

- **No flavors / environments**: a single configuration; there is no staging
  build or separate bundle ID for testing.
- **Two release pipelines** (local `scripts/release.sh` and tag-triggered CI)
  use different build-number sources (pubspec `+N` vs `run_number`); mixing
  them can produce a lower build number than one already uploaded.
- **Stale comments**: `ci.yml` says the signed IPA is produced "via fastlane
  match", but the Fastfile imports a p12 directly; `ios/Podfile` comment says
  deployment target 13.0 while both values are 15.0.
- **Fastlane is not pinned** (no `Gemfile`/`Gemfile.lock`); CI installs the
  latest gem each run.
- **Bundle ID casing differs** between platforms (`com.adakVentures.scanSignSend`
  vs `com.adakventures.scansignsend`) — harmless but easy to mistype in tooling.
