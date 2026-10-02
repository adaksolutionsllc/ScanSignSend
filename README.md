# Scan Sign Send

Offline document scanner + e-signature app for iOS and Android. Scan documents, detect and fill form fields, sign, flatten to PDF, and share — all on-device, no cloud, no account, no subscription.

One-time purchase: $9.99 base (per-country pricing in `store/PRICING.md`).

---

## Prerequisites

- Flutter 3.x (stable channel)
- Xcode 15+ (iOS builds)
- Android Studio / Android SDK (Android builds)
- CocoaPods (iOS dependency management)

---

## Commands

### Development

```bash
# List available devices and simulators
flutter devices

# Run on connected device or simulator
flutter run

# Run on a specific device
flutter run -d <device-id>

# Check Flutter environment and toolchain health
flutter doctor
```

### Code Quality

```bash
# Lint check (should always return 0 issues)
flutter analyze --no-pub

# Run tests
flutter test
```

### Dependencies

```bash
# Install / sync dependencies
flutter pub get

# Check for available updates
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade

# Clean build cache and reinstall dependencies
flutter clean && flutter pub get
```

### Codegen

Run after any change to `lib/core/db/app_database.dart` or any file with `@riverpod` annotations:

```bash
# One-shot generation
dart run build_runner build --delete-conflicting-outputs

# Watch mode (re-runs on save)
dart run build_runner watch --delete-conflicting-outputs
```

### iOS

```bash
# Re-install CocoaPods after pubspec.yaml changes
cd ios && pod install

# Open project in Xcode
open ios/Runner.xcworkspace

# Build release IPA
flutter build ios --release
```

### Android

```bash
# Build release APK
flutter build apk --release

# Build release AAB (required for Play Store)
flutter build appbundle --release

# Inspect Gradle dependency tree
cd android && ./gradlew dependencies
```
