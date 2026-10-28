#!/bin/bash
# Rebuild the NEXUS wallpaper and lock image from art.py (pixel art, native
# 2256x1504). Then re-apply the theme: omarchy theme set nexus
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
python3 -I src/art.py wallpaper "$tmp/wallpaper.svg"
python3 -I src/art.py lock "$tmp/lock.svg"
rsvg-convert "$tmp/wallpaper.svg" -o backgrounds/1-nexus.png
rsvg-convert "$tmp/lock.svg" -o lock.png
rm -r "$tmp"
echo "wrote backgrounds/1-nexus.png and lock.png"
