# Store Submission Checklist — Scan Sign Send (ADAK Ventures)

Status legend: ✅ done in repo · ⬜ you must do it (account/console/hardware)

---

## 0. What's already done in this repo
- ✅ App icons for iOS + Android (adaptive) generated from the ADAK logo — `branding/`
- ✅ iOS `PrivacyInfo.xcprivacy` privacy manifest (added to Xcode build resources)
- ✅ iOS permission strings (camera, photos, Face ID) + `ITSAppUsesNonExemptEncryption=false`
- ✅ Android release-signing scaffold (`build.gradle.kts` reads `key.properties`)
- ✅ Android R8/ProGuard rules + `isMinifyEnabled`/`isShrinkResources`
- ✅ Android permissions: camera, `USE_BIOMETRIC`, Play `BILLING` — **no storage/media
  permission is declared**, so the Play "Photo and Video Permissions" declaration
  does not apply (imports go through the Storage Access Framework)
- ✅ Android Auto Backup + device-transfer disabled (`allowBackup=false`,
  `data_extraction_rules.xml`) so scans never reach Google Drive
- ✅ App lock re-arms on backgrounding; iOS app-switcher blur; Android
  `FLAG_SECURE` when the lock is on
- ✅ Deleting a document deletes its files on disk, not just its DB rows
- ✅ iOS deployment target 15.0 (Xcode 26+ refuses to build below 15.0)
- ✅ Localized into 7 languages — EN, FR, ES, PT, HI, TA, TE (`lib/l10n/*.arb`,
  `CFBundleLocalizations` in Info.plist, guarded by
  `test/l10n_completeness_test.dart`)
- ✅ Dates, the biometric prompt and the PDF signing certificate all follow the
  active locale
- ✅ Syncfusion on the 28.x line — 27.x caps `intl` below what
  `flutter_localizations` pins, so localization is unresolvable there
- ✅ `MainActivity` → `FlutterFragmentActivity` (required for biometric lock)
- ✅ ML Kit document scanner bumped off `-beta1` to stable `16.0.0`
- ✅ IAP reads the live localized store price — no price is hardcoded in the app,
  so repricing is a console-only change (product `com.adakventures.fullaccess`)
- ✅ IAP product ID is all-lowercase — Play Console rejects uppercase in product
  IDs, so the old `com.adakVentures.fullaccess` could never have been created there
- ✅ iOS permission prompts (camera, photos, Face ID) localized in all 7 languages
  via `ios/Runner/<locale>.lproj/InfoPlist.strings`, guarded by the l10n test
- ✅ Branded native splash on both platforms (`flutter_native_splash`, config in
  `pubspec.yaml`; Android 12+ uses the padded `branding/splash_android12.png`)
- ✅ Release builds verified 2026-09-24: signed AAB (upload key, targetSdk 36,
  all native libs 16 KB page-aligned) and App Store IPA (automatic signing,
  team `T995T8G6Z2`) both build clean
- ✅ Version `1.0.0+4`

---

## 1. Accounts & one-time setup ⬜
- ⬜ Apple Developer Program membership ($99/yr) — team `T995T8G6Z2` is already set in the project
- ⬜ Google Play Developer account ($25 one-time)
- ⬜ Register App IDs / bundle IDs:
      - iOS: `com.adakVentures.scanSignSend`
      - Android: `com.adakventures.scansignsend`
- ⬜ Enable **In-App Purchase** capability on the iOS App ID (Xcode → Signing & Capabilities → + In-App Purchase). No entitlement file is needed for StoreKit.

## 2. Android upload keystore ⬜ (irreversible — back it up!)
```bash
keytool -genkey -v -keystore ~/adak-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
# edit android/key.properties with your passwords + absolute storeFile path
```
- ⬜ Store the `.jks` + passwords in a password manager. If you lose them you can never update the app (unless enrolled in Play App Signing, which is recommended — opt in during first upload).

## 3. In-app purchase product ⬜
Create the **same non-consumable** in BOTH consoles:
- Product ID: `com.adakventures.fullaccess`
- Type: Non-consumable (iOS) / One-time product (Android)
- Price tier: **$9.99 USD** base, with per-country overrides (see PRICING.md §3)
- Display name: `Full Access`
- ⬜ App Store: fill IAP metadata + screenshot, submit IAP **with** the first app version
- ⬜ Play: activate the product; upload at least one build to a track first so billing works

## 4. App Privacy / Data Safety declarations ⬜
Both answers are the same: **no data collected, no tracking.**

**App Store — App Privacy:**
- Data used to track you: **None**
- Data linked to you: **None**
- Data not linked to you: **None**
- → Select "Data Not Collected."

