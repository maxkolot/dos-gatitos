#!/usr/bin/env python3
"""Turn a batch of generated animation frames into game assets.

  python3 tool/prep_anim.py --name dance --out assets/characters/sebastian/anim --fps 6 --loop FRAME1.png FRAME2.png ...
  python3 tool/prep_anim.py --name toast --out assets/characters/duo/anim --duo --align --fps 3 FRAMES...
  python3 tool/prep_anim.py --name cushions --out assets/characters/duo/anim --duo --align --ref-scale 1.63 --fps 0.7 --loop FRAMES...

Every frame gets the SAME crop (the union of all frames), so nothing jumps between frames, and is scaled so the
character is ~1000 px tall. Next to the frames goes <name>.json with where the character stands in the frame
(feetY, centerX), how tall a STANDING character is at this scale (refHeight) and where the head is in every frame
(heads; for --duo: duoHeads = [left head, right head] per frame). The game uses it to put the frame exactly where
the idle sprites stand and to keep the name tags on the heads.

--align      frames generated one by one drift and change zoom: crop each to its content, bring all to the same
             height and stand them on the same feet line, centred.
--duo        both characters in the frame (drawn between their spots, both idle sprites hidden meanwhile).
--ref-scale  standing height / frame content height (1.0 for standing poses; sitting pairs ≈ 1.6: measured by head size).
"""
import argparse
import json
import os
import re
from collections import deque
from statistics import median

from PIL import Image

TARGET_HEIGHT = 1000


def person_component(im):
    """The tallest opaque blob of the first frame = the character (props are separate blobs)."""
    small = im.getchannel('A').resize((im.width // 4, im.height // 4))
    w, h = small.size
    px = small.load()
    seen = bytearray(w * h)
    best = None
    for y in range(h):
        for x in range(w):
            if seen[y * w + x] or px[x, y] < 128:
                continue
            q, comp = deque([(x, y)]), []
            seen[y * w + x] = 1
            while q:
                cx, cy = q.popleft()
                comp.append((cx, cy))
                for nx in (cx - 1, cx, cx + 1):
                    for ny in (cy - 1, cy, cy + 1):
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny] >= 128:
                            seen[ny * w + nx] = 1
                            q.append((nx, ny))
            ys = [p[1] for p in comp]
            tall = max(ys) - min(ys)
            if best is None or tall > best[0]:
                best = (tall, comp)
    comp = best[1]
    top = min(p[1] for p in comp) * 4
    feet = (max(p[1] for p in comp) + 1) * 4
    # centre of the head and torso (upper 60%), not of arms or props
    upper = [p[0] for p in comp if p[1] * 4 < top + (feet - top) * 0.6]
    center = (sum(upper) / len(upper) + 0.5) * 4
    return top, feet, center


def head_top(im, x0, x1):
    """Highest opaque row inside columns x0..x1 → (mean x of that row, y)."""
    px = im.getchannel('A').load()
    w, h = im.size
    x0, x1 = max(0, int(x0)), min(w, int(x1))
    for y in range(h):
        xs = [x for x in range(x0, x1, 2) if px[x, y] > 128]
        if len(xs) >= 3:
            return sum(xs) / len(xs), y
    return (x0 + x1) / 2, 0


def align(frames):
    """Crop every frame to its content, same height, feet on one line, centred."""
    crops = [f.crop(f.getbbox()) for f in frames]
    h = int(median(c.height for c in crops))
    scaled = [c.resize((max(1, round(c.width * h / c.height)), h), Image.LANCZOS) for c in crops]
    w = max(s.width for s in scaled) + 8
    out = []
    for s in scaled:
        canvas = Image.new('RGBA', (w, h + 8), (0, 0, 0, 0))
        canvas.alpha_composite(s, ((w - s.width) // 2, 4))
        out.append(canvas)
    return out


def natural_key(s):
    return [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', os.path.basename(s))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--name', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--fps', type=float, default=6)
    ap.add_argument('--loop', action='store_true', help='loop the frames while the action lasts')
    ap.add_argument('--hold', type=float, default=1.5, help='seconds to hold the last frame (non-looping)')
    ap.add_argument('--align', action='store_true')
    ap.add_argument('--duo', action='store_true')
    ap.add_argument('--ref-scale', type=float, default=1.0)
    ap.add_argument('frames', nargs='+')
    a = ap.parse_args()

    frames = [Image.open(f).convert('RGBA') for f in sorted(a.frames, key=natural_key)]
    for f in frames:  # faint noise far from the characters would stretch every crop
        f.putalpha(f.getchannel('A').point(lambda v: 0 if v < 24 else v))
    if a.align:
        frames = align(frames)
    size = frames[0].size
    if any(f.size != size for f in frames):
        raise SystemExit('all frames must have the same canvas size (use --align)')

    if a.duo:  # the pair: content box of the first frame, centred between both
        bx0, by0, bx1, by1 = frames[0].getbbox()
        top, feet, center = by0, by1, (bx0 + bx1) / 2
    else:
        top, feet, center = person_component(frames[0])
    standing = (feet - top) * a.ref_scale

    boxes = [f.getbbox() for f in frames]
    x0 = max(0, min(b[0] for b in boxes) - 4)
    y0 = max(0, min(b[1] for b in boxes) - 4)
    x1 = min(size[0], max(b[2] for b in boxes) + 4)
    y1 = min(size[1], max(b[3] for b in boxes) + 4)
    k = min(1.0, TARGET_HEIGHT / standing)

    def out_xy(x, y):
        return [round((x - x0) * k, 1), round((y - y0) * k, 1)]

    heads = []
    duo_heads = []
    for f in frames:  # the name tags follow the heads frame by frame
        if a.duo:
            fx0, _, fx1, _ = f.getbbox()
            mid = (fx0 + fx1) / 2
            duo_heads.append([out_xy(*head_top(f, fx0, mid)), out_xy(*head_top(f, mid, fx1))])
        else:
            half = (feet - top) * 0.22
            heads.append(out_xy(*head_top(f, center - half, center + half)))

    os.makedirs(a.out, exist_ok=True)
    names = []
    for i, f in enumerate(frames, 1):
        c = f.crop((x0, y0, x1, y1))
        c = c.resize((round(c.width * k), round(c.height * k)), Image.LANCZOS)
        name = f'{a.name}_{i}.webp'
        c.save(os.path.join(a.out, name), 'WEBP', quality=90, method=4)
        names.append(name)
    meta = {
        'frames': names,
        'fps': a.fps,
        'loop': a.loop,
        'hold': a.hold,
        'width': round((x1 - x0) * k),
        'height': round((y1 - y0) * k),
        'refHeight': round(standing * k, 1),
        'feetY': round((feet - y0) * k, 1),
        'centerX': round((center - x0) * k, 1),
    }
    if a.duo:
        meta['duoHeads'] = duo_heads
    else:
        meta['heads'] = heads
    with open(os.path.join(a.out, f'{a.name}.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, indent=2)
    print(json.dumps({k2: v for k2, v in meta.items() if k2 not in ('heads', 'duoHeads')}))


if __name__ == '__main__':
    main()
