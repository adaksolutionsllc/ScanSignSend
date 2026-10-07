#!/usr/bin/env bash
# Capture App Store screenshots (and optionally preview footage) on simulators.
#
#   tool/store_capture/capture.sh [--video] <device-udid> <lang>...
#   e.g. tool/store_capture/capture.sh 088FE797-… en fr es pt hi ta te
#
# Raw captures land in build/store_capture/raw/<device-name>/<lang>/<n>.png;
# tool/store_capture/frame.py turns them into store screenshots.
#
# ML Kit has no arm64 simulator slice, so for the duration of the run
# pubspec_overrides.yaml swaps in tool/store_capture/mlkit_stub. The trap puts
# the iOS project back (pod install rewrites it without ML Kit) on any exit.
set -euo pipefail
cd "$(dirname "$0")/../.."

MODE=stills
if [[ "${1:-}" == "--video" ]]; then MODE=video; shift; fi
DEV="$1"; shift
LANGS=("$@")
BUNDLE=com.adakVentures.scanSignSend
NAME=$(xcrun simctl list devices | grep "$DEV" | sed -E 's/^ *(.*) \(.*\) \(.*$/\1/' | tr ' ' '_')
OUT="build/store_capture/raw/$NAME"

restore() {
  rm -f pubspec_overrides.yaml
  git checkout -- ios/Podfile.lock ios/Runner.xcodeproj/project.pbxproj 2>/dev/null || true
  flutter pub get >/dev/null
  (cd ios && pod install >/dev/null) || true
}
trap restore EXIT

cat > pubspec_overrides.yaml <<'EOF'
dependency_overrides:
  google_mlkit_text_recognition:
    path: tool/store_capture/mlkit_stub
EOF
flutter pub get >/dev/null
# The project is device-only (SUPPORTED_PLATFORMS = iphoneos); allow the
# simulator for this run. The trap restores the project file.
sed -i '' 's/SUPPORTED_PLATFORMS = iphoneos;/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";/' \
  ios/Runner.xcodeproj/project.pbxproj
# Re-run CocoaPods now, so Flutter sees a Pods project without ML Kit when it
# decides whether to exclude arm64 from simulator builds.
(cd ios && pod install >/dev/null)
python3 tool/store_capture/make_forms.py >/dev/null

form_for() {
  case "$1" in
    fr) echo tool/store_capture/forms/Demande_de_location.pdf ;;
    es) echo tool/store_capture/forms/Solicitud_de_alquiler.pdf ;;
    pt) echo tool/store_capture/forms/Ficha_de_locacao.pdf ;;
    *)  echo tool/store_capture/forms/Rental_Application.pdf ;;  # en, hi, ta, te
  esac
}

region_for() {
  case "$1" in
    en) echo en_US ;;
    fr) echo fr_FR ;;
    es) echo es_MX ;;
    pt) echo pt_BR ;;
    *)  echo "$1_IN" ;;
  esac
}

for lang in "${LANGS[@]}"; do
  echo "── $NAME / $lang ($MODE)"
  # Simulator language + region, applied by a reboot.
  xcrun simctl shutdown "$DEV" 2>/dev/null || true
  region=$(region_for "$lang")
  xcrun simctl spawn "$DEV" defaults write .GlobalPreferences AppleLanguages -array "$lang" 2>/dev/null || true
  plutil -replace AppleLanguages -json "[\"$lang\"]" \
    ~/Library/Developer/CoreSimulator/Devices/"$DEV"/data/Library/Preferences/.GlobalPreferences.plist
  plutil -replace AppleLocale -string "$region" \
    ~/Library/Developer/CoreSimulator/Devices/"$DEV"/data/Library/Preferences/.GlobalPreferences.plist
  xcrun simctl boot "$DEV"
  xcrun simctl bootstatus "$DEV" -b >/dev/null
  xcrun simctl status_bar "$DEV" override --time "9:41" --dataNetwork wifi \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
  xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null || true

  # Video goes in its own folder so it never wipes the stills.
  dir="$OUT/$lang"; [[ $MODE == video ]] && dir="$dir/video"
  rm -rf "$dir"; mkdir -p "$dir"
  n=0
  rec_pid=""
  rec_t0=""
  flutter test integration_test/store_capture_test.dart -d "$DEV" \
      --dart-define=FORM="$PWD/$(form_for "$lang")" --dart-define=MODE="$MODE" 2>&1 |
    while IFS= read -r line; do
      echo "$line"
      if [[ "$line" =~ CAPTURE:([a-z_]+) ]]; then
        n=$((n + 1))
        xcrun simctl io "$DEV" screenshot "$dir/$(printf %02d "$n")_${BASH_REMATCH[1]}.png" >/dev/null 2>&1
      elif [[ $MODE == video && "$line" == *REC:start* ]]; then
        xcrun simctl io "$DEV" recordVideo --codec h264 --force "$dir/preview_raw.mov" >/dev/null 2>&1 &
        rec_pid=$!
        rec_t0=$(python3 -c 'import time; print(time.time())')
        : > "$dir/beats.txt"
      elif [[ -n $rec_t0 && "$line" =~ BEAT:([a-z_]+) ]]; then
        # Seconds since recording began, for the caption timeline.
        python3 -c "import time; print(f'{time.time()-$rec_t0:.2f} ${BASH_REMATCH[1]}')" >> "$dir/beats.txt"
      elif [[ -n $rec_pid && "$line" == *REC:stop* ]]; then
        kill -INT "$rec_pid"; wait "$rec_pid" || true; rec_pid=""
      fi
    done
done
echo "Raw captures in $OUT"