**Google Play — Data Safety:**
- Does your app collect or share user data? **No**
- Is all data encrypted in transit? N/A (no data leaves the device)
- Data deletion: users can delete all data by uninstalling.

## 4b. Pricing ⬜
See **`store/PRICING.md`** for the full rationale. Summary:
- ⬜ **$9.99** in tier-1 markets. Revisit $14.99 once there are reviews — see PRICING.md §2
- ⬜ **Override auto-conversion** for India (₹399), Brazil (R$19.90), Mexico,
  SE Asia, Turkey, Eastern Europe and LatAm. Default conversion would price the
  app at ~₹850 in India, which is a decision not to sell there — and the app
  now ships in Hindi, Tamil and Telugu specifically to reach those users.
- ⬜ No subscription. It would trade away the only thing the incumbents can't copy.

---

## 5. Store listing content ⬜
- ⬜ Copy fields from `STORE_LISTING.md`
- ⬜ Host `PRIVACY_POLICY.md` at a public URL; add it to both consoles (Play **requires** a privacy policy URL)
- ⬜ Support URL / email live

## 5b. Localized store listings ✅ written / ⬜ entered
Copy for all 7 languages is written and length-checked in **`store/listings/`**
(one file per locale). Still has to be pasted into the consoles:
- ⬜ App Store Connect → App Information → Localizations (name, subtitle), then
  the version page → Localizations (promo text, description, keywords, What's New)
- ⬜ Play Console → Main store listing → language selector → add fr, es, pt, hi, ta, te
- ⬜ Localized IAP display name + description per locale (45-char description limit)
- ⬜ Screenshots per language — the only remaining per-locale asset
- ✅ Product name "Scan Sign Send" kept untranslated everywhere (it's the brand
  and the primary search term)
- ✅ Keywords are locale-native search terms, not translations of the English
  list — including Latin-script spellings Indian users actually type
- ✅ `python3 store/listings/check_limits.py` passes; CI runs it on every push

---

## 6. Screenshots & graphics ⬜
Capture on a real device or simulator (status bar clean; use the built-in demo doc).
- **iOS (required sizes):**
      - 6.9" iPhone (1320×2868 or 1290×2796) — **required**
      - 6.5" iPhone (1242×2688) — recommended
      - 13" iPad (2048×2732) — required only if you ship iPad (you support iPad orientation, so provide these or disable iPad)
- **Android:**
      - Phone screenshots: min 2, up to 8 (1080×1920 or similar 16:9/9:16)
      - Feature graphic: **1024×500** (required)
      - App icon: 512×512 (use `branding/icon_master.png` resized)
- Suggested 5 shots: (1) Library grid, (2) Scanning, (3) Field detection with draggable fields, (4) Signature pad, (5) Finished/shared PDF.

## 7. Build & upload ⬜
```bash
# from repo root
flutter clean && flutter pub get
dart run build_runner build --delete-conflicting-outputs

# iOS — archive in Xcode (Product > Archive) or:
flutter build ipa --release
#   then upload the .ipa via Transporter or Xcode Organizer

# Android — App Bundle for Play:
flutter build appbundle --release
#   output: build/app/outputs/bundle/release/app-release.aab
```
- ⬜ iOS: run through **TestFlight** internal testing first (validates IAP sandbox)
- ⬜ Android: upload to **Internal testing** track first
- ⬜ Verify the one-time purchase completes and unlocks Full Access in sandbox/test

## 8. Pre-submit smoke test (real device) ⬜
- ⬜ Full cycle: scan → detect fields → drag a field → fill → sign → press → share
- ⬜ Import a PDF and an image
- ⬜ Enable Face ID / fingerprint lock, background & relaunch, confirm unlock works and cancel doesn't brick
- ⬜ Buy Full Access (sandbox) and confirm paywall disappears + Restore works
- ⬜ Confirm the app icon shows the ADAK triangle on the home screen

## 9. App Review notes ⬜
Add to the review-notes field:
> This app is fully offline. To test: tap New Scan (or Import), fill a field, add a signature, then Press & Send. Full Access is a one-time non-consumable unlock ($9.99) that removes the 3-document free-trial limit.

---

## Known non-blocking follow-ups (optional polish)
- No sweep exists for files orphaned by builds released *before* the delete-cleanup
  fix. Not a shipping blocker (the app is pre-launch), but a one-shot janitor at
  startup would reclaim them if any test installs are ever upgraded in place.
- `google_mlkit_text_recognition` has no arm64 simulator slice, so the app can
  only be run on a physical device or an Intel simulator. Device builds are
  unaffected.
- IAP entitlement is trusted from the local `purchaseStream` with no receipt
  validation. Correct for a no-server app, but it means a jailbroken/rooted
  device can unlock Full Access. Accepted trade-off — revisit only if piracy
  shows up in the numbers.
