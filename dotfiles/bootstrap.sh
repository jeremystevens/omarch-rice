#!/bin/bash
# Restore this Omarchy setup on a fresh install, or bring the current one up to date.
#
#   ./bootstrap.sh                 every step below, in order
#   ./bootstrap.sh STEP...         only those steps, e.g. ./bootstrap.sh link doom
#   ./bootstrap.sh status          which dotfiles are linked, missing or changed
#   ./bootstrap.sh adopt PATH...   move config files from ~ into this repo and link them
#
# Steps:
#   packages  pacman packages from packages/pacman.txt (asks for your sudo password)
#   link      symlink everything in home/ into ~, keep name/email in ~/.gitconfig,
#             add a block to ~/.bashrc that loads ~/.config/bash/dotfiles.bash
#   tools     mise tools (~/.config/mise/config.toml) and uv tools (packages/uv-tools.txt)
#   fonts     Symbola, the symbol fallback font Doom Emacs asks for
#   keyd      Chromebook keys: Delete, Home, End, PgUp/PgDn, F11/F12 on a right-Alt layer
#             (system/keyd/default.conf → /etc/keyd; full runs only with --chromebook)
#   doom      install Doom Emacs if it's missing, then doom sync
#   nexus     the NEXUS theme (../nexus-omarchy/install.sh)
#   aiterm    AI Terminal Companion (../ai-terminal-companion/install.sh)
#
# Options:
#   --chromebook  also the keyd step and the Chromebook bits of NEXUS (top-row keys,
#                 touchscreen fix)
#   --dry-run     show what would change, change nothing
#
# A full run skips NEXUS and aiterm if they're already installed; name the step to reinstall.
# Anything a link would replace is moved to ~/.local/share/dotfiles/backup-<time>/ first.
# Safe to run again: steps that are already done are skipped.

set -euo pipefail

REPO=$(cd "$(dirname "$0")" && pwd)
RICE=$(dirname "$REPO")
FILES=$REPO/home
BACKUP=$HOME/.local/share/dotfiles/backup-$(date +%Y%m%d-%H%M%S)
ALL_STEPS=(packages link tools fonts keyd doom nexus aiterm)

dry=0 chromebook=0 steps=() adopt=()
mode=steps
for arg in "$@"; do
  case $arg in
    --dry-run) dry=1 ;;
    --chromebook) chromebook=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    status) mode=status ;;
    adopt) mode=adopt ;;
    -*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *)
      if [[ $mode == adopt ]]; then adopt+=("$arg")
      elif [[ " ${ALL_STEPS[*]} " == *" $arg "* ]]; then steps+=("$arg")
      else echo "Unknown step: $arg (steps: ${ALL_STEPS[*]})" >&2; exit 1
      fi ;;
  esac
