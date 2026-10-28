# NEXUS terminal greeting. Sourced from ~/.bashrc for interactive shells only.
#
# A new terminal window shows the two-line NEXUS mark next to a short summary
# of where you are: the project and its git state, the tasks it offers, open
# failures and a waiting tmux session. tmux panes and windows get the summary
# only, and only inside a project, so splitting panes never repeats the
# branding. Nothing here touches the network or runs project code: it reads
# git status and manifests through `nexus-dev info`, with a 0.4 s limit.
#
# Turn it down or off in ~/.config/nexus/identity.toml:
#   [terminal]
#   greeting = "full"      # mark + summary (default)
#   greeting = "summary"   # summary only, never the mark
#   greeting = "off"       # nothing
# or for one shell: NEXUS_GREETING=off bash. The prompt is separate (starship)
# and unaffected either way.

__nexus_greeting() {
  [[ $- == *i* && -t 1 && ${TERM:-dumb} != dumb ]] || return 0
  [[ -n ${NVIM:-} ]] && return 0                           # nvim :terminal
  case $(ps -o comm= -p "$PPID" 2>/dev/null) in bash|zsh|fish|sh|dash) return 0 ;; esac   # a shell started from a shell

  local mode=${NEXUS_GREETING:-}
  if [[ -z $mode && -r $HOME/.config/nexus/identity.toml ]]; then
    mode=$(awk '/^\[/{s=($0 ~ /^\[terminal\]/)} s && /^[[:space:]]*greeting[[:space:]]*=/{gsub(/.*=[[:space:]]*"|".*/, ""); print; exit}' "$HOME/.config/nexus/identity.toml")
  fi
  mode=${mode:-full}
  [[ $mode == off ]] && return 0

  local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
  local dir=$PWD home=$HOME
  local info
  info=$(timeout 0.4 "$HOME/.config/nexus/bin/nexus-dev" info "$dir" 2>/dev/null) || info=""

  # Is this a NEXUS project (listed in identity.toml), or project-like?
  local name="" listed=""
  if [[ -r $HOME/.config/nexus/identity.toml ]]; then
    listed=$(awk -v d="$dir" -v h="$home" '
      /^\[/{s=($0 ~ /^\[projects\]/); next}
      s && /=/ && !/^[[:space:]]*#/ {
        n=$0; sub(/[[:space:]]*=.*/, "", n); gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", n)
        v=$0; sub(/^[^=]*=[[:space:]]*"/, "", v); sub(/".*/, "", v); sub(/^~/, h, v)
        if (v == d) { print n; exit }
      }' "$HOME/.config/nexus/identity.toml")
  fi

  local git="" tasks="" ntasks=0 session=""
  if [[ -n $info ]]; then
    # Unit separator, not tab: read would merge empty tab-separated fields.
    IFS=$'\x1f' read -r git tasks ntasks session < <(jq -r '.[0] |
      [ (if .git == null then "" else
          (if .git.detached then "detached \(.git.commit)" else .git.branch end)
          + (if .git.conflicted > 0 then " !\(.git.conflicted)" else "" end)
          + ((.git.staged + .git.unstaged + .git.untracked) as $c | if $c > 0 then " ●\($c)" else "" end)
          + (if (.git.staged + .git.unstaged + .git.untracked + .git.conflicted) == 0 then " ✓" else "" end)
          + (if .git.ahead > 0 then " ↑\(.git.ahead)" else "" end)
          + (if .git.behind > 0 then " ↓\(.git.behind)" else "" end) end),
        ([.tasks[].label] | .[0:4] | join(", ")),
        (.tasks | length),
        (if .session.attached then "" elif .session.live then "tmux session running" elif .session.saved then "saved layout" else "" end)
      ] | map(tostring) | join("\u001f")' <<<"$info" 2>/dev/null)
  fi
  name=${listed:-}
  local project=0
  [[ -n $listed || -n $git || ${ntasks:-0} -gt 0 ]] && project=1
  [[ -z $name ]] && name=${dir##*/}

  # Inside tmux: no mark, and nothing at all outside a project.
  [[ -n ${TMUX:-} ]] && { ((project)) || return 0; mode=summary; }

  # Open failures recorded for this folder (Phase 3 inbox).
  local fails=0
  if ((project)) && compgen -G "$HOME/.local/state/nexus/runs/*.json" >/dev/null; then
    fails=$(cat "$HOME"/.local/state/nexus/runs/*.json 2>/dev/null | jq -s --arg d "$dir" \
      '[.[] | select(.dir == $d and .status == "failed" and (.resolved_at // .dismissed_at // .superseded_by) == null)] | length' 2>/dev/null)
  fi

  local c_mark="" c_dim="" c_white="" c_amber="" c_off=""
  if [[ -z ${NO_COLOR:-} ]]; then
    c_mark=$'\e[38;2;77;255;136m' c_dim=$'\e[38;2;134;137;128m' c_white=$'\e[38;2;233;230;220m'
    c_amber=$'\e[38;2;255;179;71m' c_off=$'\e[0m'
  fi

  local short=${dir/#$home/\~}
  local l1 l2 p1 p2   # l = plain text (for width), p = coloured
  if ((project)); then
    l1="$name"; p1="$c_white$name$c_off"
    if [[ -n $git ]]; then
      l1+=" · $git"
      if [[ $git == *" ✓"* ]]; then p1+=" $c_dim· $git$c_off"; else p1+=" $c_dim·$c_off $c_amber$git$c_off"; fi
    else
      l1+=" · no git"; p1+=" $c_dim· no git$c_off"
    fi
    if ((ntasks > 0)); then
      local more=""; ((ntasks > 4)) && more=" +$((ntasks - 4))"
      l2="tasks: $tasks$more"; p2="${c_dim}tasks:$c_off $tasks$c_dim$more$c_off"
    else
      l2="$short"; p2="$c_dim$short$c_off"
    fi
    if ((fails > 0)); then
      local f=" · $fails failed (SUPER ; x)"; l2+=$f; p2+=" $c_dim·$c_off $c_amber$fails failed$c_off $c_dim(SUPER ; x)$c_off"
    fi
    if [[ -n $session ]]; then l2+=" · $session"; p2+=" $c_dim· $session$c_off"; fi
  else
    local nproj nsess
    nproj=$(grep -cE '^[^#\[]*=' <(awk '/^\[/{s=($0 ~ /^\[projects\]/); next} s' "$HOME/.config/nexus/identity.toml" 2>/dev/null))
    nsess=$(tmux list-sessions 2>/dev/null | wc -l)
    l1="$short"; p1="$c_white$short$c_off"
    l2="$nproj projects · $nsess tmux sessions · SUPER ; menu"
    p2="$c_dim$nproj projects · $nsess tmux sessions · SUPER ; menu$c_off"
  fi

  # Trim to the window so nothing wraps; plain text decides, colour follows.
  local mark1='█▄ █ ██▀ ▀▄▄▀ █  █ ▄█▀▀' mark2='█ ▀█ █▄▄ ▄▀▀▄ ▀▄▄▀ ▄▄█▀'
  local gap=3 room=$cols
  [[ $mode == full ]] && ((cols >= 23 + gap + 20)) || mode=summary
  [[ $mode == full ]] && room=$((cols - 23 - gap))
  if ((${#l1} > room)); then p1="${l1:0:room-1}…"; fi
  if ((${#l2} > room)); then p2="$c_dim${l2:0:room-1}…$c_off"; fi

  if [[ $mode == full ]]; then
    printf '%s%s%s%*s%s\n' "$c_mark" "$mark1" "$c_off" "$gap" "" "$p1"
    printf '%s%s%s%*s%s\n' "$c_mark" "$mark2" "$c_off" "$gap" "" "$p2"
  else
    printf '%s\n%s\n' "$p1" "$p2"
  fi
}
__nexus_greeting
unset -f __nexus_greeting
