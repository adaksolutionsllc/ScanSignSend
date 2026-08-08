# CI/CD & Store Deployment

Two workflows drive builds and releases:

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | every push / PR to `main` | format check (non-blocking), `flutter analyze`, `flutter test`, debug builds for Android + iOS |
| `release.yml` | pushing a `v*` tag (e.g. `v1.0.0`) | signed AAB → **Google Play internal**, signed IPA → **TestFlight** |

Store *submission for review* stays a manual click in App Store Connect / Play Console — CI only gets the build onto the testing track.

## Cutting a release

```bash
# bump the marketing version in pubspec.yaml if it changed, e.g. 1.0.1
# (the build number is set automatically — see below)
git tag v1.0.1
git push origin v1.0.1
```

The tag push kicks off `release.yml`. You can also run it manually from the
Actions tab (`workflow_dispatch`).

**Build number is automatic.** Both jobs build with
`--build-number=${{ github.run_number }}`, so every release run gets a unique,
monotonically increasing build number (iOS `CFBundleVersion` / Android
`versionCode`) without editing `pubspec.yaml`. This satisfies TestFlight and
Play, which reject re-uploads that reuse a build number. You only need to bump
the *marketing* version (`1.0.1`) in `pubspec.yaml` when it actually changes.

**Preflight.** Each job first checks that its required secrets are present and
fails fast with a clear `::error::` listing any that are missing (pointing back
to this file), instead of failing deep inside the signing/upload step.

---

## Required GitHub Secrets

Add these under **Settings → Secrets and variables → Actions**.

### Android → Google Play

| Secret | How to get it |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/adak-upload-key.jks \| pbcopy` — your upload keystore, base64-encoded |
| `ANDROID_STORE_PASSWORD` | keystore password (from `keytool -genkey`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | full JSON of a Play Console service account with "Release manager" permission. See below. |

**Play service account:** Play Console → Setup → API access → create/link a
Google Cloud service account → grant it release permissions → download the JSON
key. Paste the *entire file contents* as the secret value.

The app must already exist in the Play Console with **one AAB uploaded manually**
to any track before the API can push to it (Google's requirement for the first
upload).

### iOS → TestFlight

| Secret | How to get it |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution certificate exported from Keychain as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `IOS_DIST_CERT_PASSWORD` | password you set when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store provisioning profile for `com.adakVentures.scanSignSend`, `base64 -i profile.mobileprovision \| pbcopy` |
| `IOS_PROVISIONING_PROFILE_NAME` | the profile's exact name (e.g. `ScanSignSend App Store`) |
| `IOS_KEYCHAIN_PASSWORD` | any throwaway string — used for the ephemeral CI keychain |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_KEY_P8_BASE64` | the API key `.p8` file, `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

**App Store Connect API key:** App Store Connect → Users and Access → Integrations
→ App Store Connect API → generate a key with **App Manager** access. Download the
`.p8` (only downloadable once) and note the Key ID + Issuer ID.

**Certificate + profile:** created in the Apple Developer portal (or let Xcode
manage signing once, then export the resulting cert/profile). The bundle id is
`com.adakVentures.scanSignSend`, team `T995T8G6Z2`.

---

## Local release builds (no CI)

```bash
# Android — needs android/key.properties (see android/key.properties.example)
flutter build appbundle --release

# iOS — open ios/Runner.xcworkspace, or:
flutter build ipa --release
```

## Notes

- Flutter version is pinned to **3.41.9** in both workflows — bump `FLUTTER_VERSION`
  when you upgrade locally so CI matches.
- `dart format` is intentionally non-blocking in CI. Run `dart format .` before
  committing if you want tidy diffs.
- Signing secrets are git-ignored (`android/key.properties`, `*.jks`, `*.p8`,
  `*.p12`, `*.mobileprovision`, service-account JSON). Never commit them.
