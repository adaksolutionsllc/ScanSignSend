"""Renders the home-screen quick-action icons from the Material Icons font.

iOS: template images (black glyph, transparent) in Assets.xcassets; the
system tints them. Android: the brand-blue circle with a white glyph, at
each density, since launchers show shortcut icons as drawn.

Usage: python3 tool/quick_actions/make_icons.py <MaterialIcons-Regular.otf>
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = sys.argv[1]
ICONS = {  # resource name -> Material Icons codepoint
    'qa_scan': 0xE1F2,  # document_scanner
    'qa_open': 0xE4C0,  # picture_as_pdf
    'qa_draft': 0xF04F6,  # edit_note
}
BLUE = (0x1A, 0x73, 0xE8, 255)


def glyph(code, size, colour):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    font = ImageFont.truetype(FONT, size)
    ImageDraw.Draw(img).text(
        (size / 2, size / 2), chr(code), font=font, fill=colour, anchor='mm'
    )
    return img


def ios(name, code):
    folder = f'ios/Runner/Assets.xcassets/{name}.imageset'
    os.makedirs(folder, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        file = f'{name}@{scale}x.png'
        glyph(code, 35 * scale, (0, 0, 0, 255)).save(f'{folder}/{file}')
        images.append({'idiom': 'universal', 'filename': file, 'scale': f'{scale}x'})
    with open(f'{folder}/Contents.json', 'w') as f:
        json.dump(
            {
                'images': images,
                'info': {'author': 'xcode', 'version': 1},
                'properties': {'template-rendering-intent': 'template'},
            },
            f,
            indent=2,
        )
        f.write('\n')


def android(name, code):
    for bucket, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        img = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        ImageDraw.Draw(img).ellipse((0, 0, px - 1, px - 1), fill=BLUE)
        g = glyph(code, int(px * 0.55), (255, 255, 255, 255))
        off = (px - g.width) // 2
        img.alpha_composite(g, (off, off))
        img.save(f'android/app/src/main/res/drawable-{bucket}/{name}.png')


for name, code in ICONS.items():
    ios(name, code)
    android(name, code)
print('ok')
