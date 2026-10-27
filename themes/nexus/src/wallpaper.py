#!/usr/bin/env python3
"""Renders the NEXUS wallpaper as SVG: charcoal, faint scanlines, and the
NEXUS ANSI mark set large and dim in the lower right, where tiled windows
rarely reach. Geometry in logical px (1440x960), scaled to 2256x1504.
usage: wallpaper.py <out.svg>"""
import sys

W, H, S = 1440, 960, 2256 / 1440
MARK = [
    "█▀▄  █ █▀▀▀▀ ▀▄   ▄▀ █   █ ▄▀▀▀▀",
    "█  ▀▄█ █▄▄▄    ▀▄▀   █   █ ▀▄▄▄ ",
    "█    █ █      ▄▀ ▀▄  █   █     █",
    "▀    ▀ ▀▀▀▀▀ ▀     ▀  ▀▀▀  ▀▀▀▀ ",
]
FONT = "JetBrainsMono Nerd Font"
size = 30          # px per character row
advance = size * 0.6
x0 = W - 60 - advance * len(MARK[0])
y0 = H - 110 - size * len(MARK)

def lines(dx, dy, fill, opacity):
    out = []
    for i, row in enumerate(MARK):
        out.append(f'<text x="{x0 + dx:.1f}" y="{y0 + dy + (i + 1) * size:.1f}" xml:space="preserve" '
                   f'font-family="{FONT}" font-weight="700" font-size="{size}" fill="{fill}" '
                   f'fill-opacity="{opacity}" textLength="{advance * len(row):.1f}">'
                   + row.replace("&", "&amp;") + '</text>')
    return "".join(out)

scan = "".join(f'<rect x="0" y="{y}" width="{W}" height="1" fill="#000" fill-opacity=".12"/>' for y in range(0, H, 3))
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*S:.0f}" height="{H*S:.0f}" viewBox="0 0 {W} {H}">'
       f'<defs><radialGradient id="g" cx="78%" cy="78%" r="65%"><stop offset="0" stop-color="#161917"/>'
       f'<stop offset="1" stop-color="#101211"/></radialGradient></defs>'
       f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
       + lines(3, 3, "#163d27", .55) + lines(0, 0, "#4dff88", .085) + scan + '</svg>')
open(sys.argv[1], "w").write(svg)
