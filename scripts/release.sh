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
case "$target" in ios|android|all) ;; *)
  echo "usage: $0 ios|android|all" >&2; exit 64 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
env_file="$HOME/.config/scansignsend/release.env"
[[ -f "$env_file" ]] || { echo "Missing $env_file (see header of this script)" >&2; exit 1; }
# shellcheck disable=SC1090
source "$env_file"

version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
echo "▶ Releasing $version to: $target"

[[ -z "$(git status --porcelain)" ]] || { echo "Commit your changes first." >&2; exit 1; }

echo "▶ Checks"
flutter pub get >/dev/null
flutter analyze
flutter test
python3 store/listings/check_limits.py

if [[ "$target" == ios || "$target" == all ]]; then
  : "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_PATH:?}"
  echo "▶ iOS: building IPA"
  flutter build ipa --release
  ipa="$(ls "$root"/build/ios/ipa/*.ipa | head -1)"
  echo "▶ iOS: uploading $ipa to TestFlight"
  (cd ios && IPA_PATH="$ipa" fastlane local_testflight)
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
