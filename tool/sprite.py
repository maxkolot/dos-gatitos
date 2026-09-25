#!/usr/bin/env python3
"""Make a game sprite PNG (transparent) from an emoji — web builds can miss emoji glyphs, sprites always work.
  python3 tool/sprite.py --emoji "🐟" --out assets/images/fish.png [--size 128] [--tint "#222222"]
--tint recolors the emoji keeping its shading (e.g. a black cat from 🐈). Then load it in Dart:
  SpriteComponent(sprite: await game.loadSprite('fish.png'), size: Vector2.all(48), anchor: Anchor.center)
Any other picture works too: put a PNG into assets/images/ (the folder is already in pubspec.yaml).
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont, ImageOps

EMOJI_FONT = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--emoji', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--size', type=int, default=128)
    p.add_argument('--tint', help='hex color, e.g. #222222')
    a = p.parse_args()

    font = ImageFont.truetype(EMOJI_FONT, 109)  # the only size of the color emoji font; scaled below
    layer = Image.new('RGBA', (160 * (len(a.emoji) + 1), 180), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((10, 20), a.emoji, font=font, embedded_color=True)
    img = layer.crop(layer.getbbox())
    if a.tint:
        gray = ImageOps.grayscale(img)
        tinted = ImageOps.colorize(gray, black=a.tint, white='#5a5a64').convert('RGBA')
        tinted.putalpha(img.split()[3])
        img = tinted
    k = a.size / max(img.size)
    img = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))), Image.LANCZOS)
    out = Image.new('RGBA', (a.size, a.size), (0, 0, 0, 0))
    out.alpha_composite(img, ((a.size - img.width) // 2, (a.size - img.height) // 2))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    out.save(a.out)
    print('sprite written:', a.out)


if __name__ == '__main__':
    main()
