#!/usr/bin/env python3
"""Frame raw simulator captures into App Store screenshots.

    python3 tool/store_capture/frame.py

Reads build/store_capture/raw/<device>/<lang>/NN_<shot>.png (capture.sh) and
writes ios/fastlane/screenshots/<asc-locale>/NN_<shot>_<device>.png, ready for
`fastlane deliver`. Rendering goes through headless Chrome so Devanagari,
Tamil and Telugu captions are shaped properly (Pillow here has no raqm).

Captions are marketing copy: have a native speaker read the hi/ta/te ones
before shipping a change to them.
"""
from __future__ import annotations

import base64
import html
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "build", "store_capture", "raw")
OUT = os.path.join(ROOT, "ios", "fastlane", "screenshots")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Shots in store order: the strongest (auto-detection) first.
SHOTS = ["detect", "fill", "sign", "pdf", "library"]

# Store canvas per simulator, and how big the device sits on it.
DEVICES = {
    "iPhone_17_Pro_Max": dict(size=(1320, 2868), device_w=0.84, radius=0.13),
    "iPad_Pro_13-inch_(M5)": dict(size=(2064, 2752), device_w=0.78, radius=0.035),
}

ASC_LOCALES = {
    "en": ["en-US"],
    "fr": ["fr-FR"],
    "es": ["es-MX", "es-ES"],
    "pt": ["pt-BR"],
    "hi": ["hi"],
    "ta": ["ta-IN"],
    "te": ["te-IN"],
}

CAPTIONS = {
    "en": [
        ("Finds the blanks for you", "Lines, boxes, signature and date spots — detected automatically"),
        ("Tap a field. Fill it in.", "Your name, email and address in a tap"),
        ("Sign with your finger", "Save it once, reuse it on every document"),
        ("Send a finished PDF", "Signed, dated, with a signing certificate"),
        ("Stays on your phone", "No account. No cloud. No subscription."),
    ],
    "fr": [
        ("Trouve les champs à remplir", "Lignes, cases, signature et date — détectées automatiquement"),
        ("Touchez. Remplissez.", "Nom, e-mail et adresse en un geste"),
        ("Signez du bout du doigt", "Enregistrée une fois, réutilisée partout"),
        ("Envoyez un PDF finalisé", "Signé, daté, avec certificat de signature"),
        ("Tout reste sur votre téléphone", "Sans compte. Sans cloud. Sans abonnement."),
    ],
    "es": [
        ("Encuentra los espacios por ti", "Líneas, casillas, firma y fecha — detectadas al instante"),
        ("Toca un campo. Rellénalo.", "Tu nombre, correo y dirección con un toque"),
        ("Firma con el dedo", "Guárdala una vez y úsala en cada documento"),
        ("Envía un PDF terminado", "Firmado, fechado y con certificado de firma"),
        ("Todo se queda en tu teléfono", "Sin cuenta. Sin nube. Sin suscripción."),
    ],
    "pt": [
        ("Encontra os campos para você", "Linhas, caixas, assinatura e data — detectadas na hora"),
        ("Toque no campo. Preencha.", "Nome, e-mail e endereço com um toque"),
        ("Assine com o dedo", "Salve uma vez e use em todo documento"),
        ("Envie um PDF pronto", "Assinado, datado e com certificado de assinatura"),
        # "Sem assinatura" would read as "no signature" — say "no monthly fee".
        ("Tudo fica no seu celular", "Sem conta. Sem nuvem. Sem mensalidade."),
    ],
    "hi": [
        ("खाली जगहें खुद ढूँढता है", "लाइन, बॉक्स, हस्ताक्षर और तारीख — अपने-आप पहचाने"),
        ("फ़ील्ड पर टैप करें, भरें", "नाम, ईमेल और पता एक टैप में"),
        ("उंगली से हस्ताक्षर करें", "एक बार सेव करें, हर दस्तावेज़ में इस्तेमाल करें"),
        ("तैयार PDF भेजें", "हस्ताक्षर, तारीख और हस्ताक्षर प्रमाणपत्र के साथ"),
        ("सब कुछ आपके फ़ोन पर", "न अकाउंट, न क्लाउड, न सब्सक्रिप्शन"),
    ],
    "ta": [
        ("காலி இடங்களைத் தானே கண்டறியும்", "கோடுகள், பெட்டிகள், கையொப்பம், தேதி — தானாகவே"),
        ("தட்டுங்கள், நிரப்புங்கள்", "பெயர், மின்னஞ்சல், முகவரி ஒரே தட்டில்"),
        ("விரலால் கையொப்பமிடுங்கள்", "ஒருமுறை சேமித்து, எல்லா ஆவணங்களிலும் பயன்படுத்துங்கள்"),
        ("முடிந்த PDF-ஐ அனுப்புங்கள்", "கையொப்பம், தேதி, கையொப்பச் சான்றிதழுடன்"),
        ("எல்லாம் உங்கள் போனிலேயே", "கணக்கு இல்லை. கிளவுட் இல்லை. சந்தா இல்லை."),
    ],
    "te": [
        ("ఖాళీలను తానే కనుగొంటుంది", "గీతలు, బాక్స్‌లు, సంతకం, తేదీ — ఆటోమేటిక్‌గా"),
        ("ఫీల్డ్ నొక్కండి, నింపండి", "పేరు, ఇమెయిల్, చిరునామా ఒక్క ట్యాప్‌లో"),
        ("వేలితో సంతకం చేయండి", "ఒకసారి సేవ్ చేసి, ప్రతి పత్రంలో వాడండి"),
        ("పూర్తయిన PDF పంపండి", "సంతకం, తేదీ, సంతకం సర్టిఫికేట్‌తో"),
        ("అంతా మీ ఫోన్‌లోనే", "ఖాతా లేదు. క్లౌడ్ లేదు. సబ్‌స్క్రిప్షన్ లేదు."),
    ],
}

