#!/usr/bin/env python3
"""Turn a batch of generated animation frames into game assets.

  python3 tool/prep_anim.py --name dance --out assets/characters/sebastian/anim --fps 6 --loop FRAME1.png FRAME2.png ...

Every frame gets the SAME crop (the union of all frames), so nothing jumps between frames, and is scaled so the
character is ~1000 px tall. Next to the frames goes <name>.json with where the character stands in the frame
(feetY, centerX) and how tall he is (refHeight): the game uses it to put the frame exactly where the idle sprite
stands, whatever props the frame carries (a record cabinet, a table...).
"""
import argparse
import json
import os
import re
from collections import deque

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


def head_top(im, person_center, person_height):
    """Top of the character's head in this frame: the highest opaque pixel near his body centre
    (props like a cabinet stand to the side and are lower than his head)."""
    a = im.getchannel('A')
    w, h = im.size
    half = person_height * 0.22  # search the head in a column around the body centre
    x0, x1 = max(0, int(person_center - half)), min(w, int(person_center + half))
    px = a.load()
    for y in range(h):
        xs = [x for x in range(x0, x1, 2) if px[x, y] > 128]
        if len(xs) >= 3:
            return sum(xs) / len(xs), y
    return person_center, 0


def natural_key(s):
    return [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', os.path.basename(s))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--name', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--fps', type=float, default=6)
    ap.add_argument('--loop', action='store_true', help='loop the frames while the action lasts')
    ap.add_argument('--hold', type=float, default=1.5, help='seconds to hold the last frame (non-looping)')
    ap.add_argument('frames', nargs='+')
    a = ap.parse_args()

    frames = [Image.open(f).convert('RGBA') for f in sorted(a.frames, key=natural_key)]
    size = frames[0].size
    if any(f.size != size for f in frames):
        raise SystemExit('all frames must have the same canvas size')
    top, feet, center = person_component(frames[0])

    boxes = [f.getbbox() for f in frames]
    x0 = max(0, min(b[0] for b in boxes) - 4)
    y0 = max(0, min(b[1] for b in boxes) - 4)
    x1 = min(size[0], max(b[2] for b in boxes) + 4)
    y1 = min(size[1], max(b[3] for b in boxes) + 4)
    k = min(1.0, TARGET_HEIGHT / (feet - top))

    os.makedirs(a.out, exist_ok=True)
    names = []
    heads = []
    for f in frames:  # the name tag follows the head frame by frame
        hx, hy = head_top(f, center, feet - top)
        heads.append([round((hx - x0) * k, 1), round((hy - y0) * k, 1)])
    for i, f in enumerate(frames, 1):
        c = f.crop((x0, y0, x1, y1))
        c = c.resize((round(c.width * k), round(c.height * k)), Image.LANCZOS)
        name = f'{a.name}_{i}.webp'
        c.save(os.path.join(a.out, name), 'WEBP', quality=90, method=6)
        names.append(name)
    meta = {
        'frames': names,
        'fps': a.fps,
        'loop': a.loop,
        'hold': a.hold,
        'width': round((x1 - x0) * k),
        'height': round((y1 - y0) * k),
        'refHeight': round((feet - top) * k, 1),
        'feetY': round((feet - y0) * k, 1),
        'centerX': round((center - x0) * k, 1),
        'heads': heads,
    }
    with open(os.path.join(a.out, f'{a.name}.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, indent=2)
    print(json.dumps(meta))


if __name__ == '__main__':
    main()
