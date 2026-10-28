#!/usr/bin/env python3
"""NEXUS wallpaper and lock image, drawn as pixel art at the panel's native
resolution (2256x1504, the Spin 13 at scale 1.5667). Every block is a whole
number of physical pixels, so edges stay crisp; no fonts are involved.

  art.py wallpaper <out.svg>   desktop: dim mark lower right, open space for work
  art.py lock <out.svg>        lock: small bright mark above the clock area

Both share the same base: flat charcoal, fine scanlines, off-white
corner ticks. Render with: rsvg-convert out.svg -o out.png
"""
import sys

W, H = 2256, 1504
SCALE = 2256 / 1440          # physical px per logical px

# The NEXUS ANSI mark (same as the rail and menu), half blocks: each text row
# is two pixel rows.
MARK = [
    "█▀▄  █ █▀▀▀▀ ▀▄   ▄▀ █   █ ▄▀▀▀▀",
    "█  ▀▄█ █▄▄▄    ▀▄▀   █   █ ▀▄▄▄ ",
    "█    █ █      ▄▀ ▀▄  █   █     █",
    "▀    ▀ ▀▀▀▀▀ ▀     ▀  ▀▀▀  ▀▀▀▀ ",
]
TOP = {"█": (1, 1), "▀": (1, 0), "▄": (0, 1), " ": (0, 0)}


def pixels():
    out = []
    for r, row in enumerate(MARK):
        for c, ch in enumerate(row):
            t, b = TOP.get(ch, (0, 0))
            if t:
                out.append((c, 2 * r))
            if b:
                out.append((c, 2 * r + 1))
    return out


COLS, ROWS = len(MARK[0]), 2 * len(MARK)


def mark(x, y, block, fill, opacity, shadow=None):
    """Pixel blocks with a 1/4 scan gap, optional hard drop shadow."""
    gap = max(1, block // 4)
    parts = []
    if shadow:
        sfill, sop, off = shadow
        parts += [f'<rect x="{x + c * block + off}" y="{y + r * block + off}" width="{block}" height="{block - gap}" '
                  f'fill="{sfill}" fill-opacity="{sop}"/>' for c, r in pixels()]
    parts += [f'<rect x="{x + c * block}" y="{y + r * block}" width="{block}" height="{block - gap}" '
              f'fill="{fill}" fill-opacity="{opacity}"/>' for c, r in pixels()]
    return "".join(parts)


def base():
    scan = "".join(f'<rect x="0" y="{y}" width="{W}" height="1" fill="#000" fill-opacity=".14"/>'
                   for y in range(0, H, 4))
    # Off-white corner ticks: a quiet frame, 2 px lines, 40 px long.
    m, L, t = 44, 40, 2
    ticks = ""
    for cx, cy, sx, sy in ((m, m, 1, 1), (W - m, m, -1, 1), (m, H - m, 1, -1), (W - m, H - m, -1, -1)):
        x1 = cx if sx > 0 else cx - L
        y1 = cy if sy > 0 else cy - t
        ticks += f'<rect x="{x1}" y="{y1}" width="{L}" height="{t}" fill="#e9e6dc" fill-opacity=".14"/>'
        x2 = cx if sx > 0 else cx - t
        y2 = cy if sy > 0 else cy - L
        ticks += f'<rect x="{x2}" y="{y2}" width="{t}" height="{L}" fill="#e9e6dc" fill-opacity=".14"/>'
    # Flat charcoal: a dark gradient only has ~20 shades to work with and
    # shows visible rings on this panel, so there is none.
    return f'<rect width="{W}" height="{H}" fill="#121413"/>' + scan + ticks


def wallpaper():
    block = 22                                   # 726 x 176 px mark
    x = W - 120 - COLS * block
    y = H - 190 - ROWS * block
    return base() + mark(x, y, block, "#4dff88", .10, ("#163d27", .60, 7))


def lock():
    # The lock view centres a 381x67 (logical) password field; the clock sits
    # above it. The mark goes above the clock, centred, in phosphor.
    block = 8                                    # 264 x 64 px mark
    cx, cy = W // 2, H // 2
    x = cx - COLS * block // 2
    y = cy - round(300 * SCALE) - ROWS * block // 2
    return (base() + mark(x, y, block, "#4dff88", .85, ("#163d27", .9, 3))
            # a faint phosphor rule under the password field area
            + f'<rect x="{cx - 180}" y="{cy + round(70 * SCALE)}" width="360" height="2" fill="#4dff88" fill-opacity=".18"/>')


kind, out = sys.argv[1], sys.argv[2]
body = wallpaper() if kind == "wallpaper" else lock()
open(out, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
                     f'viewBox="0 0 {W} {H}" shape-rendering="crispEdges">{body}</svg>')
