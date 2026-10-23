#!/usr/bin/env python3
"""Add, replace or remove ARB keys in all 7 locales at once.

Usage: tool/arb_set.py changes.json
changes.json: {"set": {key: {"en": ..., "fr": ..., ...}},
               "meta": {key: {"placeholders": {...}}},   # written as @key in en
               "after": {key: existingKey},              # optional placement
               "remove": [key, ...]}
Every "set" key must have all 7 locales, so the completeness test can't fail
because of a forgotten file.
"""
import json
import sys
from pathlib import Path

LOCALES = ["en", "fr", "es", "pt", "hi", "ta", "te"]
L10N = Path(__file__).resolve().parent.parent / "lib" / "l10n"

changes = json.loads(Path(sys.argv[1]).read_text())
sets = changes.get("set", {})
meta = changes.get("meta", {})
after = changes.get("after", {})
remove = changes.get("remove", [])

for key, values in sets.items():
    missing = [l for l in LOCALES if not values.get(l)]
    if missing:
        sys.exit(f"{key}: missing {missing}")

for loc in LOCALES:
    path = L10N / f"app_{loc}.arb"
    data = json.loads(path.read_text())
    for key in remove:
        if key not in data:
            sys.exit(f"{loc}: remove {key}: not present")
        data.pop(key)
        data.pop(f"@{key}", None)
    items = list(data.items())
    for key, values in sets.items():
        entries = [(key, values[loc])]
        if loc == "en" and key in meta:
            entries.append((f"@{key}", meta[key]))
        keys = [k for k, _ in items]
        if key in keys:
            i = keys.index(key)
            items = [kv for kv in items if kv[0] not in (key, f"@{key}")]
            items[i:i] = entries
        elif key in after:
            anchor = after[key]
            if anchor not in keys:
                sys.exit(f"{loc}: anchor {anchor} not found")
            i = keys.index(anchor) + 1
            if i < len(keys) and keys[i] == f"@{anchor}":
                i += 1
            items[i:i] = entries
        else:
            items.extend(entries)
    path.write_text(json.dumps(dict(items), ensure_ascii=False, indent=2) + "\n")
    print(f"{loc}: ok")
