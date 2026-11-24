#!/usr/bin/env python3
"""What an old version's data holds, for the upgrade check to compare.

Usage: expect.py <scan_sign_send.db> <tag> > expect.json

Reads only tables and columns that exist from schema 7 (1.0.0) on. The
upgrade test (integration_test/upgrade_verify_test.dart) checks the same
facts after the new version has migrated the data.
"""
import json
import sqlite3
import sys

db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
db.row_factory = sqlite3.Row
q = lambda sql, *a: db.execute(sql, a).fetchall()

docs = []
for d in q("SELECT * FROM documents ORDER BY id"):
    fields = q("SELECT * FROM fields WHERE document_id = ?", d["id"])
    docs.append({
        "title": d["title"],
        "status": d["status"],
        "isTemplate": bool(d["is_template"]),
        "pageCount": d["page_count"],
        "pages": len(q("SELECT id FROM pages WHERE document_id = ?", d["id"])),
        "fields": len(fields),
        "values": sorted(f["value"] for f in fields if f["value"] and f["type"] != "signature"),
        "signed": sum(1 for f in fields if f["type"] == "signature" and f["value"]),
        "checked": sum(1 for f in fields if f["is_checked"]),
        "pressedPdf": d["pressed_pdf_path"] is not None,
        "fillablePdf": d["fillable_pdf_path"] is not None,
    })

# The row the app shows: the lowest id (ProfileRepository).
profile = q("SELECT * FROM user_profile ORDER BY id LIMIT 1")
profile_rows = len(q("SELECT id FROM user_profile"))
out = {
    "tag": sys.argv[2],
    "schema": db.execute("PRAGMA user_version").fetchone()[0],
    "documents": docs,
    "signatures": len(q("SELECT id FROM signatures")),
    "profileRows": profile_rows,
    "profile": {
        "fullName": profile[0]["full_name"] if profile else "",
        "email": profile[0]["email"] if profile else "",
        "isPurchased": bool(profile[0]["is_purchased"]) if profile else False,
    },
}
# From schema 8 (1.2.0) the name is kept as first and last name.
if profile and "first_name" in profile[0].keys():
    out["profile"]["firstName"] = profile[0]["first_name"] or ""
    out["profile"]["lastName"] = profile[0]["last_name"] or ""
assert docs, "the old version saved no documents"
json.dump(out, sys.stdout, indent=1, ensure_ascii=False)
print()
