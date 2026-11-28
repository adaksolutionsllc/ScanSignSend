# QA context — Scan Sign Send

Read by the shared `qa-reviewer` agent (claude-config/agents/qa-reviewer.md).

## App and risk areas

- Offline scanner and e-signature app (Flutter, iOS + Android). Scan or import
  → detect fields → fill → sign → flatten to PDF → send. No server, no
  account, no network.
- Main flows: import a PDF or photo; field detection (AcroForm, OCR,
  geometry); fill mode; signature capture; flatten ("press"); Save as
  Fillable; send (share sheet); Library (categories, search, select);
  templates; PreFill from the profile; import jobs (check edges, straighten,
  pause, resume, checkpoints).
- Fragile areas:
  - Stored file paths. iOS moves the app folder on update;
    `PathResolver` rebases paths. 1.0.0 stored absolute page paths.
  - Database migrations (`lib/core/db/app_database.dart`, `onUpgrade`).
  - The free tier: 2 documents of up to 2 pages, counted once per document
    (`FreeUsageService`, `Documents.countedFree`, Keychain / Block Store
    copy).
  - Indic text shaping in PDFs (hi, ta, te).
  - Field geometry: fields are normalized to the page content.
  - Import job checkpoints (`Documents/jobs/<docId>.json`).
- Base branch: the release branch the PR targets (else `main`).

## Devices

- iOS simulator: `0B6370E0-C54F-4ACF-9CB6-9C766F8EEAFE` (SSS Verify iPhone).
- iOS simulator, small phone with no Dynamic Island:
  `8AAF3DFE-35EA-4461-AE4C-8A3FE2292EB9` (SSS Verify iPhone 16e). Use it as
  well as the one above for any screen-layout change. The other is an
  iPhone 17 Pro Max: system UI on phones with no Dynamic Island (iOS 26's
  background-task banner) never showed there, and a tester's iPhone hit it
  (1.3.2 build 26). The simulator does not show that banner either; check it
  on a real phone with no Dynamic Island.
- Android emulator: `emulator-5554` (Pixel 9 Pro XL, API 36).
- Never touch: simulator `088FE797-D539-42E1-99D9-2F6FEA6F3725`, and any
  physical phone.
- Android: before a device run, disable the launcher
  (`adb -s emulator-5554 shell pm disable-user --user 0 com.google.android.apps.nexuslauncher`).
  After it, enable it again (`pm enable`), even if the run failed.
- If the emulator is very slow (6-page check over 10 s instead of about
  3 s), it is swapping: cold-restart it
  (`emulator -avd Pixel_9_Pro_XL -no-snapshot-load -no-audio -no-boot-anim`)
  and run again. Say so in the report.

## Commands

Run them in the worktree, in this order:

| Check | Command | Time |
|---|---|---|
| Static | `flutter analyze` | 10 s |
| Format | `dart format --output=none --set-exit-if-changed <changed .dart files>` (named files only, never a folder) | 1 s |
| Unit + widget | `flutter test` | 30 s |
| Languages | included in `flutter test` (`test/l10n_completeness_test.dart`): every key in all 7 `.arb` files, no translation equal to English | — |
| Regression | `tool/verify/device_check.sh <device> --full` on each device | 5–10 min each |
| Upgrade | `tool/verify/device_check.sh <device> --upgrade` on each device | 2–4 min each |
| OCR gate (only if OCR or detection changed) | `tool/verify/device_check.sh <device> --ocr-gate` | 5 min |

- The device runs need `pubspec.yaml` and `pubspec.lock` clean (the run edits
  and restores them). Never edit files during a device run.
- `flutter pub get` first in a new worktree. iOS: also `cd ios && pod install`.

## Supported versions

- Oldest supported: **1.0.0** (`v1.0.0-build8`). Store users can jump from any
  version to the newest in one update.
- Versions checked: `tool/verify/upgrade/versions.txt` (one per database
  schema, plus the last live version).
- Fixtures: `test/fixtures/upgrade/<tag>/<ios|android>/`, made once per version
  by `tool/verify/upgrade_seed.sh <device> <tag>` with that version's own code.
  If a fixture is missing, make it (it does not change the app).
- What must survive an update: every document (title, status, pages, field
  values, ticks, signatures), page images, flattened and fillable PDFs,
  saved signatures, templates, the profile (the 1.2.0 name split), settings
  (first-run pages done), the purchase flag. From 1.3.2: import job
  checkpoints.
- The upgrade check is required when a change touches: `lib/core/db/`,
  repositories, file paths or folders, `PathResolver`, settings keys
  (`SharedPreferences`), the job checkpoint format, purchase IDs, or
  onboarding / "What's new".
- A new data type (table, file, setting) needs the seed test
  (`tool/verify/upgrade/upgrade_seed_test.dart`) and the verify test
  (`integration_test/upgrade_verify_test.dart`) extended. Say so if missing.

## Product rules

- No server, no account, no sign-in, no analytics, no network calls.
- No watermark and no "Signed with…" text on output or in shared content.
- No overclaiming in any language: never "legally binding", "verified
  identity", "notarized", "compliant", "tamper-proof".
- Every user-facing string in all 7 languages (en, fr, es, pt-BR, hi, ta,
  te). Services without a BuildContext hold no user-facing text.
- Never `flutter install` on a phone (it wipes the user's documents).
- Do not read `~/.config/scansignsend/`.

## Not covered

The camera scanner (VisionKit / ML Kit scanner), Face ID / fingerprint,
real share targets, real purchases and restore, iOS 26 background
continuation with the screen locked, a real kill on a phone, Keychain /
Block Store across a real reinstall.
