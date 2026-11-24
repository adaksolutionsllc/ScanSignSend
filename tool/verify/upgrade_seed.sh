#!/usr/bin/env bash
# Makes the upgrade fixture of an OLD version: real data made by that
# version's own code.
#
#   tool/verify/upgrade_seed.sh <simulator-udid | emulator-NNNN> <tag>
#
# Builds <tag> in a git worktree, installs it fresh, runs
# tool/verify/upgrade/upgrade_seed_test.dart there (documents: signed and
# flattened, draft, fillable, photo with drawn fields, template; a signature;
# a profile), then saves the app's data folder to
# test/fixtures/upgrade/<tag>/<ios|android>/. Old versions never change, so
# run this once per version and platform; device_check.sh --upgrade uses the
# fixtures on every run.
#
# Refuses physical devices: it uninstalls the app first.
set -euo pipefail
cd "$(dirname "$0")/../.."
REPO="$PWD"

DEV="${1:?usage: upgrade_seed.sh <simulator-udid|emulator-NNNN> <tag>}"
TAG="${2:?usage: upgrade_seed.sh <simulator-udid|emulator-NNNN> <tag>}"
IOS_ID=com.adakVentures.scanSignSend
ANDROID_ID=com.adakventures.scansignsend

if [[ $DEV == emulator-* ]]; then
  PLATFORM=android
  adb -s "$DEV" get-state >/dev/null
elif xcrun simctl list devices | grep -q "($DEV)"; then
  PLATFORM=ios
else
  echo "Not a simulator or emulator: $DEV (physical devices are refused)" >&2
  exit 2
fi
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "No tag $TAG" >&2; exit 2; }

OUT="$REPO/test/fixtures/upgrade/$TAG/$PLATFORM"
WT="$(mktemp -d)/seed-$TAG"
cleanup() {
  local rc=$?
  git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
  exit "$rc"
}
trap cleanup EXIT
git worktree add --detach "$WT" "$TAG" >/dev/null

cd "$WT"
mkdir -p integration_test
cp "$REPO/tool/verify/upgrade/upgrade_seed_test.dart" integration_test/
python3 - <<'PY'
p = "pubspec.yaml"; t = open(p).read()
dev = "dev_dependencies:\n"
assert t.count(dev) == 1
if "integration_test:" not in t:
    t = t.replace(dev, dev + "  integration_test:\n    sdk: flutter\n")
open(p, "w").write(t)
PY
if [[ $PLATFORM == ios ]]; then
  # ML Kit has no arm64 simulator slice: build with the stub kept at the
  # last tag that had it. The seed itself reads no text.
  mkdir -p tool/store_capture
  git -C "$REPO" archive v1.3.1-build23 tool/store_capture/mlkit_stub | tar -x -C .
  printf 'dependency_overrides:\n  google_mlkit_text_recognition:\n    path: tool/store_capture/mlkit_stub\n' \
    > pubspec_overrides.yaml
  flutter pub get >/dev/null
  sed -i '' 's/SUPPORTED_PLATFORMS = iphoneos;/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";/' \
    ios/Runner.xcodeproj/project.pbxproj
  (cd ios && pod install >/dev/null)
  xcrun simctl bootstatus "$DEV" -b >/dev/null
  xcrun simctl uninstall "$DEV" "$IOS_ID" 2>/dev/null || true
else
  flutter pub get >/dev/null
  adb -s "$DEV" uninstall "$ANDROID_ID" >/dev/null 2>&1 || true
fi

provide_w4() {
  local src="$REPO/test/fixtures/irs_fw4_2026.pdf"
  if [[ $PLATFORM == ios ]]; then
    cp "$src" "$(xcrun simctl get_app_container "$DEV" "$IOS_ID" data)/Library/Caches/fw4.pdf"
  else
    adb -s "$DEV" exec-in run-as "$ANDROID_ID" sh -c 'cat > cache/fw4.pdf' < "$src"
  fi
}

echo "Seeding ${TAG} on ${PLATFORM}…"
set +e
v=""; [[ $PLATFORM == ios ]] && v="-v"
seeded=0
while IFS= read -r line; do
  [[ "$line" =~ ^\[\ *\+?[0-9]+\ ms\] ]] || echo "$line"
  [[ "$line" == *NEED:w4* ]] && provide_w4
  [[ "$line" == *SEED:done* ]] && seeded=1
done < <(flutter test integration_test/upgrade_seed_test.dart -d "$DEV" $v 2>&1)
set -e
[[ $seeded == 1 ]] || { echo "The seed did not finish" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/db"
if [[ $PLATFORM == ios ]]; then
  xcrun simctl terminate "$DEV" "$IOS_ID" 2>/dev/null || true
  C="$(xcrun simctl get_app_container "$DEV" "$IOS_ID" data)"
  dirs=(Documents)
  [[ -d "$C/Library/Application Support" ]] && dirs+=("Library/Application Support")
  tar -C "$C" -czf "$OUT/data.tar.gz" "${dirs[@]}"
  xcrun simctl spawn "$DEV" defaults export "$IOS_ID" "$OUT/prefs.plist"
  cp "$C"/Documents/scan_sign_send.db* "$OUT/db/"
else
  adb -s "$DEV" shell am force-stop "$ANDROID_ID"
  have=$(adb -s "$DEV" shell run-as "$ANDROID_ID" ls | tr -d '\r' |
    grep -xE 'app_flutter|shared_prefs|files|databases|no_backup' | tr '\n' ' ')
  # shellcheck disable=SC2086
  adb -s "$DEV" exec-out run-as "$ANDROID_ID" tar -cf - $have | gzip > "$OUT/data.tar.gz"
  tar -xzf "$OUT/data.tar.gz" -C "$OUT/db" --strip-components 1 \
    --include 'app_flutter/scan_sign_send.db*'
fi
python3 -I "$REPO/tool/verify/upgrade/expect.py" "$OUT/db/scan_sign_send.db" "$TAG" > "$OUT/expect.json"
rm -rf "$OUT/db"
echo "Fixture: $OUT ($(du -sh "$OUT" | cut -f1))"
cat "$OUT/expect.json"
