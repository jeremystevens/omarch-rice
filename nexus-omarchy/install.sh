#!/bin/bash
# Install NEXUS into the current user's Omarchy setup.
#
#   ./install.sh               theme, shell plugins, helpers, keys, font
#   ./install.sh --chromebook  also the Chromebook top-row keys and (with sudo)
#                              the Acer Spin 13 touchscreen fix
#   ./install.sh --dev         also the LazyVim language config (nexus-dev.lua)
#   ./install.sh --no-apply    copy files only; don't switch theme or restart
#   ./install.sh --dry-run     show what would happen, change nothing
#
# Every file that would be overwritten is backed up first under
# ~/.local/share/nexus/backup-<stamp>/; ./uninstall.sh puts them back.

set -euo pipefail
cd "$(dirname "$(realpath "$0")")"
REPO=$PWD

chromebook=0 dev=0 apply=1 dry=0
for arg in "$@"; do
  case $arg in
    --chromebook) chromebook=1 ;;
    --dev) dev=1 ;;
    --no-apply) apply=0 ;;
    --dry-run) dry=1 apply=0 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

say() { printf '\e[38;2;77;255;136m■\e[0m %s\n' "$*"; }
warn() { printf '\e[38;2;255;179;71m■\e[0m %s\n' "$*"; }
run() { if ((dry)); then echo "  would: $*"; else "$@"; fi; }

command -v omarchy >/dev/null || { echo "Omarchy not found. NEXUS is an Omarchy theme." >&2; exit 1; }

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=$HOME/.local/share/nexus/backup-$STAMP
MANIFEST=$BACKUP/installed.txt
run mkdir -p "$BACKUP"

# Copy one file from a source tree into $HOME, backing up what it replaces.
place() {
  local src=$1 rel=$2 dest=$HOME/$2
  if [[ -e $dest ]]; then
    cmp -s "$src" "$dest" && return   # already identical: not ours to remove later
    run mkdir -p "$(dirname "$BACKUP/files/$rel")"
    run cp -a "$dest" "$BACKUP/files/$rel"
  fi
  run mkdir -p "$(dirname "$dest")"
  run cp -a "$src" "$dest"
  ((dry)) || echo "$rel" >>"$MANIFEST"
}

install_tree() {
  local root=$1 f rel
  while IFS= read -r -d '' f; do
    rel=${f#"$root"/}
    [[ $rel == .config/hypr/nexus-*.lua ]] && continue   # merged into bindings.lua below
    place "$f" "$rel"
  done < <(find "$root" -type f -print0)
}

# Insert (or replace) a marked block at the end of ~/.config/hypr/bindings.lua.
add_bindings() {
  local name=$1 file=$2 target=$HOME/.config/hypr/bindings.lua
  local begin="-- >>> $name (added by NEXUS install.sh)" end="-- <<< $name"
  if ((dry)); then echo "  would: add the $name block to $target"; return; fi
  touch "$target"
  [[ -e $BACKUP/files/.config/hypr/bindings.lua ]] || { mkdir -p "$BACKUP/files/.config/hypr"; cp -a "$target" "$BACKUP/files/.config/hypr/bindings.lua"; }
  awk -v b="$begin" -v e="$end" 'index($0, b) == 1 { skip = 1 } !skip { print } index($0, e) == 1 { skip = 0 }' "$target" |
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$target.tmp"
  { cat "$target.tmp"; printf '\n%s\n' "$begin"; cat "$file"; printf '%s\n' "$end"; } >"$target"
  rm -f "$target.tmp"
}

# Append (or replace) a marked block of lines at the end of a file.
add_block() {
  local name=$1 target=$2 comment=$3 content=$4
  local begin="$comment >>> $name (added by NEXUS install.sh)" end="$comment <<< $name"
  if ((dry)); then echo "  would: add the $name block to $target"; return; fi
  touch "$target"
  local rel=${target#"$HOME"/}
  [[ -e $BACKUP/files/$rel ]] || { mkdir -p "$(dirname "$BACKUP/files/$rel")"; cp -a "$target" "$BACKUP/files/$rel"; }
  awk -v b="$begin" -v e="$end" 'index($0, b) == 1 { skip = 1 } !skip { print } index($0, e) == 1 { skip = 0 }' "$target" |
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$target.tmp"
  { cat "$target.tmp"; printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"; } >"$target"
  rm -f "$target.tmp"
}

say "Installing NEXUS (backup: ${BACKUP/#$HOME/~})"
install_tree "$REPO/home"
add_bindings "NEXUS keys" "$REPO/home/.config/hypr/nexus-bindings.lua"
add_block "NEXUS window rules" "$HOME/.config/hypr/hyprland.lua" "--" 'require("hypr.nexus")'
add_block "NEXUS greeting" "$HOME/.bashrc" "#" '[[ -r ~/.config/nexus/shell/greeting.bash ]] && source ~/.config/nexus/shell/greeting.bash'
run chmod +x "$HOME"/.config/nexus/bin/*
run mkdir -p "$HOME/.local/bin"
run ln -sf "$HOME/.config/nexus/bin/nexus-project" "$HOME/.local/bin/nexus-project"

if ((chromebook)); then
  say "Chromebook extras"
  install_tree "$REPO/extras/chromebook-spin-13/home"
  add_bindings "NEXUS Chromebook keys" "$REPO/extras/chromebook-spin-13/home/.config/hypr/nexus-chromebook-keys.lua"
  conf=/etc/modprobe.d/chromebook-touchscreen.conf
  if [[ -e $conf ]]; then
    say "touchscreen fix already in place"
  else
    warn "the touchscreen fix needs root: sudo will ask for your password"
    run sudo install -m 644 "$REPO/extras/chromebook-spin-13/etc/modprobe.d/chromebook-touchscreen.conf" "$conf"
    warn "reboot for the touchscreen fix to take effect"
  fi
fi

if ((dev)); then
  say "Developer extras"
  place "$REPO/extras/dev-workstation/home/.config/nvim/lua/plugins/nexus-dev.lua" ".config/nvim/lua/plugins/nexus-dev.lua"
  warn "lazyvim.json, mise and git ignore examples are in extras/dev-workstation (not installed: they would replace your own)"
fi

((dry)) && { rmdir "$BACKUP" 2>/dev/null || true; exit 0; }

run fc-cache -f "$HOME/.local/share/fonts/nexus" >/dev/null 2>&1 || true

if ((apply)) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  say "Applying"
  omarchy theme set nexus || warn "could not switch theme; run: omarchy theme set nexus"
  omarchy theme bg set "$HOME/.local/state/omarchy/current/theme/backgrounds/1-nexus.png" >/dev/null 2>&1 || true
  hyprctl reload >/dev/null && { errs=$(hyprctl configerrors); [[ -z $errs || $errs == *"no errors"* ]] || warn "Hyprland config errors: $errs"; }
  omarchy restart shell >/dev/null 2>&1 || warn "run: omarchy restart shell"
fi

say "Done. Open the menu with SUPER ; — undo with ./uninstall.sh"
