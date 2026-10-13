# Store capture

Reproducible App Store screenshots, product-page creative and the preview
video, in all 7 languages, from the real app running on simulators.

```bash
# 1. Raw captures (≈1 min per language per device)
tool/store_capture/capture.sh <iphone-udid> en fr es pt hi ta te
tool/store_capture/capture.sh <ipad-13-udid> en fr es pt hi ta te
tool/store_capture/capture.sh --video <iphone-udid> en

# 2. Store assets
python3 tool/store_capture/frame.py          # -> ios/fastlane/screenshots/<locale>/
python3 tool/store_capture/creative.py       # -> build/store_capture/creative/ (header, search)
python3 tool/store_capture/make_preview.py   # -> build/store_capture/preview/en/
python3 scripts/appstore_metadata.py         # -> ios/fastlane/metadata/ (from store/listings)
```

Google Play (phone screenshots, 1080×1920, all 7 languages):

```bash
tool/store_capture/capture_android.sh emulator-5554 en fr es pt hi ta te
python3 tool/store_capture/frame.py          # also -> android/fastlane/metadata/android/<locale>/images/phoneScreenshots/
cd android && VALIDATE_ONLY=1 fastlane play_screenshots   # dry run, then without VALIDATE_ONLY
python3 scripts/play_listing.py && cd android && fastlane play_listing   # listing text
```

The emulator's language can't be switched from a script, so the test sets
the app's (`--dart-define=LOCALE`); the demo form goes into the app's cache
(`NEED:form`), since the emulator can't read the Mac's files. The status bar
runs in demo mode (9:41) for the capture.

UDIDs: `xcrun simctl list devices` — use an *iPhone 17 Pro Max* (1320×2868,
the 6.9" slot) and an *iPad Pro 13-inch* (2064×2752).

## How it works

- `integration_test/store_capture_test.dart` drives the real flow — import →
  detect → fill → sign → flatten → preview — and prints `CAPTURE:<name>`;
  `capture.sh` answers each with `simctl io screenshot` (clean 9:41 status bar
  via `simctl status_bar`). In `--video` mode it records between `REC:start`
  and `REC:stop` and logs `BEAT:` times for the captions.
- `integration_test` is not in pubspec.yaml — Flutter would embed its
  framework in release IPAs. `capture.sh` adds it for the run and restores
  `pubspec.yaml`/`pubspec.lock` afterwards (so commit before capturing).
- ML Kit has no arm64 simulator slice, so for the run `capture.sh` writes a
  `pubspec_overrides.yaml` pointing at `mlkit_stub/`, and lets the Runner
  target build for the simulator. A trap restores the iOS project on exit;
  if a run is killed, run `git checkout ios/Runner.xcodeproj/project.pbxproj`,
  delete `pubspec_overrides.yaml` and `pod install`.
- The demo forms (`make_forms.py`) are born-digital PDFs with a text layer,
  so detection reads labels from the PDF, not OCR — the stub costs nothing.
  fr/es/pt get a form in their language; hi/ta/te use the English form, as
  most forms in India are.
- Everything on screen is fictional: the forms and the applicants.
- Captions are rendered by headless Chrome, which shapes Devanagari, Tamil and
  Telugu correctly. Have a native speaker read caption changes in those three.
