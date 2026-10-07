# Release 1.0.1 — store listing enhancements

Version `1.0.1+9` (pubspec.yaml). Prepared 2026-10-07, to ship the week of
2026-10-12. **Do not start until 1.0 is released** — App Store Connect won't
open a new version while 1.0 is still waiting for developer release.

## What's in it
- **App:** the profile-row race fix (duplicate profile rows at first launch
  silently broke detection, autofill and the free-tier check).
- **Listing:** name/subtitle/description/keywords/What's New in en-US, fr-FR,
  es-MX, es-ES, pt-BR, hi, ta-IN, te-IN (from `store/listings/`).
- **Screenshots:** 5 per language, iPhone 6.9" + iPad 13" — replaces the live
  raw captures (one of which shows a real-looking affidavit).
- **App preview:** English, 886×1920, 29.5 s.
- **Header + search-result creative:** every language.

Note the English name changes from "Scan Sign Send" to
"Scan Sign Send: PDF Signer" (subtitle "Scan, sign & send. Offline.").
Revert `store/listings/en.md` first if you'd rather keep the current name.

## Before release day
- [ ] A native speaker reads the hi / ta / te captions
      (`tool/store_capture/frame.py`, `creative.py`) and listings
      (`store/listings/hi.md`, `ta.md`, `te.md`). After any edit:
      re-run `frame.py` / `creative.py` / `scripts/appstore_metadata.py`.
- [ ] Look through `~/Desktop/ScanSignSend-AppStore-1.0.1/`.

## Release day
1. [ ] **Binary → TestFlight:** `scripts/release.sh ios`
       (checks, builds 1.0.1+9, uploads). Smoke-test the TestFlight build:
       import a PDF → detect → fill → sign → share.
2. [ ] **Listing:** `scripts/release.sh listing` — creates version 1.0.1 in
       App Store Connect and uploads metadata + 80 screenshots for all 8
       locales. Does **not** submit.
3. [ ] **App preview** (App Store Connect → 1.0.1 → English (U.S.) →
       iPhone 6.9" Display → App Previews):
       `build/store_capture/preview/en/preview_886x1920.mp4`
       (copy on the Desktop). Processing can take up to 24 h.
4. [ ] **Header + search results** (Distribution → Header and Search Results),
       per language: `build/store_capture/creative/<locale>/header_3840x1646.png`
       and `search_1920x1280.png`. These can also be submitted on their own,
       any time after 1.0 is live.
5. [ ] On the 1.0.1 page: select build **9**, check What's New in each
       language, then **Add for Review → Submit**. Choose manual release if you
       want to pick the day.

## Android (optional, same version)
`scripts/release.sh android` uploads 1.0.1+9 to Play internal testing;
promote to production in Play Console. Play screenshots are unchanged
(`branding/store_screenshots/android/`).

## Regenerating assets
See `tool/store_capture/README.md`. Raw captures and framed output are
gitignored; everything is reproducible from the repo.
