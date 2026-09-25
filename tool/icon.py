#!/usr/bin/env python3
"""App icon. The ONLY source is web/icon.png (1024x1024); every size is generated from it at deploy time.

Change the icon with one command, then repo_publish:
  python3 tool/icon.py --emoji "🦁" --bg "#FF8FB1"      emoji on a colored background (several emoji allowed)
  python3 tool/icon.py --svg my_icon.svg                  an SVG you drew (shapes, gradients, text)
  python3 tool/icon.py --image https://example.com/p.png  any picture (URL or file), center-cropped to a square
  python3 tool/icon.py --preview                          writes a 180px iPhone-size preview and prints its path
CI only:
  python3 tool/icon.py --sizes build/web                  all PWA / iPhone sizes + favicon from web/icon.png
"""
import argparse
import io
import os
import subprocess
import sys
import tempfile
import urllib.request

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'web', 'icon.png')
EMOJI_FONT = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'


def square(img):
    img = img.convert('RGBA')
    s = min(img.size)
    left, top = (img.width - s) // 2, (img.height - s) // 2
    return img.crop((left, top, left + s, top + s)).resize((1024, 1024), Image.LANCZOS)


def from_emoji(text, bg):
    font = ImageFont.truetype(EMOJI_FONT, 109)  # the color emoji font only has this size; scaled below
    layer = Image.new('RGBA', (140 * (len(text) + 1), 180), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((10, 20), text, font=font, embedded_color=True)
    layer = layer.crop(layer.getbbox())
    k = 0.72 * 1024 / max(layer.size)
    layer = layer.resize((int(layer.width * k), int(layer.height * k)), Image.LANCZOS)
    img = Image.new('RGBA', (1024, 1024), bg)
    img.alpha_composite(layer, ((1024 - layer.width) // 2, (1024 - layer.height) // 2))
    return img


def from_svg(path):
    out = os.path.join(tempfile.gettempdir(), 'icon-from-svg.png')
    subprocess.run(['rsvg-convert', '-w', '1024', '-h', '1024', '--keep-aspect-ratio', '-o', out, path], check=True)
    return square(Image.open(out))


def from_image(src):
    data = urllib.request.urlopen(src, timeout=30).read() if src.startswith('http') else open(src, 'rb').read()
    return square(Image.open(io.BytesIO(data)))


def sizes(out_dir):
    src = Image.open(SRC).convert('RGBA')
    bg = src.getpixel((4, 4))[:3]  # corner color fills transparent parts and the maskable safe zone
    os.makedirs(os.path.join(out_dir, 'icons'), exist_ok=True)

    def flat(img):
        base = Image.new('RGB', img.size, bg)
        base.paste(img, mask=img.split()[3])
        return base

    def plain(n):
        return flat(src.resize((n, n), Image.LANCZOS))

    def maskable(n):  # Android crops to a circle: keep the art inside the central 80%
        inner = src.resize((int(n * 0.8), int(n * 0.8)), Image.LANCZOS)
        img = Image.new('RGBA', (n, n), bg + (255,))
        img.alpha_composite(inner, ((n - inner.width) // 2, (n - inner.height) // 2))
        return flat(img)

    plain(192).save(os.path.join(out_dir, 'icons', 'Icon-192.png'))
    plain(512).save(os.path.join(out_dir, 'icons', 'Icon-512.png'))
    maskable(192).save(os.path.join(out_dir, 'icons', 'Icon-maskable-192.png'))
    maskable(512).save(os.path.join(out_dir, 'icons', 'Icon-maskable-512.png'))
    plain(180).save(os.path.join(out_dir, 'icons', 'apple-touch-icon.png'))
    plain(64).save(os.path.join(out_dir, 'favicon.png'))
    print('icons written to', out_dir)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument('--emoji')
    g.add_argument('--svg')
    g.add_argument('--image')
    g.add_argument('--sizes', metavar='OUT_DIR')
    g.add_argument('--preview', action='store_true')
    p.add_argument('--bg', default='#1D1B2E', help='background for --emoji')
    a = p.parse_args()
    if a.sizes:
        return sizes(a.sizes)
    if not a.preview:
        img = from_emoji(a.emoji, a.bg) if a.emoji else from_svg(a.svg) if a.svg else from_image(a.image)
        img.convert('RGB').save(SRC)
        print('web/icon.png updated')
    prev = os.path.join(tempfile.gettempdir(), 'icon-preview-180.png')
    Image.open(SRC).convert('RGB').resize((180, 180), Image.LANCZOS).save(prev)
    print('preview:', prev)


if __name__ == '__main__':
    sys.exit(main())
