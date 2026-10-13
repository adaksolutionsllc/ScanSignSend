#!/usr/bin/env bash
# Raw Google Play screenshots from an Android emulator, per language.
#
#   tool/store_capture/capture_android.sh emulator-5554 en fr es pt hi ta te
#
# Runs integration_test/store_capture_test.dart in each language (set inside
# the test: the emulator's own language can't be switched from a script)
# with that language's demo form, and saves a screenshot at each CAPTURE:
# marker to build/store_capture/raw/Android_Phone/<lang>/NN_<name>.png.
# Then: python3 tool/store_capture/frame.py (frames them for Play too).
#
# The status bar is put in demo mode (9:41, full Wi-Fi and battery, no
# notifications) for the run. Refuses physical devices: the run reinstalls
# the app, which wipes its documents.
set -euo pipefail
cd "$(dirname "$0")/../.."

DEV="${1:?usage: capture_android.sh <emulator-NNNN> <lang>...}"
shift
[[ $DEV == emulator-* ]] || { echo "Emulators only (got $DEV)" >&2; exit 2; }
adb -s "$DEV" get-state >/dev/null
LANGS=("$@")
[[ ${#LANGS[@]} -gt 0 ]] || LANGS=(en fr es pt hi ta te)
OUT="build/store_capture/raw/Android_Phone"

if ! git diff --quiet -- pubspec.yaml pubspec.lock; then
  echo "Commit or stash pubspec.yaml/pubspec.lock first (the run restores them)." >&2
  exit 2
fi

demo() { adb -s "$DEV" shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
restore() {
  demo exit || true
  git checkout -- pubspec.yaml pubspec.lock 2>/dev/null || true
  flutter pub get >/dev/null
}
trap restore EXIT

# integration_test only for the run (it would otherwise ship in releases).
python3 - <<'PY'
p = "pubspec.yaml"; t = open(p).read()
dev = "dev_dependencies:\n"
assert t.count(dev) == 1
open(p, "w").write(t.replace(dev, dev + "  integration_test:\n    sdk: flutter\n"))
PY
flutter pub get >/dev/null

# A clean status bar.
adb -s "$DEV" shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 0941
demo network -e wifi show -e level 4 -e mobile hide
demo battery -e level 100 -e plugged false
demo notifications -e visible false

# The demo forms are born-digital PDFs (their text layer is read, no OCR).
python3 tool/store_capture/make_forms.py >/dev/null
form_for() {
  case "$1" in
    fr) echo Demande_de_location.pdf ;;
    es) echo Solicitud_de_alquiler.pdf ;;
    pt) echo Ficha_de_locacao.pdf ;;
    *)  echo Rental_Application.pdf ;;  # en, hi, ta, te
  esac
}

status=0
for lang in "${LANGS[@]}"; do
  dir="$OUT/$lang"
  rm -rf "$dir"; mkdir -p "$dir"
  form="$(form_for "$lang")"
  echo "── Android_Phone / $lang"
  n=0
  set +e
  flutter test integration_test/store_capture_test.dart -d "$DEV" \
    --dart-define=FORM="cache:$form" --dart-define=MODE=stills \
    --dart-define=LOCALE="$lang" 2>&1 | while IFS= read -r line; do
      [[ "$line" =~ ^\[\ *\+?[0-9]+\ ms\] ]] || echo "$line"
      if [[ "$line" == *NEED:form* ]]; then
        # The emulator can't read the Mac's files: into the app's own cache.
        adb -s "$DEV" exec-in run-as com.adakventures.scansignsend \
          sh -c "cat > cache/$form" < "tool/store_capture/forms/$form"
      elif [[ "$line" =~ CAPTURE:([a-z0-9_]+) ]]; then
        n=$((n + 1))
        adb -s "$DEV" exec-out screencap -p > "$dir/$(printf %02d "$n")_${BASH_REMATCH[1]}.png"
      fi
    done
  rc=${PIPESTATUS[0]}
  set -e
  [[ $rc == 0 ]] || status=$rc
done
echo "Raw captures in $OUT"
exit "$status"
