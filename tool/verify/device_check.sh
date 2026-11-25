#!/usr/bin/env bash
# On-device check with screenshots, on an iOS simulator or Android emulator.
#
#   tool/verify/device_check.sh <simulator-udid | emulator-NNNN> [--full]
#
# Runs integration_test/device_check_test.dart (library, settings, send,
# viewer, rating sheet, store listing) and saves a screenshot at each
# CAPTURE: marker to build/verify/<device>/NN_<name>.png. --ocr-gate runs only
# integration_test/ocr_gate_test.dart (OCR fields vs text-layer fields; see
# its GATE lines). --upgrade [tag…] runs integration_test/upgrade_verify_test.dart
# once per old version (default: tool/verify/upgrade/versions.txt) on that
# version's data from test/fixtures/upgrade/ (made by upgrade_seed.sh).
# --full also runs the
# whole store flow (import → detect → fill → sign → flatten → send → preview)
# from integration_test/store_capture_test.dart; on iOS that's capture.sh.
#
# Refuses physical devices: an integration run reinstalls the app, which
# wipes its documents.
set -euo pipefail
cd "$(dirname "$0")/../.."

DEV="${1:?usage: device_check.sh <simulator-udid|emulator-NNNN> [--full|--ocr-gate|--upgrade [tag…]]}"
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
  # The release builds are device-only; allow the simulator for this run.
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

# Copy a test PDF into the app's temp folder (the test asks with NEED:).
provide() {
  local src="test/fixtures/irs_fw4_2026.pdf"
  if [[ $PLATFORM == ios ]]; then
    # path_provider's temporary directory on iOS is Library/Caches.
    cp "$src" "$(xcrun simctl get_app_container "$DEV" com.adakVentures.scanSignSend data)/Library/Caches/fw4.pdf"
  else
    adb -s "$DEV" exec-in run-as com.adakventures.scansignsend \
      sh -c 'cat > cache/fw4.pdf' < "$src"
  fi
}

