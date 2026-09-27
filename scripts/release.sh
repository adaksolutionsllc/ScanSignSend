#!/usr/bin/env bash
# Build Scan Sign Send on this Mac and upload it for testing.
#
#   scripts/release.sh ios        # TestFlight (internal testers)
#   scripts/release.sh android    # Google Play internal testing track
#   scripts/release.sh all        # both
#
# Production is deliberately NOT automated here: promote a tested build from
# App Store Connect (submit for review) and Play Console (internal → production,
# staged rollout) by hand — see store/SUBMISSION_CHECKLIST.md.
#
# Credentials never live in the repo. Put them in
# ~/.config/scansignsend/release.env (chmod 600):
#
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   export ASC_KEY_PATH=$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
#   export GOOGLE_PLAY_JSON_KEY=$HOME/.config/scansignsend/play-service-account.json
#
# Every upload needs a new build number: bump `version: x.y.z+N` in
# pubspec.yaml first (the stores reject a number they've already seen).
set -euo pipefail

target="${1:-}"
case "$target" in ios|android|all|ios-upload) ;; *)
  echo "usage: $0 ios|android|all|ios-upload" >&2; exit 64 ;;
esac

# Uploads can die on a dropped connection mid-transfer (altool reports
# "The network connection was lost" and fastlane gives up). Retry the upload
# alone — the build is fine — before failing.
upload_ios() {
  local ipa="$1" attempt
  local build="${version##*+}" log
  log="$(mktemp)"
  for attempt in 1 2 3; do
    echo "▶ iOS: uploading $ipa to TestFlight (attempt $attempt/3)"
    # pipefail (set above) makes this fail when fastlane fails, not tee.
    if (cd "$root/ios" && IPA_PATH="$ipa" fastlane local_testflight) 2>&1 | tee "$log"; then
      return 0
    fi
    # fastlane reports failure whenever altool logged a retried part, even
    # when altool itself finished the upload. Trust altool's own verdict.
    if LC_ALL=C grep -aq "UPLOAD SUCCEEDED" "$log"; then
      echo "✓ Upload succeeded (fastlane's error was only retried network parts)"
      return 0
    fi
    # A dropped connection can hide a successful upload; Apple then refuses
    # the retry as a duplicate of this very build number. That's success too.
    # (\${build} braces matter: a curly quote right after \$build was read by
    # bash as part of the variable name.)
    if LC_ALL=C grep -aq "previously uploaded version: .${build}." "$log"; then
      echo "✓ Build ${build} is already on App Store Connect (earlier attempt succeeded)"
      return 0
    fi
    sleep 20
  done
  echo "Upload failed 3 times; retry later with: $0 ios-upload" >&2
  return 1
}

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
env_file="$HOME/.config/scansignsend/release.env"
[[ -f "$env_file" ]] || { echo "Missing $env_file (see header of this script)" >&2; exit 1; }
# shellcheck disable=SC1090
source "$env_file"

version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
echo "▶ Releasing $version to: $target"

[[ -z "$(git status --porcelain)" ]] || { echo "Commit your changes first." >&2; exit 1; }

if [[ "$target" == ios-upload ]]; then
  # Re-upload the last IPA built by this script (after a failed upload).
  : "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
  upload_ios "$(ls "$root"/build/ios/ipa/*.ipa | head -1)"
  echo "✓ $version uploaded (ios)"
  exit 0
fi

echo "▶ Checks"
flutter pub get >/dev/null
flutter analyze
flutter test
python3 store/listings/check_limits.py

if [[ "$target" == ios || "$target" == all ]]; then
  : "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
  # Apple rejects an upload whose asset catalog lacks the 1024x1024 App Store
  # icon (it happened: the file was deleted and slipped into a commit). Check
  # every icon the catalog lists exists, and the marketing icon has no alpha.
  icons="$root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  python3 - "$icons" <<'PY'
import json, os, subprocess, sys
d = sys.argv[1]
names = [i["filename"] for i in json.load(open(os.path.join(d, "Contents.json")))["images"] if "filename" in i]
missing = [n for n in names if not os.path.exists(os.path.join(d, n))]
if missing:
    sys.exit("Missing app icons: " + ", ".join(missing))
big = os.path.join(d, "Icon-App-1024x1024@1x.png")
info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "hasAlpha", big], capture_output=True, text=True).stdout
if "pixelWidth: 1024" not in info or "hasAlpha: yes" in info:
    sys.exit("App Store icon must be 1024x1024 with no transparency")
print("✓ App icons present")
PY
  echo "▶ iOS: building IPA"
  flutter build ipa --release
  upload_ios "$(ls "$root"/build/ios/ipa/*.ipa | head -1)"
fi

if [[ "$target" == android || "$target" == all ]]; then
  : "${GOOGLE_PLAY_JSON_KEY:?}"
  [[ -f android/key.properties ]] || { echo "android/key.properties missing (upload keystore)" >&2; exit 1; }
  echo "▶ Android: building App Bundle"
  flutter build appbundle --release
  echo "▶ Android: uploading to Play internal testing"
  (cd android && AAB_PATH="$root/build/app/outputs/bundle/release/app-release.aab" \
    fastlane internal)
fi

echo "✓ $version uploaded ($target). Tag it: git tag v${version/+/-build} && git push --tags"
