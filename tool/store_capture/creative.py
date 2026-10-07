#!/usr/bin/env python3
"""Product-page creative assets: the header (3840x1646, 21:9) and the search
results image (1920x1280, 3:2), per locale, from the framed captures' raw
screens.

    python3 tool/store_capture/creative.py   # -> build/store_capture/creative/

Header text stays inside Apple's safe area (1646x661 at 1097,493); the phones
outside it are decoration and may be cropped on narrow screens. No prices,
URLs or badges — App Review rejects them on these assets.
"""
from __future__ import annotations

import base64
import html
import os
import sys

from frame import ASC_LOCALES, render

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "build", "store_capture", "raw", "iPhone_17_Pro_Max")
OUT = os.path.join(ROOT, "build", "store_capture", "creative")

# (header phrase, header line 2, search-results headline, search-results line)
COPY = {
    "en": ("Paper in.", "Signed PDF out.", "Scan. Fill. Sign. Send.", "Finds the blanks for you — fully offline"),
    "fr": ("Du papier", "au PDF signé.", "Scannez. Remplissez. Signez.", "Trouve les champs pour vous — 100 % hors ligne"),
    "es": ("Del papel", "al PDF firmado.", "Escanea. Rellena. Firma.", "Encuentra los espacios por ti — sin conexión"),
    "pt": ("Do papel", "ao PDF assinado.", "Digitalize. Preencha. Assine.", "Encontra os campos para você — 100% offline"),
    "hi": ("कागज़ से", "साइन किया PDF", "स्कैन करें। भरें। साइन करें।", "खाली जगहें खुद ढूँढता है — पूरी तरह ऑफ़लाइन"),
    "ta": ("காகிதத்திலிருந்து", "கையொப்பமிட்ட PDF", "ஸ்கேன். நிரப்பு. கையொப்பம்.", "காலி இடங்களைத் தானே கண்டறியும் — ஆஃப்லைனில்"),
    "te": ("కాగితం నుంచి", "సంతకం చేసిన PDF", "స్కాన్. నింపండి. సంతకం.", "ఖాళీలను తానే కనుగొంటుంది — పూర్తిగా ఆఫ్‌లైన్"),
}

# Single quotes: this goes inside style="…" attributes.
FONT = ("-apple-system,'SF Pro Display','Helvetica Neue','Kohinoor Devanagari',"
        "'Tamil Sangam MN','Kohinoor Telugu',sans-serif")
BG = "linear-gradient(160deg,#1c2029 0%,#262a35 50%,#3a3424 80%,#7a5d1c 100%)"


def b64(path: str) -> str:
    return base64.b64encode(open(path, "rb").read()).decode()


def phone(img: str, w: int, x: int, y: int, rot: float) -> str:
    bz = round(w * 0.022)
    return (f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;'
            f'transform:rotate({rot}deg);border-radius:{round(w*.13)}px;'
            f'background:#0b0d11;padding:{bz}px;box-sizing:border-box;'
            f'box-shadow:0 {round(w*.05)}px {round(w*.15)}px rgba(0,0,0,.55)">'
            f'<img src="data:image/png;base64,{img}" style="width:100%;display:block;'
            f'border-radius:{round(w*.13)-bz}px"></div>')


def header(lang: str, shots: dict[str, str]) -> str:
    l1, l2, *_ = COPY[lang]
    w, h = 3840, 1646
    return f"""<!doctype html><html><head><meta charset="utf-8"></head>
<body style="margin:0;width:{w}px;height:{h}px;overflow:hidden;position:relative;
  background:{BG};font-family:{FONT}">
<div style="position:absolute;left:50%;top:40%;width:2600px;height:2600px;
  transform:translate(-50%,-50%);border-radius:50%;
  background:radial-gradient(circle,rgba(236,180,64,.20),rgba(236,180,64,0) 62%)"></div>
{phone(shots['detect'], 820, 120, 260, -8)}
{phone(shots['pdf'], 820, 2900, 260, 8)}
<div style="position:absolute;left:1097px;top:493px;width:1646px;height:661px;
  display:flex;flex-direction:column;justify-content:center;text-align:center">
  <div style="color:#fff;font-weight:800;font-size:150px;line-height:1.05">{html.escape(l1)}</div>
  <div style="color:#f1c25b;font-weight:800;font-size:150px;line-height:1.15">{html.escape(l2)}</div>
</div></body></html>"""


def search(lang: str, shots: dict[str, str]) -> str:
    *_, head, line = COPY[lang]
    w, h = 1920, 1280
    return f"""<!doctype html><html><head><meta charset="utf-8"></head>
<body style="margin:0;width:{w}px;height:{h}px;overflow:hidden;position:relative;
  background:{BG};font-family:{FONT}">
<div style="position:absolute;left:110px;top:0;width:900px;height:{h}px;
  display:flex;flex-direction:column;justify-content:center">
  <div style="color:#fff;font-weight:800;font-size:104px;line-height:1.08">{html.escape(head)}</div>
  <div style="color:#f1c25b;font-weight:600;font-size:52px;line-height:1.3;margin-top:36px">{html.escape(line)}</div>
</div>
{phone(shots['detect'], 640, 1150, 120, 0)}
</body></html>"""


def main() -> int:
    for lang in COPY:
        d = os.path.join(RAW, lang)
        if not os.path.isdir(d):
            continue
        shots = {f.split("_", 1)[1][:-4]: b64(os.path.join(d, f))
                 for f in os.listdir(d) if f.endswith(".png")}
        for loc in ASC_LOCALES[lang]:
            od = os.path.join(OUT, loc)
            os.makedirs(od, exist_ok=True)
            render(header(lang, shots), 3840, 1646, os.path.join(od, "header_3840x1646.png"))
            render(search(lang, shots), 1920, 1280, os.path.join(od, "search_1920x1280.png"))
        print(lang)
    print(f"Creative assets in {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
