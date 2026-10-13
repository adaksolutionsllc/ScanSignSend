#!/usr/bin/env python3
"""Write the Google Play store listing text from store/listings.

    python3 scripts/play_listing.py

store/listings/<lang>.md stays the single source of truth. For each Play
language this writes, under android/fastlane/metadata/android/<locale>/,

    title.txt              (## app_name, ≤30)
    short_description.txt  (## short_description, ≤80)
    full_description.txt   (## full_description, ≤4000)

uploaded by the `play_listing` lane. English (en-US) gets the full
description only: its title and short description were set in Play Console
and are kept as they are.

Graphics aren't written: Play shows the default (English) screenshots for
a language that has none of its own.
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTINGS = os.path.join(ROOT, "store", "listings")
OUT = os.path.join(ROOT, "android", "fastlane", "metadata", "android")

PLAY_LOCALES = {
    "en": ["en-US"],
    "fr": ["fr-FR"],
    "es": ["es-ES", "es-419"],
    "pt": ["pt-BR"],
    "hi": ["hi-IN"],
    "ta": ["ta-IN"],
    "te": ["te-IN"],
}
FIELDS = {  # listing section -> (Play file, limit)
    "app_name": ("title", 30),
    "short_description": ("short_description", 80),
    "full_description": ("full_description", 4000),
}
EN_ONLY = {"full_description"}


def sections(lang: str) -> dict[str, str]:
    text = open(os.path.join(LISTINGS, f"{lang}.md"), encoding="utf-8").read()
    return {
        m.group(1): m.group(2).strip()
        for m in re.finditer(r"^## (\w+)\n(.*?)(?=\n## |\Z)", text, re.S | re.M)
    }


def main() -> int:
    problems = []
    plan = []
    for lang, locales in PLAY_LOCALES.items():
        s = sections(lang)
        for key, (name, limit) in FIELDS.items():
            if lang == "en" and key not in EN_ONLY:
                continue
            value = s.get(key, "")
            if not value:
                problems.append(f"{lang}.md: no {key}")
            elif len(value) > limit:
                problems.append(f"{lang}.md: {key} is {len(value)} > {limit}")
            for loc in locales:
                plan.append((loc, name, value))
    if problems:
        sys.exit("\n".join(problems))
    for loc, name, value in plan:
        d = os.path.join(OUT, loc)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, f"{name}.txt"), "w", encoding="utf-8") as f:
            f.write(value + "\n")
    print(f"Play listing text: {len(plan)} files for "
          f"{sum(len(v) for v in PLAY_LOCALES.values())} languages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
