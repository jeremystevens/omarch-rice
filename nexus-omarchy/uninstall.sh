#!/bin/bash
# Remove NEXUS: restore every file install.sh replaced, delete the files it
# added, and take the NEXUS blocks out of ~/.config/hypr/bindings.lua,
# ~/.config/hypr/hyprland.lua and ~/.bashrc.
#
# Uses every install record under ~/.local/share/nexus/backup-*, so running
# install.sh more than once is fine.
#
# The touchscreen fix in /etc/modprobe.d is left alone (remove it yourself
# with sudo if you want to). Pick another theme afterwards with the Omarchy
# theme menu.

set -euo pipefail
STORE=$HOME/.local/share/nexus
mapfile -t BACKUPS < <(find "$STORE" -maxdepth 1 -name 'backup-*' -type d 2>/dev/null | sort)
((${#BACKUPS[@]})) || { echo "no NEXUS install record found in ${STORE/#$HOME/~}" >&2; exit 1; }

say() { printf '\e[38;2;77;255;136m■\e[0m %s\n' "$*"; }
say "Uninstalling NEXUS (${#BACKUPS[@]} install record(s) in ${STORE/#$HOME/~})"

# Every file any install added. Restore the oldest backup of it (the version
# from before NEXUS); if there is none, NEXUS created it, so delete it.
{ cat "${BACKUPS[@]/%//installed.txt}" 2>/dev/null || true; } | sort -u | while IFS= read -r rel; do   # a re-install that changed nothing has no record
  [[ -n $rel ]] || continue
  original=""
  for b in "${BACKUPS[@]}"; do [[ -e $b/files/$rel ]] && { original=$b/files/$rel; break; }; done
  if [[ -n $original ]]; then cp -a "$original" "$HOME/$rel"; else rm -f "$HOME/$rel"; fi
done

# Marked blocks added by install.sh: keys, window rules, greeting.
for target in "$HOME/.config/hypr/bindings.lua" "$HOME/.config/hypr/hyprland.lua" "$HOME/.bashrc"; do
  [[ -f $target ]] || continue
  awk 'index($0, "-- >>> NEXUS") == 1 || index($0, "# >>> NEXUS") == 1 { skip = 1 } !skip { print }
       index($0, "-- <<< NEXUS") == 1 || index($0, "# <<< NEXUS") == 1 { skip = 0 }' "$target" |
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$target.tmp" && cat "$target.tmp" >"$target" && rm -f "$target.tmp"
done

[[ $(readlink "$HOME/.local/bin/nexus-project" 2>/dev/null) == "$HOME/.config/nexus/bin/nexus-project" ]] && rm -f "$HOME/.local/bin/nexus-project"
find "$HOME/.config/nexus" "$HOME/.config/omarchy/plugins" "$HOME/.config/omarchy/themes/nexus" "$HOME/.local/share/fonts/nexus" -type d -empty -delete 2>/dev/null || true

# Keep the records, but out of the way of the next install.
done_dir=$STORE/uninstalled-$(date +%Y%m%d-%H%M%S)
mkdir -p "$done_dir" && mv "${BACKUPS[@]}" "$done_dir/"

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null || true
  omarchy restart shell >/dev/null 2>&1 || true
fi
say "Done. Choose another theme from the Omarchy menu (SUPER SPACE)."
