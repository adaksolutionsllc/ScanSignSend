# Store Release — Scan Sign Send (ADAK Ventures)

This app is prepped for App Store + Google Play. Full details live in `store/`:

- **`store/SUBMISSION_CHECKLIST.md`** — the master checklist (do this in order)
- **`store/STORE_LISTING.md`** — listing copy, keywords, IAP metadata
- **`store/PRIVACY_POLICY.md`** — host this at a public URL (Play requires it)

## Quick reference

**Bundle / package IDs**
- iOS: `com.adakVentures.scanSignSend` (team `T995T8G6Z2`)
- Android: `com.adakventures.scansignsend`

**In-app purchase** — non-consumable `com.adakVentures.fullaccess`, **$14.99**

**Brand & icons** — the launcher icon is rendered from scratch by
`branding/make_icon_3d.py`: a signed page rising out of a lit slot in a dark
shell, shaded with height-field normals plus Lambert/Blinn-Phong rather than
pasted gradients. Regenerate after any change:
```bash
python3 branding/make_icon_3d.py --variant gold --concept scanner --install
dart run flutter_launcher_icons
```
`--variant` picks the palette (gold / aurora / teal), `--concept` the mark
(scanner / printer / sheet). Drop `--install` to render comparisons only.
The Android adaptive foreground is cropped to the mark's own bounds and
pre-compensated for the extra 16% inset `ic_launcher.xml` applies — do not
"simplify" that, or the mark shrinks inside the launcher mask.

Older scripts `make_brand.py` and `make_icon.py` are superseded.

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
