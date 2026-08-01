# Store Release — Scan Sign Send (ADAK Ventures)

This app is prepped for App Store + Google Play. Full details live in `store/`:

- **`store/SUBMISSION_CHECKLIST.md`** — the master checklist (do this in order)
- **`store/STORE_LISTING.md`** — listing copy, keywords, IAP metadata
- **`store/PRIVACY_POLICY.md`** — host this at a public URL (Play requires it)

## Quick reference

**Bundle / package IDs**
- iOS: `com.scansignsend.scanSignSend` (team `T995T8G6Z2`)
- Android: `com.scansignsend.scan_sign_send`

**In-app purchase** — non-consumable `com.scansignsend.fullaccess`, **$14.99**

**Icons** — generated from the ADAK logo by `branding/make_icon.py`, then
`dart run flutter_launcher_icons`. To regenerate after changing the art:
```bash
python3 branding/make_icon.py
dart run flutter_launcher_icons
```

## Android release signing
Release builds read `android/key.properties` (git-ignored). If it's absent,
the build falls back to debug signing so local `--release` runs still work.
Copy `android/key.properties.example` → `android/key.properties` and fill in
your upload keystore. See the checklist for `keytool` steps.

## Build commands
```bash
flutter build ipa --release        # iOS  → upload via Xcode/Transporter
flutter build appbundle --release  # Android → build/app/outputs/bundle/release/app-release.aab
```
