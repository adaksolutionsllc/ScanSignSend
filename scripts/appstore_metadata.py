#!/usr/bin/env python3
"""Generate fastlane `deliver` metadata from store/listings/<locale>.md.

store/listings/ stays the single source of truth for store copy; this writes
the per-field .txt files deliver uploads, so nothing is pasted into App Store
Connect by hand:

    python3 scripts/appstore_metadata.py          # -> ios/fastlane/metadata/
    cd ios && fastlane deliver --skip_binary_upload --skip_screenshots ...

The output directory is regenerated from scratch each run.
"""
from __future__ import annotations

import os
import re
import shutil
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTINGS = os.path.join(ROOT, "store", "listings")
OUT = os.path.join(ROOT, "ios", "fastlane", "metadata")

# Listing file -> App Store Connect locale(s). Spanish goes to both es-MX and
# es-ES: the US storefront also indexes es-MX keywords, and Spain needs es-ES.
LOCALES = {
    "en": ["en-US"],
    "fr": ["fr-FR"],
    "es": ["es-MX", "es-ES"],
    "pt": ["pt-BR"],
    "hi": ["hi"],
    "ta": ["ta-IN"],
    "te": ["te-IN"],
}

# listing field -> deliver file name
FIELDS = {
    "app_name": "name",
    "subtitle": "subtitle",
    "promotional_text": "promotional_text",
    "keywords": "keywords",
    "full_description": "description",
    "whats_new": "release_notes",
}

URLS = {
    "privacy_url": "https://www.adakventures.com/scansignsend/privacy",
    "support_url": "https://www.adakventures.com/scansignsend/support",
    "marketing_url": "https://www.adakventures.com/scansignsend",
}


def parse(path: str) -> dict[str, str]:
    text = open(path, encoding="utf-8").read()
    return {
        m.group(1): unicodedata.normalize("NFC", m.group(2).strip())
        for m in re.finditer(r"^## (\w+)\n(.*?)(?=\n## |\Z)", text, re.S | re.M)
    }


def main() -> int:
    shutil.rmtree(OUT, ignore_errors=True)
    for src, targets in LOCALES.items():
        fields = parse(os.path.join(LISTINGS, f"{src}.md"))
        for locale in targets:
            d = os.path.join(OUT, locale)
            os.makedirs(d)
            for field, name in FIELDS.items():
                with open(os.path.join(d, f"{name}.txt"), "w", encoding="utf-8") as f:
                    f.write(fields[field] + "\n")
            for name, url in URLS.items():
                with open(os.path.join(d, f"{name}.txt"), "w", encoding="utf-8") as f:
                    f.write(url + "\n")
    print(f"Wrote {sum(map(len, LOCALES.values()))} locales to {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
