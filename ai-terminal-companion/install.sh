#!/usr/bin/env bash
# Builds the app and installs it for the current user (no sudo needed) so it can be started like any terminal:
#   - Omarchy app launcher (Super+Space): "AI Terminal Companion"
#   - any terminal:                       aiterm  [folder]
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v npm >/dev/null; then
  echo "npm not found. Install Node.js first:  sudo pacman -S --needed nodejs npm" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64) arch=arm64 ;;
  *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

dest="$HOME/.local/share/aiterm"
bin="$HOME/.local/bin/aiterm"
desktop="$HOME/.local/share/applications/aiterm.desktop"

if pgrep -f "^$dest/aiterm" >/dev/null; then
  echo "AI Terminal Companion is running. Close its windows and run the installer again." >&2
  exit 1
fi

echo "==> Installing dependencies"
npm install
echo "==> Building"
npm run package

echo "==> Installing to $dest"
rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -r "dist/aiterm-linux-$arch" "$dest"

# Launcher on PATH. --ozone-platform-hint=auto runs natively on Wayland (Hyprland), X11 otherwise.
mkdir -p "$(dirname "$bin")"
cat > "$bin" <<EOF
#!/usr/bin/env bash
exec "$dest/aiterm" --ozone-platform-hint=auto "\$@"
EOF
chmod +x "$bin"

# Desktop entry, so the app launcher finds it.
mkdir -p "$(dirname "$desktop")"
cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=AI Terminal Companion
GenericName=Terminal
Comment=Terminal with a drop-down AI companion
Exec=$bin
Icon=$dest/resources/app/build/icon.png
Terminal=false
Categories=System;TerminalEmulator;
Keywords=terminal;shell;ai;aiterm;
StartupWMClass=aiterm
EOF
command -v update-desktop-database >/dev/null && update-desktop-database "$(dirname "$desktop")" || true

echo
echo "Done. Start it from the app launcher (\"AI Terminal Companion\") or type: aiterm"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: ~/.local/bin is not on your PATH, so 'aiterm' won't be found in terminals until you add it." ;;
esac
echo "Settings (which LLM server to use, hotkey, ...): ~/.config/aiterm/config.json (created on first start)"