PAGE = """<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;padding:0}}
body{{width:{w}px;height:{h}px;overflow:hidden;position:relative;box-sizing:border-box;
  display:flex;flex-direction:column;align-items:center;padding:{cap_top}px {pad}px {bottom}px;
  background:linear-gradient(170deg,#1c2029 0%,#262a35 48%,#3a3424 78%,#7a5d1c 100%);
  font-family:-apple-system,"SF Pro Display","Helvetica Neue",
    "Kohinoor Devanagari","Tamil Sangam MN","Kohinoor Telugu",sans-serif;}}
.glow{{position:absolute;left:50%;top:{glow_top}px;width:{glow}px;height:{glow}px;
  transform:translateX(-50%);border-radius:50%;z-index:0;
  background:radial-gradient(circle,rgba(236,180,64,.22),rgba(236,180,64,0) 65%)}}
.cap{{text-align:center;z-index:1}}
h1{{margin:0;color:#fff;font-weight:800;font-size:{t}px;line-height:1.08;
  letter-spacing:-.01em}}
p{{margin:{gap}px 0 0;color:#f1c25b;font-weight:600;font-size:{s}px;line-height:1.3}}
/* The device takes whatever height the caption leaves, keeping its shape. */
.slot{{flex:1;min-height:0;width:100%;display:flex;justify-content:center;
  align-items:flex-start;margin-top:{dev_gap}px;z-index:1}}
.dev{{height:100%;max-width:{dw}px;aspect-ratio:{ar};border-radius:{r}px;
  background:#0b0d11;padding:{bz}px;box-sizing:border-box;
  box-shadow:0 {sh}px {sh2}px rgba(0,0,0,.55),0 0 0 {rim}px #3b3f48 inset}}
.dev img{{width:100%;height:100%;display:block;border-radius:{ri}px;object-fit:fill}}
</style></head><body>
<div class="glow"></div>
<div class="cap"><h1>{title}</h1><p>{sub}</p></div>
<div class="slot"><div class="dev"><img src="data:image/png;base64,{img}"></div></div>
</body></html>"""


def render(html_doc: str, w: int, h: int, out: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, "p.html")
        with open(page, "w", encoding="utf-8") as f:
            f.write(html_doc)
        shot = os.path.join(tmp, "s.png")
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             "--force-device-scale-factor=1", f"--window-size={w},{h}",
             f"--screenshot={shot}", f"file://{page}"],
            check=True, capture_output=True)
        # Store screenshots must not carry an alpha channel.
        subprocess.run(["sips", "-s", "format", "jpeg", shot, "--out", shot + ".jpg"],
                       check=True, capture_output=True)
        subprocess.run(["sips", "-s", "format", "png", shot + ".jpg", "--out", out],
                       check=True, capture_output=True)


def frame(device: str, spec: dict, lang: str, raw_dir: str) -> list[str]:
    w, h = spec["size"]
    files = {f.split("_", 1)[1][:-4]: f for f in os.listdir(raw_dir) if f.endswith(".png")}
    made = []
    for n, (shot, (title, sub)) in enumerate(zip(SHOTS, CAPTIONS[lang]), 1):
        if shot not in files:
            print(f"  missing {lang}/{shot}", file=sys.stderr)
            continue
        src = os.path.join(raw_dir, files[shot])
        sw, sh = map(int, subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", src],
            capture_output=True, text=True).stdout.split()[-3::2])
        pad = round(w * 0.07)
        t = round(w * (0.084 if w < h * 0.6 else 0.058))
        s = round(t * 0.5)
        cap_top = round(h * 0.045)
        dw = round(w * spec["device_w"])
        bz = round(dw * 0.022)
        r = round(dw * spec["radius"])
        doc = PAGE.format(
            w=w, h=h, pad=pad, t=t, s=s, gap=round(s * 0.55), cap_top=cap_top,
            bottom=round(h * 0.03), dev_gap=round(h * 0.035),
            ar=f"{sw + 2 * bz} / {sh + 2 * bz}",
            dw=dw, r=r, ri=max(r - bz, 0), bz=bz,
            sh=round(w * 0.02), sh2=round(w * 0.06), rim=max(2, round(w * 0.002)),
            glow=round(w * 1.3), glow_top=round(h * 0.25),
            title=html.escape(title), sub=html.escape(sub),
            img=base64.b64encode(open(src, "rb").read()).decode())
        for loc in ASC_LOCALES[lang]:
            d = os.path.join(OUT, loc)
            os.makedirs(d, exist_ok=True)
            out = os.path.join(d, f"{n:02d}_{shot}_{device}.png")
            if loc == ASC_LOCALES[lang][0]:
                render(doc, w, h, out)
                first = out
            else:
                shutil.copyfile(first, out)
            made.append(out)
    return made


def main() -> int:
    total = 0
    for device, spec in DEVICES.items():
        ddir = os.path.join(RAW, device)
        if not os.path.isdir(ddir):
            continue
        for lang in CAPTIONS:
            ldir = os.path.join(ddir, lang)
            if os.path.isdir(ldir):
                total += len(frame(device, spec, lang, ldir))
                print(f"{device} {lang}")
    print(f"{total} screenshots in {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
