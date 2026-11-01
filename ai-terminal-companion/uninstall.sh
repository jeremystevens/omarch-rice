#!/usr/bin/env bash
# Removes what install.sh added. Your settings in ~/.config/aiterm are kept.
set -euo pipefail

dest="$HOME/.local/share/aiterm"
if pgrep -f "^$dest/aiterm" >/dev/null; then
  echo "AI Terminal Companion is running. Close its windows and run the uninstaller again." >&2
  exit 1
fi

rm -rf "$dest"
rm -f "$HOME/.local/bin/aiterm" "$HOME/.local/share/applications/aiterm.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
echo "AI Terminal Companion has been uninstalled (settings kept in ~/.config/aiterm)."
