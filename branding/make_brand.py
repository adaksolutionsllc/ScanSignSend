#!/usr/bin/env python3
"""Generate the Scan Sign Send brand assets in the ADAK Ventures identity.

Concept: ADAK's concentric golden triangle mark fused with a document sheet and
a signature stroke — dark radial background, gold gradient stroke with glow.

Palette sampled from branding/adak_ventures_logo_full.png:
  bg near-black      #04030C  →  #0B0B10 (app brand-dark)
  gold deep          #C77A12
  gold core          #FFB300
  gold highlight     #FFD873
  cream (text)       #FBF7EA

Outputs (branding/):
  icon_master.png        1024²  opaque, full mark on dark radial   (iOS + stores)
  icon_foreground.png    1024²  Android adaptive foreground (safe zone), opaque dark
  icon_background.png    1024²  Android adaptive background, dark radial
  logo_wordmark.png      1600×1600 transparent — mark + "SCAN SIGN SEND" wordmark
  play_feature.png       1024×500  Google Play feature graphic
Then run:  dart run flutter_launcher_icons
"""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ── palette ──────────────────────────────────────────────────────────────────
BG_DARK      = (11, 11, 16)      # #0B0B10  app brand-dark
BG_EDGE      = (4, 3, 12)        # #04030C  darkest corner
GOLD_DEEP    = (199, 122, 18)    # #C77A12
GOLD_CORE    = (255, 179, 0)     # #FFB300
GOLD_HI      = (255, 216, 115)   # #FFD873
CREAM        = (251, 247, 234)   # #FBF7EA

SS = 4  # supersample factor


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def radial_bg(size, center_boost=True):
    """Dark radial: brand-dark glow in the middle fading to near-black corners."""
    img = Image.new("RGB", (size, size), BG_EDGE)
    px = img.load()
    cx = cy = size / 2
    maxd = math.hypot(cx, cy)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / maxd
            t = min(1.0, d ** 1.15)
            px[x, y] = lerp(BG_DARK, BG_EDGE, t)
    return img


def _tri_points(cx, cy, r, rot=-90):
    """Equilateral triangle centered at (cx,cy), circumradius r, apex up."""
    pts = []
    for k in range(3):
        a = math.radians(rot + k * 120)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def gold_gradient_stroke(size, draw_fn):
    """Render shape (via draw_fn on a mask) then fill with a vertical gold gradient."""
    mask = Image.new("L", (size, size), 0)
    draw_fn(ImageDraw.Draw(mask))
    grad = Image.new("RGB", (size, size))
    gp = grad.load()
    for y in range(size):
        t = y / size
        if t < 0.5:
            c = lerp(GOLD_HI, GOLD_CORE, t / 0.5)
        else:
            c = lerp(GOLD_CORE, GOLD_DEEP, (t - 0.5) / 0.5)
        for x in range(size):
            gp[x, y] = c
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out, mask


