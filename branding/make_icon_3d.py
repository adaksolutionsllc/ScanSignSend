#!/usr/bin/env python3
"""Render the premium 3D launcher icon for Scan Sign Send.

Style brief: a central glossy mark, smooth rounded corners, soft realistic
shadows, vibrant gradient background, claymation + glassmorphism hybrid,
highly detailed, centred, zero text.

The 3D look is *rendered*, not faked with pasted gradients. Every solid shape
becomes a height field (a blurred, domed version of its own alpha mask); the
height field's gradient gives a surface normal; the normal is lit with a
Lambert term plus a Blinn-Phong specular lobe and a rim light. That is what
produces the soft "pressed clay" falloff at the edges and the tight glossy
highlight on top of it.

Layers, back to front:
    1. vibrant gradient background (radial warm glow over a diagonal ramp)
    2. backing sheet, tilted, for depth
    3. main document sheet — clay shaded, soft contact shadow
    4. frosted glass lens over the sheet (glassmorphism: blur-lift, inner
       border highlight, gradient sheen)
    5. scan beam — the "Scan" half of the mark
    6. signature ribbon — the "Sign" half, a glossy 3D tube
    7. global gloss sweep + subtle vignette

Usage:
    python3 branding/make_icon_3d.py                 # render every variant
    python3 branding/make_icon_3d.py --variant aurora --install

`--install` promotes the chosen variant to the files flutter_launcher_icons
reads (icon_master.png / icon_foreground.png / icon_background.png) and the
1024 Play listing icon. Then run:

    dart run flutter_launcher_icons
"""
from __future__ import annotations

import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))

OUT = 1024          # final edge length
SS = 3              # supersample factor
R = OUT * SS        # render edge length


# ── palettes ─────────────────────────────────────────────────────────────────
# Each variant names the whole scene. Colours are 0-255 RGB.
VARIANTS = {
    # Vibrant indigo→violet with a warm bottom-right glow. Keeps ADAK gold as
    # the hero accent on the signature stroke, but the luminous background
    # holds up on dark wallpapers where near-black art disappears.
    "aurora": dict(
        bg_top=(58, 28, 113),
        bg_bottom=(123, 47, 247),
        bg_glow=(255, 138, 61),
        bg_glow_at=(0.78, 0.86),
        bg_glow_strength=0.55,
        sheet=(255, 254, 255),
        sheet_shade=(206, 198, 232),
        beam=(120, 231, 255),
        ribbon=(255, 179, 0),
        ribbon_dark=(199, 110, 12),
        device=(108, 96, 160),
        outline=(236, 240, 255),
    ),
    # Brand-matched: the existing ADAK near-black + gold identity, lifted into
    # 3D. Most consistent with the current store art and wordmark.
    "gold": dict(
        bg_top=(26, 22, 40),
        bg_bottom=(8, 7, 16),
        bg_glow=(255, 179, 0),
        bg_glow_at=(0.72, 0.80),
        bg_glow_strength=0.50,
        sheet=(255, 252, 244),
        sheet_shade=(196, 186, 162),
        beam=(255, 216, 115),
        ribbon=(255, 179, 0),
        ribbon_dark=(160, 88, 8),
        device=(142, 136, 129),
        outline=(255, 246, 226),
    ),
    # Deep teal→emerald with an amber stroke. Reads as "trustworthy utility"
    # and is the most distinct from the blue-heavy scanner-app category.
    "teal": dict(
        bg_top=(6, 78, 90),
        bg_bottom=(10, 158, 130),
        bg_glow=(255, 214, 102),
        bg_glow_at=(0.76, 0.84),
        bg_glow_strength=0.48,
        sheet=(255, 255, 254),
        sheet_shade=(188, 214, 208),
        beam=(186, 255, 236),
        ribbon=(255, 168, 38),
        ribbon_dark=(178, 92, 10),
        device=(76, 118, 124),
        outline=(232, 255, 248),
    ),
}


# ── small numeric helpers ────────────────────────────────────────────────────
def f32(img: Image.Image) -> np.ndarray:
    """PIL → float32 array in 0..1."""
    return np.asarray(img, dtype=np.float32) / 255.0


def to_img(arr: np.ndarray, mode: str = "RGB") -> Image.Image:
    return Image.fromarray(np.clip(arr * 255.0, 0, 255).astype(np.uint8), mode)


def blur(mask: Image.Image, radius: float) -> Image.Image:
    return mask.filter(ImageFilter.GaussianBlur(radius))


def normalize(v: np.ndarray) -> np.ndarray:
    n = np.sqrt((v * v).sum(axis=-1, keepdims=True))
    return v / np.maximum(n, 1e-6)


# ── shape construction ───────────────────────────────────────────────────────
def blank_mask() -> Image.Image:
    return Image.new("L", (R, R), 0)


def rounded_rect(box, radius, rotation=0.0, center=None) -> Image.Image:
    """An antialiased rounded rectangle mask, optionally rotated about center."""
    m = blank_mask()
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    if rotation:
        cx, cy = center or ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2)
        m = m.rotate(rotation, resample=Image.BICUBIC, center=(cx, cy))
    return m


