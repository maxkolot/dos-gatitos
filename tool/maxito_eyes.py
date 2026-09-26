#!/usr/bin/env python3
"""Measure Maxito's eyes in the sprite so the blink code can close them.

The blink in lib/features/characters/maxito/maxito_character.dart draws the
skin band just above each eye over the eye itself. That needs the eye geometry
as a fraction of the sprite box (eyeY, eyeLeftX, eyeRightX, eyeWidth,
eyeHeight). Blue irises are the easiest feature to find automatically, so this
script clusters blue pixels in the upper half of the image and prints the
constants to paste in.

Usage: python3 tool/maxito_eyes.py [assets/characters/maxito/maxito_idle.png]
"""

from __future__ import annotations

import sys

from PIL import Image

DEFAULT = "assets/characters/maxito/maxito_idle.png"


def is_iris(r: int, g: int, b: int, a: int) -> bool:
    return a > 128 and b > 110 and b > r + 25 and b > g + 10 and g > 60


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()

    pts = [
        (x, y)
        for y in range(0, int(h * 0.6))
        for x in range(w)
        if is_iris(*px[x, y])
    ]
    if len(pts) < 12:
        print(f"no iris pixels found in {path} ({len(pts)} candidates)")
        return 1

    xs = sorted(p[0] for p in pts)
    mid = xs[len(xs) // 2]
    left = [p for p in pts if p[0] <= mid]
    right = [p for p in pts if p[0] > mid]

    def box(cluster):
        cx = [p[0] for p in cluster]
        cy = [p[1] for p in cluster]
        return min(cx), max(cx), min(cy), max(cy)

    lx0, lx1, ly0, ly1 = box(left)
    rx0, rx1, ry0, ry1 = box(right)

    eye_left = (lx0 + lx1) / 2 / w
    eye_right = (rx0 + rx1) / 2 / w
    eye_y = ((ly0 + ly1) / 2 + (ry0 + ry1) / 2) / 2 / h
    eye_w = (max(lx1 - lx0, rx1 - rx0) / w) * 1.35
    eye_h = (max(ly1 - ly0, ry1 - ry0) / h) * 1.6

    print(f"{path}: {w}x{h}, {len(pts)} iris pixels")
    print("  static const double eyeY       = %.3f;" % eye_y)
    print("  static const double eyeLeftX   = %.3f;" % eye_left)
    print("  static const double eyeRightX  = %.3f;" % eye_right)
    print("  static const double eyeWidth   = %.3f;" % eye_w)
    print("  static const double eyeHeight  = %.3f;" % eye_h)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
