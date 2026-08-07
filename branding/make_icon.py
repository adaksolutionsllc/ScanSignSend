#!/usr/bin/env python3
"""Compose the ScanSignSend app icon from the ADAK Ventures logo.

Outputs (into branding/):
  icon_master.png            1024x1024, opaque dark bg + centered gold triangle (iOS/store)
  icon_foreground.png        1024x1024, transparent bg + triangle (Android adaptive foreground)
  icon_background.png        1024x1024, solid brand-dark (Android adaptive background)
"""
from PIL import Image

SRC = "/Users/arun/Downloads/ADAK Website/uploads/ADAK Ventures Logo.png"
BRAND_DARK = (11, 11, 16, 255)  # near-black with a hint of blue, matches the logo bg

# Region of the triangle in the 900x900 source (measured from the logo).
# Apex ~ (450,150), base spans ~ (285,485)-(615,485). Stop above the "ADAK"
# text (which starts ~y=505) so no letters leak into the icon.
TRI_BOX = (255, 130, 645, 489)  # left, top, right, bottom — stops just above ADAK text (y=495)


def square_crop(src):
    """Crop TRI_BOX and center it on a square transparent tile (no distortion)."""
    tri = src.crop(TRI_BOX)
    w, h = tri.size
    s = max(w, h)
    tile = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    tile.alpha_composite(tri, ((s - w) // 2, (s - h) // 2))
    return tile


def main():
    src = Image.open(SRC).convert("RGBA")
    tri_sq = square_crop(src)  # square, transparent margins

    size = 1024

    # --- Master icon (opaque) ---
    target = int(size * 0.74)
    tri = tri_sq.resize((target, target), Image.LANCZOS)
    master = Image.new("RGBA", (size, size), BRAND_DARK)
    off = (size - target) // 2
    master.alpha_composite(tri, (off, off))
    master.convert("RGB").save("branding/icon_master.png")

    # --- Android adaptive foreground ---
    # The foreground shares the same brand-dark fill as the adaptive background
    # color, so it blends seamlessly with no transparency artifacts. The triangle
    # is kept inside the ~66% adaptive safe zone so launcher masks never clip it.
    fg_target = int(size * 0.56)
    tri_fg = tri_sq.resize((fg_target, fg_target), Image.LANCZOS)
    fg = Image.new("RGBA", (size, size), BRAND_DARK)
    fo = (size - fg_target) // 2
    fg.alpha_composite(tri_fg, (fo, fo))
    fg.convert("RGB").save("branding/icon_foreground.png")

    # --- Android adaptive background (solid) ---
    bg = Image.new("RGBA", (size, size), BRAND_DARK)
    bg.convert("RGB").save("branding/icon_background.png")

    print("Wrote icon_master.png, icon_foreground.png, icon_background.png")


if __name__ == "__main__":
    main()