def bezier_points(ctrl, steps=900):
    """Uniformly sampled cubic Bezier chain through a flat control list."""
    pts = []
    for i in range(0, len(ctrl) - 3, 3):
        p0, p1, p2, p3 = ctrl[i:i + 4]
        for s in range(steps):
            t = s / (steps - 1)
            u = 1 - t
            x = (u**3 * p0[0] + 3 * u * u * t * p1[0]
                 + 3 * u * t * t * p2[0] + t**3 * p3[0])
            y = (u**3 * p0[1] + 3 * u * u * t * p1[1]
                 + 3 * u * t * t * p2[1] + t**3 * p3[1])
            pts.append((x, y))
    return pts


def stroke_mask(points, width_fn) -> Image.Image:
    """Variable-width stroke: stamp a disc at each sample. Cheap, and gives the
    tapered calligraphic ends a signature needs."""
    m = blank_mask()
    d = ImageDraw.Draw(m)
    n = len(points)
    for i, (x, y) in enumerate(points):
        w = width_fn(i / (n - 1))
        if w <= 0:
            continue
        d.ellipse([x - w, y - w, x + w, y + w], fill=255)
    return m


# ── lighting ─────────────────────────────────────────────────────────────────
def height_field(mask: Image.Image, soften: float, dome: float = 1.0) -> np.ndarray:
    """Turn an alpha mask into a rounded height field.

    Blurring the mask and re-curving it produces a plateau with a smooth
    shoulder at the border — the geometry that reads as soft moulded clay
    rather than a flat sticker.
    """
    h = f32(blur(mask, soften))
    # sqrt-curve the shoulder so the dome bulges instead of ramping linearly
    return np.power(np.clip(h, 0, 1), 0.5) * dome


def normals_from_height(h: np.ndarray, relief: float) -> np.ndarray:
    gy, gx = np.gradient(h.astype(np.float32))
    n = np.dstack([-gx * relief, -gy * relief, np.ones_like(h)])
    return normalize(n)


def shade(
    base: np.ndarray,
    normals: np.ndarray,
    *,
    light=(-0.45, -0.72, 0.52),
    ambient=0.58,
    diffuse=0.52,
    spec_strength=0.85,
    spec_power=48.0,
    rim_strength=0.0,
    rim_color=(1.0, 1.0, 1.0),
) -> np.ndarray:
    """Lambert + Blinn-Phong over a base albedo."""
    L = np.array(light, dtype=np.float32)
    L /= np.linalg.norm(L)
    V = np.array([0.0, 0.0, 1.0], dtype=np.float32)
    H = (L + V)
    H /= np.linalg.norm(H)

    ndl = np.clip((normals * L).sum(axis=-1), 0, 1)[..., None]
    ndh = np.clip((normals * H).sum(axis=-1), 0, 1)[..., None]

    lit = base * (ambient + diffuse * ndl)
    lit = lit + spec_strength * np.power(ndh, spec_power)

    if rim_strength:
        # Fresnel-ish edge glow: strongest where the surface turns away.
        ndv = np.clip((normals * V).sum(axis=-1), 0, 1)[..., None]
        rim = np.power(1.0 - ndv, 3.0) * rim_strength
        lit = lit + rim * np.array(rim_color, dtype=np.float32)

    return np.clip(lit, 0, 1)