def build_mark(size, scale=0.72, doc=True):
    """The core glyph: rounded document sheet + concentric gold triangles + sign stroke.
    Returns an RGBA layer (transparent) sized `size`."""
    S = size * SS
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = S / 2
    cy = S / 2 + S * 0.05                   # nudge mark down so triangle sits on the page
    R = S * scale / 2                      # outer triangle circumradius
    stroke = max(2, int(S * 0.018))

    # ── document sheet behind the triangle (subtle, folded corner) ──
    if doc:
        dw, dh = R * 1.28, R * 1.62
        dl, dt = cx - dw / 2, cy - dh / 2 + R * 0.02
        fold = dw * 0.26
        sheet = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sheet)
        rad = int(dw * 0.06)
        # page body
        sd.rounded_rectangle([dl, dt, dl + dw, dt + dh], radius=rad,
                             fill=(20, 19, 27, 255))
        # faint gold border
        sd.rounded_rectangle([dl, dt, dl + dw, dt + dh], radius=rad,
                             outline=(*GOLD_DEEP, 90), width=max(1, stroke // 2))
        # folded top-right corner
        sd.polygon([(dl + dw - fold, dt), (dl + dw, dt + fold),
                    (dl + dw - fold, dt + fold)], fill=(*GOLD_DEEP, 70))
        layer.alpha_composite(sheet)

    # ── concentric golden triangles (ADAK signature) ──
    def draw_triangles(d):
        for i, rr in enumerate((R, R * 0.62, R * 0.30)):
            w = stroke if i == 0 else max(1, int(stroke * 0.7))
            d.polygon(_tri_points(cx, cy, rr), outline=255, width=w)
        # apex node dot (from the ADAK logo)
        ax, ay = _tri_points(cx, cy, R)[0]
        rr = stroke * 1.05
        d.ellipse([ax - rr, ay - rr, ax + rr, ay + rr], fill=255)

    tris, tmask = gold_gradient_stroke(S, draw_triangles)

    # glow: blurred copy of the gold mark underneath
    glow_src = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow_src.paste(Image.new("RGB", (S, S), GOLD_CORE), (0, 0), tmask)
    glow = glow_src.filter(ImageFilter.GaussianBlur(S * 0.02))
    glow.putalpha(glow.getchannel("A").point(lambda a: int(a * 0.55)))
    layer.alpha_composite(glow)
    layer.alpha_composite(tris)

    # ── signature stroke sweeping across the base ──
    sig = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sig)
    baseY = cy + R * 0.72
    pts = []
    for i in range(0, 101):
        t = i / 100
        x = cx - R * 0.72 + t * R * 1.44
        y = baseY + math.sin(t * math.pi * 2.1) * R * 0.10 - t * R * 0.04
        pts.append((x, y))
    sd.line(pts, fill=(*CREAM, 235), width=max(2, int(stroke * 0.9)), joint="curve")
    layer.alpha_composite(sig)

    return layer.resize((size, size), Image.LANCZOS)


def make_master():
    size = 1024
    bg = radial_bg(size).convert("RGBA")
    bg.alpha_composite(build_mark(size, scale=0.70))
    bg.convert("RGB").save("branding/icon_master.png")
    print("wrote icon_master.png")


def make_adaptive():
    size = 1024
    # background: dark radial
    radial_bg(size).save("branding/icon_background.png")
    # foreground: mark only, kept inside ~66% adaptive safe zone, opaque dark fill
    fg = Image.new("RGBA", (size, size), (*BG_DARK, 255))
    fg.alpha_composite(build_mark(size, scale=0.50))
    fg.convert("RGB").save("branding/icon_foreground.png")
    print("wrote icon_foreground.png, icon_background.png")


def _font(sz, bold=True):
    paths = [
        "/System/Library/Fonts/Supplemental/Futura.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def _text_centered(d, cx, y, text, font, fill, tracking=0):
    """Draw letter-spaced text centered on cx."""
    widths = [d.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, w in zip(text, widths):
        d.text((x, y), ch, font=font, fill=fill)
        x += w + tracking


def make_wordmark():
    size = 1600
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.alpha_composite(build_mark(size, scale=0.46).transform(
        (size, size), Image.AFFINE, (1, 0, 0, 0, 1, -size * 0.10), resample=Image.BICUBIC))
    d = ImageDraw.Draw(img)
    f1 = _font(int(size * 0.115))
    f2 = _font(int(size * 0.052))
    _text_centered(d, size / 2, int(size * 0.66), "SCAN SIGN SEND", f1, (*CREAM, 255),
                   tracking=size * 0.006)
    _text_centered(d, size / 2, int(size * 0.80), "BY ADAK VENTURES", f2, (*GOLD_CORE, 235),
                   tracking=size * 0.024)
    img.save("branding/logo_wordmark.png")
    print("wrote logo_wordmark.png")


def make_play_feature():
    W, H = 1024, 500
    # wide dark radial
    img = Image.new("RGB", (W, H), BG_EDGE)
    px = img.load()
    cx, cy = W * 0.30, H / 2
    maxd = math.hypot(W, H)
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - cx) * 0.8, y - cy) / maxd
            px[x, y] = lerp(BG_DARK, BG_EDGE, min(1.0, (d * 1.6) ** 1.1))
    img = img.convert("RGBA")
    mark = build_mark(H, scale=0.72)
    img.alpha_composite(mark, (int(W * 0.02), 0))
    d = ImageDraw.Draw(img)
    tx = int(W * 0.42)
    avail = W - tx - int(W * 0.04)

    def fit(text, start, weight=None):
        sz = start
        while sz > 8:
            f = _font(sz)
            if d.textlength(text, font=f) <= avail:
                return f
            sz -= 2
        return _font(8)

    title = "Scan Sign Send"
    f1 = fit(title, int(H * 0.19))
    f2 = fit("Scan · Sign · Send — offline.", int(H * 0.072))
    d.text((tx, int(H * 0.26)), title, font=f1, fill=(*CREAM, 255))
    d.text((tx, int(H * 0.52)), "Scan · Sign · Send — offline.", font=f2, fill=(*GOLD_HI, 235))
    d.text((tx, int(H * 0.64)), "No accounts. No cloud. One-time.", font=f2, fill=(*GOLD_CORE, 210))
    img.convert("RGB").save("branding/play_feature.png")
    print("wrote play_feature.png")


if __name__ == "__main__":
    make_master()
    make_adaptive()
    make_wordmark()
    make_play_feature()
    print("done — now run: dart run flutter_launcher_icons")
