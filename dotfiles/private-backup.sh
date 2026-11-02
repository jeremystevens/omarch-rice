#!/bin/bash
# Pack the private files that must never go in this repo into one password-protected archive,
# for a USB stick. Restore them on a new machine after bootstrap.sh.
#
#   ./private-backup.sh [DIR]          make DIR/omarchy-private-<date>.tar.zst.gpg (default: ~)
#   ./private-backup.sh list FILE      show what's inside (asks for the password)
#   ./private-backup.sh restore FILE   unpack into ~ (files already there are kept as name.~1~)
#
# Encrypted with gpg (AES-256, a password you choose). Lose the password and the archive is gone.
# Not included: gh login (run `gh auth login` again) and anything bootstrap.sh restores.

set -euo pipefail

# Relative to ~.
PRIVATE=(
  .ssh                              # SSH key for GitHub
  .gitconfig                        # git name, email, gh credential helper
  .config/aiterm/config.json        # AI Terminal Companion: LLM server addresses
  .config/nexus/identity.toml       # NEXUS projects, greeting, notes
  .local/state/nexus                # NEXUS sessions and runs
  .atuin/data                       # shell history
)

encrypt() { gpg --symmetric --cipher-algo AES256 --output "$1"; }
decrypt() { gpg --quiet --decrypt "$1"; }

case ${1:-} in
  list)
    decrypt "${2:?archive}" | zstd -dq | tar -tv
    ;;
  restore)
    file=${2:?archive}
    decrypt "$file" | zstd -dq | tar -C "$HOME" -x --backup=numbered -v
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    chmod 600 "$HOME"/.ssh/id_* 2>/dev/null || true
    chmod 644 "$HOME"/.ssh/*.pub 2>/dev/null || true
    echo "Restored. Next: gh auth login"
    ;;
  -h|--help)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    dir=${1:-$HOME}
    [[ -d $dir ]] || { echo "No such directory: $dir" >&2; exit 1; }
    out=$dir/omarchy-private-$(date +%Y%m%d).tar.zst.gpg
    [[ -e $out ]] && { echo "Already exists: $out" >&2; exit 1; }
    have=()
    for p in "${PRIVATE[@]}"; do
      if [[ -e $HOME/$p ]]; then have+=("$p"); else echo "skipping ~/$p (not found)"; fi
    done
    echo "Packing: ${have[*]}"
    echo "Choose a password you'll remember; there is no way to recover it."
    # .ssh/agent only holds the running agent's sockets.
    tar -C "$HOME" -c --exclude=.ssh/agent "${have[@]}" | zstd -q -19 | encrypt "$out"
    chmod 600 "$out"
    echo "Wrote $out ($(du -h "$out" | cut -f1))"
    ;;
esac