def composite(dst: np.ndarray, src: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    a = alpha[..., None] if alpha.ndim == 2 else alpha
    return dst * (1 - a) + src * a


def drop_shadow(canvas, mask, *, dx, dy, radius, opacity, color=(0, 0, 0)):
    """Soft contact shadow under `mask`, composited into `canvas`."""
    sh = mask.transform(
        mask.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BILINEAR)
    a = f32(blur(sh, radius)) * opacity
    col = np.ones_like(canvas) * np.array(color, dtype=np.float32) / 255.0
    return composite(canvas, col, a)


# ── the scene ────────────────────────────────────────────────────────────────
#
# Every concept shares the background, the lighting rig and the final gloss
# pass; they differ only in the mark they paint in the middle. Each painter
# takes the prepared context and returns (canvas, list-of-shape-masks) — the
# masks are unioned into the Android adaptive foreground cut-out.


def _scene_context(v: dict) -> dict:
    """Background plus the coordinate grids every painter needs."""
    yy, xx = np.mgrid[0:R, 0:R].astype(np.float32)
    u, w = xx / R, yy / R

    t = np.clip((u * 0.45 + w * 0.75), 0, 1)[..., None]
    top = np.array(v["bg_top"], dtype=np.float32) / 255.0
    bot = np.array(v["bg_bottom"], dtype=np.float32) / 255.0
    canvas = top * (1 - t) + bot * t

    gx, gy = v["bg_glow_at"]
    d = np.sqrt((u - gx) ** 2 + (w - gy) ** 2)
    canvas = np.clip(
        canvas + np.exp(-(d / 0.42) ** 2)[..., None] * v["bg_glow_strength"]
        * (np.array(v["bg_glow"], dtype=np.float32) / 255.0), 0, 1)

    d2 = np.sqrt((u - 0.18) ** 2 + (w - 0.12) ** 2)
    canvas = np.clip(canvas + np.exp(-(d2 / 0.38) ** 2)[..., None] * 0.16, 0, 1)

    return {"canvas": canvas, "u": u, "w": w, "yy": yy, "xx": xx}


def _finish(canvas: np.ndarray, u: np.ndarray, w: np.ndarray) -> np.ndarray:
    """Global gloss sweep + vignette, applied after the mark."""
    sweep = np.clip(1.0 - np.abs((u * 0.55 + w * 0.85) - 0.30) / 0.42, 0, 1)
    canvas = np.clip(canvas + (sweep ** 3)[..., None] * 0.080, 0, 1)
    rad = np.sqrt((u - 0.5) ** 2 + (w - 0.5) ** 2) / 0.72
    return np.clip(
        canvas * (1.0 - np.clip(rad, 0, 1)[..., None] ** 2.6 * 0.30), 0, 1)


def _clay(canvas, mask, colour, *, soften, relief, ambient=0.60, diffuse=0.46,
          spec=0.55, power=64, rim=0.20, rim_color=(1.0, 1.0, 1.0),
          albedo_grad=None):
    """Shade a mask as a moulded clay solid and composite it in."""
    n = normals_from_height(height_field(mask, soften), relief=relief)
    base = np.ones((R, R, 3), np.float32) * (
        np.array(colour, np.float32) / 255.0)
    if albedo_grad is not None:
        base = base * albedo_grad
    lit = shade(base, n, ambient=ambient, diffuse=diffuse,
                spec_strength=spec, spec_power=power, rim_strength=rim,
                rim_color=rim_color)
    return composite(canvas, lit, f32(mask))


def _edge_light(canvas, mask, colour, *, inner=0.0030, outer=0.0105,
                strength=0.95, u=None, w=None):
    """Crisp accent along a shape's own border, brightest on the lit side.

    Clipped to the mask so the light never bleeds outside the silhouette —
    that bleed is what made the Fresnel rim read as a fuzzy amber halo.
    """
    edge = np.clip(f32(blur(mask, inner * R)) - f32(blur(mask, outer * R)), 0, 1)
    edge = edge * f32(mask)
    if u is not None:
        # Strong on the upper-left where the key light is, a faint bounce
        # opposite it, so the shell reads as a solid with a lit rim.
        facing = np.clip(1.0 - (u * 0.5 + w * 0.5), 0, 1)
        edge = edge * (0.25 + 0.75 * facing)
    col = np.array(colour, np.float32) / 255.0
    return np.clip(canvas + edge[..., None] * col * strength, 0, 1)


def _outline_light(canvas, masks, v, *, tight=0.0024, glow=0.014,
                   tight_strength=0.52, glow_strength=0.11):
    """A defining light hugging the *outside* of the combined silhouette.

    A lighter shell has less value break against the background, so the mark's
    outer border stops carrying itself at small sizes. This adds it back: a
    narrow bright outline for definition plus a wider, weaker bloom so the
    outline doesn't read as a sticker cut-out.

    `blur(mask) - mask` is ~0 inside the shape, so both bands fall entirely
    outside it and no interior detail is touched.
    """
    union = np.clip(np.maximum.reduce([f32(m) for m in masks]), 0, 1)
    union_img = Image.fromarray((union * 255).astype(np.uint8), "L")

    edge = np.clip(f32(blur(union_img, tight * R)) - union, 0, 1)
    bloom = np.clip(f32(blur(union_img, glow * R)) - union, 0, 1)

    line_col = np.array(v["outline"], np.float32) / 255.0
    glow_col = np.array(v["beam"], np.float32) / 255.0
    canvas = canvas + edge[..., None] * line_col * tight_strength
    canvas = canvas + bloom[..., None] * glow_col * glow_strength

    # Hand back silhouette-plus-outline as a mask. The outline is painted
    # *outside* the shapes, so if it isn't folded into the mark alpha the
    # Android adaptive cut-out clips it off and the adaptive icon loses the
    # definition the outline exists to provide.
    halo = Image.fromarray(
        (np.clip(union + edge, 0, 1) * 255).astype(np.uint8), "L")
    return np.clip(canvas, 0, 1), halo


def _signature(canvas, cx, cy, half_w, v, *, thickness=0.0195):
    """The gold pen stroke — the "Sign" third of the name. Returns (canvas, mask)."""
    pts = bezier_points([
        (cx - half_w, cy + R * 0.026),
        (cx - half_w * 0.58, cy - R * 0.062),
        (cx - half_w * 0.24, cy + R * 0.070),
        (cx + R * 0.004, cy - R * 0.004),
        (cx + half_w * 0.30, cy - R * 0.062),
        (cx + half_w * 0.60, cy + R * 0.072),
        (cx + half_w, cy - R * 0.036),
    ])
    ribbon = stroke_mask(
        pts, lambda t: R * thickness * math.sin(math.pi * min(max(t, 0.0), 1.0)) ** 0.50)
    canvas = drop_shadow(canvas, ribbon, dx=0, dy=R * 0.009,
                         radius=R * 0.015, opacity=0.36)
    h = height_field(ribbon, R * 0.009)
    n = normals_from_height(h, relief=R * 1.15)
    col = np.array(v["ribbon"], np.float32) / 255.0
    dark = np.array(v["ribbon_dark"], np.float32) / 255.0
    mix = np.clip(h, 0, 1)[..., None]
    lit = shade(dark * (1 - mix) + col * mix, n, ambient=0.55, diffuse=0.55,
                spec_strength=1.00, spec_power=54, rim_strength=0.30,
                rim_color=(1.0, 0.92, 0.70))
    return composite(canvas, lit, f32(ribbon)), ribbon


def _light_bar(canvas, box, radius, v, *, halo=0.032, strength=0.60):
    """A glowing scan bar sitting inside its own halo. Returns (canvas, mask)."""
    bar = rounded_rect(box, radius)
    col = np.array(v["beam"], np.float32) / 255.0
    # Two-stage bloom: a wide soft falloff plus a tight one, so the glow reads
    # as light spilling out of the slot instead of a flat coloured band.
    canvas = np.clip(
        canvas + f32(blur(bar, halo * R))[..., None] * col * strength, 0, 1)
    canvas = np.clip(
        canvas + f32(blur(bar, halo * R * 0.35))[..., None] * col * strength * 0.8,
        0, 1)
    # The core runs hot toward white, the way a real emitter clips.
    hot = np.clip(col * 0.45 + 0.55, 0, 1)
    n = normals_from_height(height_field(bar, R * 0.005), relief=R * 0.6)
    lit = shade(np.ones((R, R, 3), np.float32) * hot, n, ambient=0.92,
                diffuse=0.16, spec_strength=0.7, spec_power=80)
    return composite(canvas, lit, f32(bar)), bar


# ── the scene ────────────────────────────────────────────────────────────────
def _mark_sheet(v: dict, ctx=None):
    """Returns (icon RGB at OUT×OUT, mark alpha at OUT×OUT).

    The alpha is the union of the mark's own shapes — no background,
    no cast shadows — which is exactly what Android's adaptive
    foreground layer needs (the launcher supplies its own elevation
    shadow and masks the corners itself).
    """
    yy, xx = np.mgrid[0:R, 0:R].astype(np.float32)
    u, w = xx / R, yy / R

    # 1 ─ background: diagonal ramp + radial warm glow ------------------------
    t = np.clip((u * 0.45 + w * 0.75), 0, 1)[..., None]
    top = np.array(v["bg_top"], dtype=np.float32) / 255.0
    bot = np.array(v["bg_bottom"], dtype=np.float32) / 255.0
    canvas = top * (1 - t) + bot * t

    gx, gy = v["bg_glow_at"]
    d = np.sqrt((u - gx) ** 2 + (w - gy) ** 2)
    glow = np.exp(-(d / 0.42) ** 2)[..., None] * v["bg_glow_strength"]
    canvas = np.clip(
        canvas + glow * (np.array(v["bg_glow"], dtype=np.float32) / 255.0), 0, 1)

    # a second, tighter cool glow top-left keeps the gradient from going flat
    d2 = np.sqrt((u - 0.18) ** 2 + (w - 0.12) ** 2)
    canvas = np.clip(canvas + np.exp(-(d2 / 0.38) ** 2)[..., None] * 0.16, 0, 1)

    # ── geometry ─────────────────────────────────────────────────────────────
    # A portrait document sheet, centred, filling ~2/3 of the canvas. Paper
    # proportions (w/h ≈ 0.77) are what make the silhouette read as a document
    # at launcher size rather than as an abstract blob.
    cx = cy = R / 2
    sheet_w, sheet_h = R * 0.498, R * 0.646
    sheet_box = (cx - sheet_w / 2, cy - sheet_h / 2,
                 cx + sheet_w / 2, cy + sheet_h / 2)
    corner = R * 0.070

    # 2 ─ backing sheet: one page peeking out behind, up and to the right -----
    back = rounded_rect(
        (sheet_box[0] + R * 0.026, sheet_box[1] - R * 0.022,
         sheet_box[2] + R * 0.026, sheet_box[3] - R * 0.022),
        corner, rotation=-5.0, center=(cx, cy))
    canvas = drop_shadow(canvas, back, dx=R * 0.010, dy=R * 0.024,
                         radius=R * 0.034, opacity=0.38)
    back_n = normals_from_height(height_field(back, R * 0.016), relief=R * 0.55)
    # Paper sitting in the front sheet's shadow — mostly sheet colour, not the
    # flat grey that made it read as a smudge behind the mark.
    back_albedo = np.ones((R, R, 3), np.float32) * (
        (np.array(v["sheet"], np.float32) * 0.72
         + np.array(v["sheet_shade"], np.float32) * 0.28) / 255.0)
    canvas = composite(
        canvas,
        shade(back_albedo, back_n, ambient=0.50, diffuse=0.38,
              spec_strength=0.26, spec_power=40),
        f32(back))

    # 3 ─ main document sheet, clay shaded ------------------------------------
    sheet = rounded_rect(sheet_box, corner)
    sheet_a = f32(sheet)
    canvas = drop_shadow(canvas, sheet, dx=0, dy=R * 0.030,
                         radius=R * 0.044, opacity=0.48)

    sheet_n = normals_from_height(height_field(sheet, R * 0.024), relief=R * 0.62)
    grad = (1.0 - (w - 0.25) * 0.22)[..., None]
    sheet_albedo = (np.ones((R, R, 3), np.float32)
                    * (np.array(v["sheet"], np.float32) / 255.0)) * grad
    canvas = composite(
        canvas,
        shade(sheet_albedo, sheet_n, ambient=0.62, diffuse=0.46,
              spec_strength=0.55, spec_power=64, rim_strength=0.22),
        sheet_a)

    # 4 ─ glassmorphism: a frosted band CLIPPED TO THE SHEET -------------------
    # Clipping matters: an unclipped panel produces rounded "ears" either side
    # of the sheet and destroys the document silhouette.
    band_top = sheet_box[1] + R * 0.150
    lens = rounded_rect(
        (sheet_box[0] - R * 0.02, band_top,
         sheet_box[2] + R * 0.02, band_top + R * 0.214),
        R * 0.040)
    # Feather the horizontal edges: a hard-edged frost panel reads as a printing
    # artefact banded across the page, not as glass laid over it.
    span = R * 0.214
    fade = R * 0.055
    vy = yy - band_top
    feather = np.clip(np.minimum(vy, span - vy) / fade, 0, 1)
    feather = feather * feather * (3 - 2 * feather)          # smoothstep
    lens_a = f32(lens) * sheet_a * feather

    frosted = f32(to_img(canvas).filter(ImageFilter.GaussianBlur(R * 0.022)))
    frosted = np.clip(frosted * 1.05 + 0.09, 0, 1)
    canvas = composite(canvas, frosted, lens_a * 0.78)

    # glass border: bright hairline up-left, dim down-right
    edge = np.clip(f32(blur(lens, R * 0.0035)) - f32(blur(lens, R * 0.0110)), 0, 1)
    edge = edge * sheet_a
    lit_edge = np.clip(1.0 - (u * 0.5 + w * 0.5), 0, 1)[..., None]
    canvas = composite(canvas, np.ones_like(canvas),
                       edge[..., None] * lit_edge * 0.80)
    canvas = composite(canvas, np.zeros_like(canvas),
                       edge[..., None] * (1 - lit_edge) * 0.20)

    # diagonal sheen across the glass
    band = np.clip(1.0 - np.abs((u * 0.72 + w * 0.68) - 0.60) / 0.16, 0, 1)
    canvas = composite(canvas, np.ones_like(canvas),
                       (band ** 2)[..., None] * lens_a[..., None] * 0.20)

    # 5 ─ scan beam: the "Scan" half of the mark ------------------------------
    beam_y = band_top + R * 0.107          # centred in the glass band
    beam = rounded_rect(
        (sheet_box[0] - R * 0.018, beam_y - R * 0.0130,
         sheet_box[2] + R * 0.018, beam_y + R * 0.0130),
        R * 0.0130)
    beam_col = np.array(v["beam"], np.float32) / 255.0

    halo = f32(blur(beam, R * 0.032))
    canvas = np.clip(canvas + halo[..., None] * beam_col * 0.60, 0, 1)

    beam_n = normals_from_height(height_field(beam, R * 0.008), relief=R * 0.75)
    canvas = composite(
        canvas,
        shade(np.ones_like(canvas) * beam_col, beam_n, ambient=0.78,
              diffuse=0.30, spec_strength=0.90, spec_power=70),
        f32(beam))

    # 6 ─ corner brackets, inset well clear of the beam and the signature -----
    ticks = blank_mask()
    td = ImageDraw.Draw(ticks)
    arm, thick = R * 0.048, R * 0.0115
    inset_x, inset_y = R * 0.052, R * 0.048
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        ax = sheet_box[0] + inset_x if sx > 0 else sheet_box[2] - inset_x
        ay = sheet_box[1] + inset_y if sy > 0 else sheet_box[3] - inset_y
        td.rounded_rectangle(
            [min(ax, ax + sx * arm) - thick / 2, ay - thick / 2,
             max(ax, ax + sx * arm) + thick / 2, ay + thick / 2],
            radius=thick / 2, fill=255)
        td.rounded_rectangle(
            [ax - thick / 2, min(ay, ay + sy * arm) - thick / 2,
             ax + thick / 2, max(ay, ay + sy * arm) + thick / 2],
            radius=thick / 2, fill=255)
    tick_col = np.array(v["ribbon"], np.float32) / 255.0
    tick_n = normals_from_height(height_field(ticks, R * 0.006), relief=R * 0.8)
    canvas = composite(
        canvas,
        shade(np.ones_like(canvas) * tick_col, tick_n, ambient=0.76,
              diffuse=0.34, spec_strength=0.70, spec_power=60),
        f32(ticks) * 0.90)

    # 7 ─ signature ribbon: the "Sign" half, a glossy 3D tube -----------------
    sig_y = sheet_box[3] - R * 0.150       # sits in the sheet's lower third
    sig = bezier_points([
        (cx - R * 0.168, sig_y + R * 0.028),
        (cx - R * 0.098, sig_y - R * 0.072),
        (cx - R * 0.040, sig_y + R * 0.080),
        (cx + R * 0.006, sig_y - R * 0.004),
        (cx + R * 0.050, sig_y - R * 0.072),
        (cx + R * 0.100, sig_y + R * 0.082),
        (cx + R * 0.180, sig_y - R * 0.040),
    ])

    def sig_width(t: float) -> float:
        # thick through the middle, tapering to fine points like a pen stroke
        return R * 0.0210 * math.sin(math.pi * min(max(t, 0.0), 1.0)) ** 0.50

    ribbon = stroke_mask(sig, sig_width)

    canvas = drop_shadow(canvas, ribbon, dx=0, dy=R * 0.011,
                         radius=R * 0.017, opacity=0.38)

    rib_h = height_field(ribbon, R * 0.010)
    rib_n = normals_from_height(rib_h, relief=R * 1.15)
    rib_col = np.array(v["ribbon"], np.float32) / 255.0
    rib_dark = np.array(v["ribbon_dark"], np.float32) / 255.0
    mix = np.clip(rib_h, 0, 1)[..., None]
    canvas = composite(
        canvas,
        shade(rib_dark * (1 - mix) + rib_col * mix, rib_n, ambient=0.55,
              diffuse=0.55, spec_strength=1.00, spec_power=54,
              rim_strength=0.30, rim_color=(1.0, 0.92, 0.70)),
        f32(ribbon))

    # 8 ─ global gloss sweep + vignette ---------------------------------------
    sweep = np.clip(1.0 - np.abs((u * 0.55 + w * 0.85) - 0.30) / 0.42, 0, 1)
    canvas = np.clip(canvas + (sweep ** 3)[..., None] * 0.080, 0, 1)

    rad = np.sqrt((u - 0.5) ** 2 + (w - 0.5) ** 2) / 0.72
    canvas = np.clip(canvas * (1.0 - np.clip(rad, 0, 1)[..., None] ** 2.6 * 0.30),
                     0, 1)

    # Union of the mark's shapes, for the adaptive foreground cut-out.
    mark = np.clip(
        np.maximum.reduce([f32(back), sheet_a, f32(beam), f32(ticks),
                           f32(ribbon)]), 0, 1)

    icon = to_img(canvas).resize((OUT, OUT), Image.LANCZOS)
    alpha = Image.fromarray((mark * 255).astype(np.uint8), "L") \
        .resize((OUT, OUT), Image.LANCZOS)
    return icon, alpha




# ── concept: scanner — a signed page rising out of a lit slot ────────────────
def _mark_scanner(v: dict, ctx: dict):
    canvas, u, w = ctx["canvas"], ctx["u"], ctx["w"]
    cx = cy = R / 2
    masks = []
    gold = np.array(v["ribbon"], np.float32) / 255.0

    body_top = cy + R * 0.070
    body = rounded_rect(
        (cx - R * 0.310, body_top, cx + R * 0.310, body_top + R * 0.286),
        R * 0.064)

    # The page is drawn first so the shell occludes its base — that overlap is
    # what makes it read as passing *through* the device rather than sitting in
    # front of it.
    page_top = cy - R * 0.336
    page = rounded_rect(
        (cx - R * 0.224, page_top, cx + R * 0.224, body_top + R * 0.080),
        R * 0.030)
    canvas = drop_shadow(canvas, page, dx=0, dy=R * 0.016,
                         radius=R * 0.030, opacity=0.42)
    grad = (1.0 - (w - 0.18) * 0.22)[..., None]
    canvas = _clay(canvas, page, v["sheet"], soften=R * 0.015, relief=R * 0.60,
                   albedo_grad=grad)
    masks.append(page)

    canvas, sig = _signature(canvas, cx, page_top + R * 0.176, R * 0.146, v,
                             thickness=0.0178)
    masks.append(sig)

    # Dark shell, edge-lit in the accent colour. A light-on-light device blends
    # into the page; the value break is what separates them at 48px.
    canvas = drop_shadow(canvas, body, dx=0, dy=R * 0.030,
                         radius=R * 0.046, opacity=0.55)
    shell_grad = (1.0 - (w - 0.52) * 0.30)[..., None]
    canvas = _clay(canvas, body, v["device"], soften=R * 0.024, relief=R * 0.70,
                   ambient=0.54, diffuse=0.50, spec=0.46, power=48, rim=0.08,
                   albedo_grad=shell_grad)
    canvas = _edge_light(canvas, body, v["ribbon"], u=u, w=w, strength=0.55)
    masks.append(body)

    # Slot: a recess cut into the shell, with the scan light inside it.
    slot = rounded_rect(
        (cx - R * 0.244, body_top + R * 0.036,
         cx + R * 0.244, body_top + R * 0.086), R * 0.025)
    canvas = composite(canvas, np.zeros_like(canvas), f32(slot) * 0.48)
    masks.append(slot)

    canvas, bar = _light_bar(
        canvas,
        (cx - R * 0.210, body_top + R * 0.055,
         cx + R * 0.210, body_top + R * 0.067),
        R * 0.006, v, halo=0.024, strength=0.50)
    masks.append(bar)

    # Status pip, low on the shell face.
    pip = rounded_rect(
        (cx + R * 0.212, body_top + R * 0.192,
         cx + R * 0.248, body_top + R * 0.228), R * 0.018)
    canvas = _clay(canvas, pip, v["ribbon"], soften=R * 0.006, relief=R * 0.9,
                   ambient=0.82, diffuse=0.28, spec=0.8, power=60, rim=0.0)
    masks.append(pip)

    canvas, halo = _outline_light(canvas, masks, v)
    masks.append(halo)
    return _finish(canvas, u, w), masks


# ── concept: printer — a signed page feeding out of a front tray ─────────────
def _mark_printer(v: dict, ctx: dict):
    canvas, u, w = ctx["canvas"], ctx["u"], ctx["w"]
    cx = cy = R / 2
    masks = []
    gold = np.array(v["ribbon"], np.float32) / 255.0

    # Blank stock in the top feed — cream, not grey, so it reads as paper
    # rather than as a smudge behind the device.
    feed = rounded_rect(
        (cx - R * 0.196, cy - R * 0.308, cx + R * 0.196, cy - R * 0.160),
        R * 0.026)
    canvas = drop_shadow(canvas, feed, dx=0, dy=R * 0.012,
                         radius=R * 0.024, opacity=0.38)
    canvas = _clay(canvas, feed, v["sheet"], soften=R * 0.013, relief=R * 0.55,
                   ambient=0.50, diffuse=0.40, spec=0.34, power=48, rim=0.14,
                   albedo_grad=np.full((R, R, 1), 0.86, np.float32))
    masks.append(feed)

    body_top = cy - R * 0.202
    body = rounded_rect(
        (cx - R * 0.302, body_top, cx + R * 0.302, body_top + R * 0.282),
        R * 0.066)
    canvas = drop_shadow(canvas, body, dx=0, dy=R * 0.028,
                         radius=R * 0.044, opacity=0.52)
    shell_grad = (1.0 - (w - 0.30) * 0.30)[..., None]
    canvas = _clay(canvas, body, v["device"], soften=R * 0.026, relief=R * 0.70,
                   ambient=0.54, diffuse=0.50, spec=0.46, power=48, rim=0.08,
                   albedo_grad=shell_grad)
    canvas = _edge_light(canvas, body, v["ribbon"], u=u, w=w, strength=0.55)
    masks.append(body)

    # Output slit, lit from inside.
    slot_y = body_top + R * 0.196
    slot = rounded_rect(
        (cx - R * 0.246, slot_y, cx + R * 0.246, slot_y + R * 0.050),
        R * 0.025)
    canvas = composite(canvas, np.zeros_like(canvas), f32(slot) * 0.48)
    masks.append(slot)

    canvas, bar = _light_bar(
        canvas,
        (cx - R * 0.228, slot_y + R * 0.019,
         cx + R * 0.228, slot_y + R * 0.031),
        R * 0.006, v, halo=0.022, strength=0.46)
    masks.append(bar)

    # Status pip on the shell's upper face, mirroring the scanner concept.
    pip = rounded_rect(
        (cx + R * 0.206, body_top + R * 0.056,
         cx + R * 0.242, body_top + R * 0.092), R * 0.018)
    canvas = _clay(canvas, pip, v["ribbon"], soften=R * 0.006, relief=R * 0.9,
                   ambient=0.82, diffuse=0.28, spec=0.8, power=60, rim=0.0)
    masks.append(pip)

    # The signed sheet feeding out — centred under the shell, barely tilted, so
    # the whole mark keeps one clean silhouette.
    out_top = slot_y + R * 0.026
    page = rounded_rect(
        (cx - R * 0.262, out_top, cx + R * 0.262, out_top + R * 0.270),
        R * 0.028)
    canvas = drop_shadow(canvas, page, dx=0, dy=R * 0.014,
                         radius=R * 0.028, opacity=0.46)
    grad = (1.0 - (w - 0.55) * 0.16)[..., None]
    canvas = _clay(canvas, page, v["sheet"], soften=R * 0.014, relief=R * 0.58,
                   albedo_grad=grad)
    masks.append(page)

    canvas, sig = _signature(canvas, cx, out_top + R * 0.164, R * 0.170, v,
                             thickness=0.0180)
    masks.append(sig)

    canvas, halo = _outline_light(canvas, masks, v)
    masks.append(halo)
    return _finish(canvas, u, w), masks


CONCEPTS = {
    "sheet": _mark_sheet,
    "scanner": _mark_scanner,
    "printer": _mark_printer,
}


def render(v: dict, concept: str = "sheet"):
    """Returns (icon RGB at OUT x OUT, mark alpha at OUT x OUT)."""
    painter = CONCEPTS[concept]
    if concept == "sheet":
        return painter(v)          # legacy painter builds its own scene
    ctx = _scene_context(v)
    canvas, masks = painter(v, ctx)
    mark = np.clip(np.maximum.reduce([f32(m) for m in masks]), 0, 1)
    icon = to_img(canvas).resize((OUT, OUT), Image.LANCZOS)
    alpha = Image.fromarray((mark * 255).astype(np.uint8), "L") \
        .resize((OUT, OUT), Image.LANCZOS)
    return icon, alpha


# ── android adaptive pieces ──────────────────────────────────────────────────
def adaptive_pair(v: dict, full: Image.Image, mark_alpha: Image.Image):
    """Android draws the foreground inside a 66% safe zone and masks the rest,
    so the mark has to be re-rendered smaller rather than cropped."""
    bg = Image.new("RGB", (OUT, OUT))
    yy, xx = np.mgrid[0:OUT, 0:OUT].astype(np.float32)
    u, w = xx / OUT, yy / OUT
    t = np.clip((u * 0.45 + w * 0.75), 0, 1)[..., None]
    top = np.array(v["bg_top"], np.float32) / 255.0
    bot = np.array(v["bg_bottom"], np.float32) / 255.0
    arr = top * (1 - t) + bot * t
    gx, gy = v["bg_glow_at"]
    d = np.sqrt((u - gx) ** 2 + (w - gy) ** 2)
    arr = np.clip(
        arr + np.exp(-(d / 0.42) ** 2)[..., None] * v["bg_glow_strength"]
        * (np.array(v["bg_glow"], np.float32) / 255.0), 0, 1)
    bg = to_img(arr)

    # foreground: the mark alone, on transparency, scaled into the safe zone.
    # Android masks the outer ~33% away, so the art has to be re-scaled rather
    # than cropped — and it must not carry its own background, or the adaptive
    # icon shows an opaque square instead of the mark.
    cut = full.convert("RGBA")
    cut.putalpha(mark_alpha)
    # Size the *mark*, not the frame it was rendered in — the mark only fills
    # ~55% of that frame, so scaling the frame leaves the art looking shrunken.
    # Crop to the mark's real bounds, then pre-compensate for the extra 16%
    # inset flutter_launcher_icons writes into ic_launcher.xml: the foreground
    # is drawn at 68% of the canvas, so a mark spanning FILL of this PNG lands
    # at FILL × 0.68 of the icon. Target 0.58 of the canvas, comfortably inside
    # Android's 66% safe zone and visually matched to the iOS tile.
    XML_INSET = 0.16
    TARGET_ON_CANVAS = 0.58
    fill = TARGET_ON_CANVAS / (1.0 - 2 * XML_INSET)

    bbox = mark_alpha.getbbox()
    cut = cut.crop(bbox)
    span = max(cut.width, cut.height)
    k = (fill * OUT) / span
    inner = cut.resize((max(1, round(cut.width * k)),
                        max(1, round(cut.height * k))), Image.LANCZOS)

    fg = Image.new("RGBA", (OUT, OUT), (0, 0, 0, 0))
    fg.paste(inner, ((OUT - inner.width) // 2, (OUT - inner.height) // 2), inner)
    return bg, fg


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=sorted(VARIANTS) + ["all"],
                    default="all")
    ap.add_argument("--concept", choices=sorted(CONCEPTS) + ["all"],
                    default="sheet",
                    help="which mark to draw: sheet (document), scanner "
                         "(page out of a lit slot), printer (page feeding out)")
    ap.add_argument("--install", action="store_true",
                    help="promote this variant to the flutter_launcher_icons "
                         "source files")
    args = ap.parse_args()

    names = sorted(VARIANTS) if args.variant == "all" else [args.variant]
    concepts = sorted(CONCEPTS) if args.concept == "all" else [args.concept]
    rendered = {}
    for name in names:
        for concept in concepts:
            key = name if concept == "sheet" else f"{name}_{concept}"
            print(f"rendering {name}/{concept} at {R}×{R} → {OUT}×{OUT} …")
            img, alpha = render(VARIANTS[name], concept)
            path = os.path.join(HERE, f"icon_3d_{key}.png")
            img.save(path)
            rendered[key] = (img, alpha)
            print(f"  wrote {path}")
    names = list(rendered)

    if len(rendered) > 1:
        sheet = Image.new("RGB", (OUT * len(rendered), OUT), (14, 14, 18))
        for i, name in enumerate(names):
            sheet.paste(rendered[name][0], (OUT * i, 0))
        cmp_path = os.path.join(HERE, "icon_3d_variants.png")
        sheet.resize((512 * len(rendered), 512), Image.LANCZOS).save(cmp_path)
        print(f"  wrote {cmp_path}")

    if args.install:
        if args.variant == "all" or args.concept == "all":
            raise SystemExit("--install needs a single --variant and --concept")
        v = VARIANTS[args.variant]
        key = (args.variant if args.concept == "sheet"
               else f"{args.variant}_{args.concept}")
        img, alpha = rendered[key]
        img.save(os.path.join(HERE, "icon_master.png"))
        # Play's listing icon slot is 512×512 exactly.
        img.resize((512, 512), Image.LANCZOS).save(
            os.path.join(HERE, "play_store_icon_512.png"))
        bg, fg = adaptive_pair(v, img, alpha)
        bg.save(os.path.join(HERE, "icon_background.png"))
        fg.save(os.path.join(HERE, "icon_foreground.png"))
        print("installed → icon_master / icon_background / icon_foreground / "
              "play_store_icon_512")
        print("next: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
