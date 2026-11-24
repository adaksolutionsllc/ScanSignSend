# UX review context — Scan Sign Send

Read by the shared `ux-reviewer` agent (claude-config/agents/ux-reviewer.md).

## App

- Purpose: offline scanner and e-signature app. Scan or import a form, detect
  its fields, fill, sign, flatten to PDF, send.
- Business: one-time purchase. Free tier: 2 documents of up to 2 pages.
  No server, no account, no subscription, no network.
- Audience: people who must sign and return a form today. Mixed tech comfort.
  Many use the app once a month, so they forget it between uses.
- Happy path: open → scan/import → fields found → fill + sign → send.
  Target: under 2 minutes for a 2-page form.
- Platforms: iOS and Android (Flutter).
- Languages: en, fr, es, pt (Brazil), hi, ta, te. Longest: ta and te.
- Known pain points (tester, build 24): a time-left estimate far too high;
  decorative progress lines that confused users ("Lining up the margins…");
  a text file saved next to the PDF from "Save to Files". Check these are
  gone.

## Devices

- iOS simulator: `0B6370E0-C54F-4ACF-9CB6-9C766F8EEAFE` (SSS Verify iPhone).
- Android emulator: `emulator-5554` (Pixel 9 Pro XL, API 36).
- Never touch: simulator `088FE797-D539-42E1-99D9-2F6FEA6F3725`, and any
  physical phone.
- Android: before a run, disable the launcher
  (`adb -s emulator-5554 shell pm disable-user --user 0 com.google.android.apps.nexuslauncher`).
  After the run, enable it again (`pm enable`), even if the run failed.

## Capture

```
tool/verify/device_check.sh 0B6370E0-C54F-4ACF-9CB6-9C766F8EEAFE --full
tool/verify/device_check.sh emulator-5554 --full
```

- Screenshots: `build/verify/<device>/NN_<name>.png` (about 30 screens,
  import → detect → fill → sign → flatten → send → viewer, plus Library,
  Settings, the import job screen, the paywall-free flow).
- A run takes 5–10 minutes. One device at a time.
- `pubspec.yaml` and `pubspec.lock` must be clean: the run restores them.
- Also check for a running `device_check.sh` before you start.
- Package / bundle ID: `com.adakventures.scansignsend` (Android),
  `com.adakVentures.scanSignSend` (iOS).

## Product rules

- No server, no account, no sign-in, no cloud sync, no analytics, no network.
- No watermark and no "Signed with…" text on output or in shared content.
- No overclaiming in any language: never "legally binding", "verified
  identity", "notarized", "compliant", "tamper-proof". See
  `docs/two-party-signing.md`.
- Every copy change must exist in all 7 languages.
- The free-tier limits and the paywall stay. How they are told may change.
- Do not read `~/.config/scansignsend/`.

## Decisions

The "Decisions" sections of `docs/plan-*.md`.

## Not covered

The camera scanner (VisionKit / ML Kit scanner), Face ID / fingerprint, the
real share sheet targets, purchases.
