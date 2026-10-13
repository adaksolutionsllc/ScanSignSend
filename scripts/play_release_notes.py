#!/usr/bin/env python3
"""Write Google Play release notes for the pubspec build from store/listings.

    python3 scripts/play_release_notes.py

store/listings/<lang>.md (its `## whats_new` section) stays the single source
of truth; this writes, for the version code in pubspec.yaml,

    android/fastlane/metadata/android/<play-locale>/changelogs/<code>.txt

which fastlane `supply` uploads with the `internal` upload and with
`promote_to_production` (the notes go on the release being promoted).
Play allows 500 characters per language; anything longer is refused here
rather than by Play halfway through an upload.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTINGS = os.path.join(ROOT, "store", "listings")
OUT = os.path.join(ROOT, "android", "fastlane", "metadata", "android")
LIMIT = 500

# store/listings language -> Play Console language codes.
PLAY_LOCALES = {
    "en": ["en-US"],
    "fr": ["fr-FR"],
    "es": ["es-ES", "es-419"],
    "pt": ["pt-BR"],
    "hi": ["hi-IN"],
    "ta": ["ta-IN"],
    "te": ["te-IN"],
}


def whats_new(lang: str) -> str:
    text = open(os.path.join(LISTINGS, f"{lang}.md"), encoding="utf-8").read()
    m = re.search(r"^## whats_new\n(.*?)(?=\n## |\Z)", text, re.S | re.M)
    if not m or not m.group(1).strip():
        sys.exit(f"{lang}.md has no whats_new section")
    return m.group(1).strip()


def main() -> int:
    pubspec = open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8").read()
    code = re.search(r"^version:\s*[\d.]+\+(\d+)", pubspec, re.M).group(1)
    notes = {lang: whats_new(lang) for lang in PLAY_LOCALES}
    too_long = {l: len(t) for l, t in notes.items() if len(t) > LIMIT}
    if too_long:
        sys.exit(f"Play release notes over {LIMIT} characters: {too_long}")
    for lang, text in notes.items():
        for loc in PLAY_LOCALES[lang]:
            d = os.path.join(OUT, loc, "changelogs")
            os.makedirs(d, exist_ok=True)
            for old in os.listdir(d):  # one build's notes at a time
                os.remove(os.path.join(d, old))
            with open(os.path.join(d, f"{code}.txt"), "w", encoding="utf-8") as f:
                f.write(text + "\n")
    n = sum(len(v) for v in PLAY_LOCALES.values())
    print(f"Play release notes for version code {code}: {n} languages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
