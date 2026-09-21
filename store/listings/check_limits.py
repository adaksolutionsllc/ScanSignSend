#!/usr/bin/env python3
"""Validate the localized store listings against the console character limits.

Both stores reject an upload outright when a field is one character over, and
they do it per-language — so a listing that is fine in English can fail only in
Tamil, after you have already filled in six other languages by hand. This
checks all of them at once.

Limits are counted in *characters*, not bytes, which is why Devanagari, Tamil
and Telugu are not penalised for their UTF-8 size.

    python3 store/listings/check_limits.py
"""
from __future__ import annotations

import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))

LOCALES = ["en", "fr", "es", "pt", "hi", "ta", "te"]

# field -> (limit, where it is used). None = no enforced limit.
LIMITS = {
    "app_name": (30, "App Store + Play"),
    "subtitle": (30, "App Store"),
    "short_description": (80, "Play"),
    "promotional_text": (170, "App Store"),
    "keywords": (100, "App Store"),
    "full_description": (4000, "App Store + Play"),
    "whats_new": (4000, "App Store + Play"),
    "iap_display_name": (30, "App Store + Play"),
    "iap_description": (45, "App Store"),
}

REQUIRED = set(LIMITS)


def parse(path: str) -> dict[str, str]:
    """`## field` headings followed by the value, as written in the .md files."""
    text = open(path, encoding="utf-8").read()
    out: dict[str, str] = {}
    for m in re.finditer(r"^## (\w+)\n(.*?)(?=\n## |\Z)", text, re.S | re.M):
        out[m.group(1)] = m.group(2).strip()
    return out


def width(value: str) -> int:
    """Character count as the consoles measure it.

    Normalise to NFC first: a decomposed Devanagari or Tamil string counts more
    code points than the identical text composed, and what gets pasted into the
    console is whatever the file holds.
    """
    return len(unicodedata.normalize("NFC", value))


def main() -> int:
    failures: list[str] = []
    warnings: list[str] = []

    for locale in LOCALES:
        path = os.path.join(HERE, f"{locale}.md")
        if not os.path.exists(path):
            failures.append(f"{locale}: missing {locale}.md")
            continue

        fields = parse(path)
        missing = REQUIRED - set(fields)
        if missing:
            failures.append(f"{locale}: missing field(s) {sorted(missing)}")

        print(f"\n{locale}")
        for name, (limit, where) in LIMITS.items():
            value = fields.get(name)
            if value is None:
                continue
            n = width(value)
            if n > limit:
                flag = "FAIL"
                failures.append(
                    f"{locale}.{name}: {n}/{limit} chars — {n - limit} over "
                    f"({where})")
            elif n > limit * 0.95:
                flag = "tight"
                warnings.append(f"{locale}.{name}: {n}/{limit} — no headroom")
            else:
                flag = "ok"
            print(f"  {name:<20} {n:>5}/{limit:<5} {flag}")

        # The brand name is the primary search term; it must survive verbatim.
        if "Scan Sign Send" not in fields.get("app_name", ""):
            failures.append(
                f"{locale}.app_name: product name was translated or dropped")

        # App Store keywords are comma-separated with no spaces after commas —
        # a space costs a character out of the 100 and indexes nothing.
        kw = fields.get("keywords", "")
        if ", " in kw:
            warnings.append(
                f"{locale}.keywords: has ', ' — the space wastes budget")

    print("\n" + "=" * 60)
    for w in warnings:
        print(f"WARN  {w}")
    for f in failures:
        print(f"FAIL  {f}")
    if failures:
        print(f"\n{len(failures)} problem(s) — these would be rejected.")
        return 1
    print(f"\nAll {len(LOCALES)} locales within limits"
          + (f" ({len(warnings)} tight)" if warnings else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