# The OCR gate's forms, into the app's temp folder as gate_<name>.pdf.
provide_gate() {
  python3 tool/store_capture/make_forms.py >/dev/null
  local f
  for f in tool/store_capture/forms/*.pdf test/fixtures/irs_fw4_2026.pdf; do
    local name="gate_$(basename "$f" .pdf).pdf"
    [[ $f == *irs_fw4_2026.pdf ]] && name=gate_fw4.pdf
    if [[ $PLATFORM == ios ]]; then
      cp "$f" "$(xcrun simctl get_app_container "$DEV" com.adakVentures.scanSignSend data)/Library/Caches/$name"
    else
      adb -s "$DEV" exec-in run-as com.adakventures.scansignsend \
        sh -c "cat > cache/$name" < "$f"
    fi
  done
}

# An old version's data into the freshly installed app (NEED:upgrade), then
# the marker the test waits for. Settings go through `defaults import` on iOS:
# the running app reads them from cfprefsd, not from the file.
provide_upgrade() {
  local fx="$PWD/test/fixtures/upgrade/$FROM/$PLATFORM"
  if [[ $PLATFORM == ios ]]; then
    local c
    c="$(xcrun simctl get_app_container "$DEV" com.adakVentures.scanSignSend data)"
    tar -xzf "$fx/data.tar.gz" -C "$c"
    # Into the container's own domain (its plist path): the app does not
    # read the simulator-wide com.adakVentures.scanSignSend domain.
    xcrun simctl spawn "$DEV" defaults import \
      "$c/Library/Preferences/com.adakVentures.scanSignSend.plist" "$fx/prefs.plist"
    cp "$fx/expect.json" "$c/Library/Caches/upgrade_expect.json"
    touch "$c/Library/Caches/upgrade_ready"
  else
    gunzip -c "$fx/data.tar.gz" |
      adb -s "$DEV" exec-in run-as com.adakventures.scansignsend tar -xf -
    adb -s "$DEV" exec-in run-as com.adakventures.scansignsend \
      sh -c 'cat > cache/upgrade_expect.json' < "$fx/expect.json"
    adb -s "$DEV" shell run-as com.adakventures.scansignsend touch cache/upgrade_ready
  fi
}

# RECORD:<name> … STOP:<name>: a screen video, then <name>.gif next to it.
REC_PID=""
record() {
  if [[ $PLATFORM == ios ]]; then
    xcrun simctl io "$DEV" recordVideo --codec=h264 --force "$OUT/$1.mp4" >/dev/null 2>&1 &
  else
    adb -s "$DEV" shell screenrecord --bit-rate 6000000 "/sdcard/$1.mp4" &
  fi
  REC_PID=$!
}
stop_record() {
  [[ -z $REC_PID ]] && return
  if [[ $PLATFORM == ios ]]; then
    kill -INT "$REC_PID" 2>/dev/null || true
    wait "$REC_PID" 2>/dev/null || true
  else
    # </dev/null: anything reading stdin here eats the test's output lines.
    adb -s "$DEV" shell pkill -INT screenrecord </dev/null || true
    wait "$REC_PID" 2>/dev/null || true
    sleep 1
    adb -s "$DEV" pull "/sdcard/$1.mp4" "$OUT/$1.mp4" </dev/null >/dev/null
    adb -s "$DEV" shell rm -f "/sdcard/$1.mp4" </dev/null
  fi
  REC_PID=""
  # In the background, so the next marker is not held up.
  if command -v ffmpeg >/dev/null; then
    ffmpeg -nostdin -loglevel error -y -i "$OUT/$1.mp4" -vf \
      "fps=12,scale=360:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
      "$OUT/$1.gif" </dev/null || true &
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
  # iOS always runs verbose: with Xcode 27 the quiet mode intermittently
  # fails with "missing expected TARGET_BUILD_DIR" after a good build. The
  # verbose noise ("[ +12 ms] …") is hidden unless VERBOSE=1.
  local v=""
  [[ $PLATFORM == ios || -n "${VERBOSE:-}" ]] && v="-v"
  flutter test "$test" -d "$DEV" $v "$@" 2>&1 | while IFS= read -r line; do
    if [[ -n "${VERBOSE:-}" || ! "$line" =~ ^\[\ *\+?[0-9]+\ ms\] ]]; then
      echo "$line"
    fi
    if [[ "$line" =~ CAPTURE:([a-z0-9_]+) ]]; then
      n=$((n + 1))
      shot "$OUT/$(printf %02d "$n")_${BASH_REMATCH[1]}.png"
    elif [[ "$line" == *NEED:gate* ]]; then
      provide_gate
    elif [[ "$line" == *NEED:upgrade* ]]; then
      provide_upgrade
    elif [[ "$line" == *NEED:w4* ]]; then
      provide
    elif [[ "$line" == *NEED:form* ]]; then
      # The store flow's demo form, into the app's cache (Android only).
      adb -s "$DEV" exec-in run-as com.adakventures.scansignsend \
        sh -c 'cat > cache/Rental_Application.pdf' \
        < tool/store_capture/forms/Rental_Application.pdf
    elif [[ "$line" =~ RECORD:([a-z0-9_]+) ]]; then
      record "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ STOP:([a-z0-9_]+) ]]; then
      stop_record "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ LEAVE:([a-z0-9_]+) ]]; then
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
if [[ $FULL == --ocr-gate ]]; then
  run integration_test/ocr_gate_test.dart | grep -E "GATE|passed|failed" || status=$?
  exit "$status"
fi
if [[ $FULL == --upgrade ]]; then
  tags=("${@:3}")
  if [[ ${#tags[@]} == 0 ]]; then
    while read -r t; do tags+=("$t"); done < <(grep -v '^#' tool/verify/upgrade/versions.txt | grep .)
  fi
  for FROM in "${tags[@]}"; do
    if [[ ! -f test/fixtures/upgrade/$FROM/$PLATFORM/data.tar.gz ]]; then
      echo "FAIL: no fixture for $FROM on $PLATFORM (tool/verify/upgrade_seed.sh $DEV $FROM)"
      status=1
      continue
    fi
    # A fresh install, as the old data must be the only data.
    if [[ $PLATFORM == ios ]]; then
      xcrun simctl uninstall "$DEV" com.adakVentures.scanSignSend 2>/dev/null || true
    else
      adb -s "$DEV" uninstall com.adakventures.scansignsend >/dev/null 2>&1 || true
    fi
    echo "== upgrade from $FROM"
    run integration_test/upgrade_verify_test.dart --dart-define=FROM="$FROM" || status=$?
  done
  echo "Screenshots in $OUT"
  exit "$status"
fi
run integration_test/device_check_test.dart || status=$?

if [[ $FULL == --full && $status == 0 ]]; then
  if [[ $PLATFORM == ios ]]; then
    trap - EXIT; restore  # capture.sh sets itself up
    tool/store_capture/capture.sh "$DEV" en || status=$?
  else
    # The emulator can't read the Mac's files: the test asks (NEED:form)
    # and run() copies the demo form into the app's cache.
    python3 tool/store_capture/make_forms.py >/dev/null
    run integration_test/store_capture_test.dart \
      --dart-define=FORM=cache:Rental_Application.pdf \
      --dart-define=MODE=stills || status=$?
  fi
fi

echo "Screenshots in $OUT"
ls "$OUT"
exit "$status"
