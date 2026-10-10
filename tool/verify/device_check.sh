#!/usr/bin/env bash
# On-device check with screenshots, on an iOS simulator or Android emulator.
#
#   tool/verify/device_check.sh <simulator-udid | emulator-NNNN> [--full]
#
# Runs integration_test/device_check_test.dart (library, settings, send,
# viewer, rating sheet, store listing) and saves a screenshot at each
# CAPTURE: marker to build/verify/<device>/NN_<name>.png. --full also runs the
# whole store flow (import → detect → fill → sign → flatten → send → preview)
# from integration_test/store_capture_test.dart; on iOS that's capture.sh.
#
# Refuses physical devices: an integration run reinstalls the app, which
# wipes its documents.
set -euo pipefail
cd "$(dirname "$0")/../.."

DEV="${1:?usage: device_check.sh <simulator-udid|emulator-NNNN> [--full]}"
FULL="${2:-}"

if [[ $DEV == emulator-* ]]; then
  PLATFORM=android
  adb -s "$DEV" get-state >/dev/null
  NAME="android_$(adb -s "$DEV" shell getprop ro.product.model | tr -d '\r' | tr ' ' '_')"
elif xcrun simctl list devices | grep -q "($DEV)"; then
  PLATFORM=ios
  NAME="ios_$(xcrun simctl list devices | grep "($DEV)" | head -1 | sed -E 's/^ *(.*) \(.*\) \(.*$/\1/' | tr ' ' '_')"
else
  echo "Not a simulator or emulator: $DEV (physical devices are refused)" >&2
  exit 2
fi
OUT="build/verify/$NAME"
rm -rf "$OUT"; mkdir -p "$OUT"

if ! git diff --quiet -- pubspec.yaml pubspec.lock; then
  echo "Commit or stash pubspec.yaml/pubspec.lock first (the run restores them)." >&2
  exit 2
fi

restore() {
  rm -f pubspec_overrides.yaml
  rm -rf build/native_assets/ios  # simulator frameworks must not reach an IPA
  git checkout -- pubspec.yaml pubspec.lock ios/Podfile.lock \
    ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || true
  flutter pub get >/dev/null
  if [[ $PLATFORM == ios ]]; then (cd ios && pod install >/dev/null) || true; fi
}
trap restore EXIT

# integration_test only for the run (it would otherwise ship in release IPAs).
python3 - <<'PY'
p = "pubspec.yaml"; t = open(p).read()
dev = "dev_dependencies:\n"
assert t.count(dev) == 1
open(p, "w").write(t.replace(dev, dev + "  integration_test:\n    sdk: flutter\n"))
PY

if [[ $PLATFORM == ios ]]; then
  # ML Kit has no arm64 simulator slice; the project is device-only.
  cat > pubspec_overrides.yaml <<'EOF'
dependency_overrides:
  google_mlkit_text_recognition:
    path: tool/store_capture/mlkit_stub
EOF
  flutter pub get >/dev/null
  sed -i '' 's/SUPPORTED_PLATFORMS = iphoneos;/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";/' \
    ios/Runner.xcodeproj/project.pbxproj
  (cd ios && pod install >/dev/null)
  # Fresh boot: an app left open by an earlier run (Safari from the store
  # step) would put a "◀ Safari" back-link in the status bar.
  xcrun simctl shutdown "$DEV" 2>/dev/null || true
  xcrun simctl boot "$DEV"
  xcrun simctl bootstatus "$DEV" -b >/dev/null
  xcrun simctl status_bar "$DEV" override --time "9:41" --batteryState charged --batteryLevel 100
else
  flutter pub get >/dev/null
fi

# Bring the app back after the test sent it to another app (store listing).
foreground() {
  if [[ $PLATFORM == ios ]]; then
    xcrun simctl launch "$DEV" com.adakVentures.scanSignSend >/dev/null 2>&1 || true
  else
    adb -s "$DEV" shell monkey -p com.adakventures.scansignsend \
      -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  fi
}

shot() {
  if [[ $PLATFORM == ios ]]; then
    xcrun simctl io "$DEV" screenshot "$1" >/dev/null 2>&1
  else
    adb -s "$DEV" exec-out screencap -p > "$1"
  fi
}

run() {  # run <test file> [flutter test args...]
  local test="$1"; shift
  local n
  n=$(ls "$OUT" | wc -l | tr -d ' ')
  set +e
  flutter test "$test" -d "$DEV" "$@" 2>&1 | while IFS= read -r line; do
    echo "$line"
    if [[ "$line" =~ CAPTURE:([a-z_]+) ]]; then
      n=$((n + 1))
      shot "$OUT/$(printf %02d "$n")_${BASH_REMATCH[1]}.png"
    elif [[ "$line" =~ LEAVE:([a-z_]+) ]]; then
      # The app is about to leave for another app: shoot that, then return.
      n=$((n + 1))
      (sleep 6; shot "$OUT/$(printf %02d "$n")_${BASH_REMATCH[1]}.png"; foreground) &
    fi
  done
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

status=0
run integration_test/device_check_test.dart || status=$?

if [[ $FULL == --full && $status == 0 ]]; then
  if [[ $PLATFORM == ios ]]; then
    trap - EXIT; restore  # capture.sh sets itself up
    tool/store_capture/capture.sh "$DEV" en || status=$?
  else
    # The emulator can't read the Mac's files: push the demo form to the
    # app-readable public Download folder.
    python3 tool/store_capture/make_forms.py >/dev/null
    adb -s "$DEV" push tool/store_capture/forms/Rental_Application.pdf \
      /sdcard/Download/Rental_Application.pdf >/dev/null
    run integration_test/store_capture_test.dart \
      --dart-define=FORM=/sdcard/Download/Rental_Application.pdf \
      --dart-define=MODE=stills || status=$?
  fi
fi

echo "Screenshots in $OUT"
ls "$OUT"
exit "$status"