done
explicit=1
((${#steps[@]})) || { steps=("${ALL_STEPS[@]}"); explicit=0; }

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
# Run a command, or only print it with --dry-run.
run() { if ((dry)); then note "would run: $*"; else "$@"; fi; }
# Lines of a list file without comments or blanks.
list() { sed 's/#.*//' "$1" | tr -s ' \t' '\n' | grep -v '^$' || true; }

# ------------------------------------------------------------------ link

# Every file in home/, as a path relative to ~.
tracked() { (cd "$FILES" && find . -type f -o -type l | sed 's|^\./||' | sort); }

backed_up=0
backup() {
  local rel=$1
  if ((dry)); then note "would back up ~/$rel"; return; fi
  mkdir -p "$(dirname "$BACKUP/$rel")"
  mv "$HOME/$rel" "$BACKUP/$rel"
  backed_up=1
  note "backed up ~/$rel"
}

link_one() {
  local rel=$1 src=$FILES/$1 dst=$HOME/$1
  if [[ -L $dst && $(readlink -f "$dst") == "$(readlink -f "$src")" ]]; then return; fi
  if [[ -e $dst || -L $dst ]]; then
    [[ $rel == .config/git/config ]] && move_git_identity
    backup "$rel"
  fi
  if ((dry)); then note "would link ~/$rel"; return; fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  note "linked ~/$rel"
}

# The shared git config in this repo has no name, email or credentials. Before it replaces
# ~/.config/git/config, copy those settings to ~/.gitconfig, which stays on this machine.
move_git_identity() {
  local old=$HOME/.config/git/config key value
  [[ -f $old && ! -L $old ]] || return 0
  while IFS= read -r -d '' entry; do
    key=${entry%%$'\n'*}
    value=${entry#*$'\n'}; [[ $entry == *$'\n'* ]] || value=''
    # gh's helper is saved with the full path of one gh version; use the gh on PATH instead.
    [[ $value == *"/gh auth git-credential" ]] && value='!gh auth git-credential'
    if ! git config --file "$HOME/.gitconfig" --get-all "$key" 2>/dev/null | grep -qxF -- "$value"; then
      ((dry)) || git config --file "$HOME/.gitconfig" --add "$key" "$value"
    fi
  done < <(git config --file "$old" -z --get-regexp '^(user|credential)\.' || true)
  note "$( ((dry)) && echo "would keep" || echo kept) your git name, email and credential helpers in ~/.gitconfig"
}

ensure_git_identity() {
  local name email
  name=$(git config --file "$HOME/.gitconfig" user.name 2>/dev/null || true)
  email=$(git config --file "$HOME/.gitconfig" user.email 2>/dev/null || true)
  [[ -n $name && -n $email ]] || ((dry)) && return
  if [[ ! -t 0 ]]; then warn "No git name/email yet: git config --global user.name/user.email"; return; fi
  [[ -n $name ]] || { read -r -p "    Git name for commits: " name; git config --file "$HOME/.gitconfig" user.name "$name"; }
  [[ -n $email ]] || { read -r -p "    Git email for commits: " email; git config --file "$HOME/.gitconfig" user.email "$email"; }
}

BASH_BLOCK='# >>> dotfiles (omarch-rice) >>>
[[ -r ~/.config/bash/dotfiles.bash ]] && source ~/.config/bash/dotfiles.bash
# <<< dotfiles (omarch-rice) <<<'

bashrc_block() {
  grep -qF '# >>> dotfiles (omarch-rice) >>>' "$HOME/.bashrc" 2>/dev/null && return
  if ((dry)); then note "would add the dotfiles block to ~/.bashrc"; return; fi
  printf '\n%s\n' "$BASH_BLOCK" >> "$HOME/.bashrc"
  note "added the dotfiles block to ~/.bashrc"
}

step_link() {
  say "Linking dotfiles from $FILES"
  local rel
  while IFS= read -r rel; do link_one "$rel"; done < <(tracked)
  ensure_git_identity
  bashrc_block
  ((backed_up)) && note "replaced files are in $BACKUP"
  return 0
}

status() {
  local rel dst
  while IFS= read -r rel; do
    dst=$HOME/$rel
    if [[ -L $dst && $(readlink -f "$dst") == "$(readlink -f "$FILES/$rel")" ]]; then echo "linked   ~/$rel"
    elif [[ ! -e $dst ]]; then echo "missing  ~/$rel"
    elif cmp -s "$dst" "$FILES/$rel"; then echo "same     ~/$rel (a copy, not linked)"
    else echo "differs  ~/$rel"
    fi
  done < <(tracked)
}

# Files that must never go into a public repo.
SECRET='(^|/)(\.env(\..*)?|.*\.(pem|key|p12|pfx|kdbx|gpg|asc)|id_(rsa|ed25519|ecdsa).*|\.netrc|\.npmrc|\.pypirc|\.git-credentials|\.gitconfig|.*(credential|secret|token).*)$'

adopt_files() {
  ((${#adopt[@]})) || { echo "Usage: ./bootstrap.sh adopt ~/.config/app/file ..." >&2; exit 1; }
  local p abs rel
  for p in "${adopt[@]}"; do
    abs=$(realpath -s "$p")
    rel=${abs#"$HOME"/}
    if [[ $abs != "$HOME"/* || ! -f $abs || -L $abs ]]; then warn "Skipping $p: not a regular file in your home folder"; continue; fi
    if [[ $rel =~ $SECRET ]]; then warn "Skipping $p: looks like a secret, and this repo is public"; continue; fi
    if ((dry)); then note "would copy ~/$rel into the repo"; continue; fi
    mkdir -p "$(dirname "$FILES/$rel")"
    cp -p "$abs" "$FILES/$rel"
    link_one "$rel"
  done
  note "Check the new files for anything private before you commit."
}

# ------------------------------------------------------------------ other steps

step_packages() {
  say "Installing packages from packages/pacman.txt"
  local missing
  missing=$(list "$REPO/packages/pacman.txt" | while read -r p; do pacman -Qq "$p" >/dev/null 2>&1 || echo "$p"; done)
  if [[ -z $missing ]]; then note "all installed"; return; fi
  note "to install: ${missing//$'\n'/ }"
  # shellcheck disable=SC2086  # one package per word
  run sudo pacman -S --needed $missing
}

step_tools() {
  say "Installing developer tools"
  if command -v mise >/dev/null; then run mise install; else warn "mise not found; skipping mise tools"; fi
  local uv; uv=$(command -v uv || echo "$HOME/.local/bin/uv")
  if [[ ! -x $uv ]]; then warn "uv not found (sudo pacman -S uv); skipping uv tools"; return; fi
  local t
  for t in $(list "$REPO/packages/uv-tools.txt"); do
    if [[ -d $("$uv" tool dir)/$t ]]; then note "$t already installed"; else run "$uv" tool install "$t"; fi
  done
}

SYMBOLA_DEB=https://deb.debian.org/debian/pool/main/t/ttf-ancient-fonts/fonts-symbola_2.60-2_all.deb
SYMBOLA_SHA=af8bd8cc9c808272034651cb5ebf6c38370ae536fe631eb89462f127f11e793f   # of Symbola.ttf

step_fonts() {
  say "Installing the Symbola font"
  local dir=$HOME/.local/share/fonts/symbola
  if [[ -f $dir/Symbola.ttf ]] && echo "$SYMBOLA_SHA  $dir/Symbola.ttf" | sha256sum -c --quiet 2>/dev/null; then
    note "already installed"; return
  fi
  if ((dry)); then note "would download $SYMBOLA_DEB and install Symbola.ttf to $dir"; return; fi
  local tmp; tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/symbola.deb" "$SYMBOLA_DEB"
  (cd "$tmp" && bsdtar -xf symbola.deb && bsdtar -xf data.tar.* )
  local ttf; ttf=$(find "$tmp" -name Symbola.ttf | head -1)
  if ! echo "$SYMBOLA_SHA  $ttf" | sha256sum -c --quiet; then rm -rf "$tmp"; warn "Symbola checksum mismatch; not installed"; return 1; fi
  mkdir -p "$dir"
  cp "$ttf" "$dir/"
  cp "$(find "$tmp" -path '*fonts-symbola/copyright' | head -1)" "$dir/COPYRIGHT" 2>/dev/null || true
  rm -rf "$tmp"
  fc-cache -f "$dir" >/dev/null
  note "installed to $dir"
}

step_keyd() {
  say "Chromebook keys (keyd)"
  if ((!explicit && !chromebook)); then note "skipped (Chromebook only: add --chromebook, or run ./bootstrap.sh keyd)"; return; fi
  local conf=$REPO/system/keyd/default.conf dst=/etc/keyd/default.conf
  pacman -Qq keyd >/dev/null 2>&1 || run sudo pacman -S --needed keyd
  if cmp -s "$conf" "$dst"; then
    note "config already installed"
  else
    [[ -e $dst ]] && run sudo cp "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"
    run sudo install -Dm644 "$conf" "$dst"
    ((dry)) || note "installed $dst"
  fi
  if systemctl is-active --quiet keyd; then run sudo keyd reload; else run sudo systemctl enable --now keyd; fi
  note "Hold right Alt: Backspace = Delete, arrows = Home/End/PgUp/PgDn, minus/equals = F11/F12."
  note "Stuck keyboard? Backspace + Escape + Enter together stops keyd."
}

step_doom() {
  say "Doom Emacs"
  local doom=$HOME/.config/emacs/bin/doom
  if ! command -v emacs >/dev/null; then warn "emacs isn't installed (run the packages step); skipping"; return; fi
  if [[ ! -x $doom ]]; then
    if [[ -e $HOME/.config/emacs ]]; then warn "$HOME/.config/emacs exists but has no Doom in it; skipping"; return; fi
    run git clone --depth 1 https://github.com/doomemacs/core "$HOME/.config/emacs"
    # The config (init.el etc.) is already linked, so don't let Doom write its example one.
    run "$doom" install --no-config --force
  else
    run "$doom" sync
  fi
}

# A full run leaves installed apps alone (on the machine you develop them on, the live copy is
# newer than the repo); name the step to reinstall: ./bootstrap.sh nexus
run_installer() {
  local name=$1 dir=$RICE/$2 installed=$3; shift 3
  say "$name"
  if ((!explicit)) && [[ -e $installed ]]; then note "already installed; run ./bootstrap.sh $STEP to reinstall"; return; fi
  if [[ ! -x $dir/install.sh ]]; then warn "$dir/install.sh not found; skipping"; return; fi
  if ((dry)); then
    if grep -q -- '--dry-run' "$dir/install.sh"; then "$dir/install.sh" --dry-run "$@"; else note "would run $dir/install.sh $*"; fi
  else
    "$dir/install.sh" "$@"
  fi
}

step_nexus() {
  local args=(); ((chromebook)) && args+=(--chromebook)
  STEP=nexus run_installer "NEXUS theme" nexus-omarchy "$HOME/.config/nexus/bin/nexus-dev" "${args[@]}"
}

step_aiterm() {
  STEP=aiterm run_installer "AI Terminal Companion" ai-terminal-companion "$HOME/.local/share/aiterm/aiterm"
  note "Its LLM server is set in ~/.config/aiterm/config.json (not in this repo)."
}

# ------------------------------------------------------------------ main

case $mode in
  status) status; exit 0 ;;
  adopt) adopt_files; exit 0 ;;
esac

((dry)) && say "Dry run: nothing will be changed"
for s in "${steps[@]}"; do "step_$s"; done
say "Done."
