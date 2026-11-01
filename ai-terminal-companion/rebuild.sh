#!/usr/bin/env bash
# Rebuild and reinstall AI Terminal Companion after changing the code, then start it again.
#
#   ./rebuild.sh            asks before closing open windows
#   ./rebuild.sh -y         closes open windows without asking
#   ./rebuild.sh --no-start leaves it closed afterwards
#
# Run it from a normal terminal, not from inside aiterm (closing aiterm would stop this script).
set -euo pipefail
cd "$(dirname "$0")"

yes=0 start=1
for arg in "$@"; do
  case $arg in
    -y|--yes) yes=1 ;;
    --no-start) start=0 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [[ ${TERM_PROGRAM:-} == aiterm ]]; then
  echo "You're inside AI Terminal Companion. Run this from another terminal (Super+Enter)." >&2
  exit 1
fi

dest="$HOME/.local/share/aiterm"
if pgrep -f "^$dest/aiterm" >/dev/null; then
  n=$(pgrep -f "^$dest/aiterm .*--ozone" | wc -l)
  if ((!yes)); then
    read -r -p "AI Terminal Companion has $n window(s) open. Close them to rebuild? Anything running in them stops. [y/N] " ans
    [[ $ans == [yY]* ]] || { echo "Nothing changed."; exit 1; }
  fi
  # Ask nicely first (the app hangs up its shell and exits), then make sure.
  pkill -TERM -f "^$dest/aiterm" || true
  for _ in {1..30}; do pgrep -f "^$dest/aiterm" >/dev/null || break; sleep 0.2; done
  pkill -KILL -f "^$dest/aiterm" 2>/dev/null || true
fi

./install.sh

if ((start)); then
  setsid -f "$HOME/.local/bin/aiterm" >/dev/null 2>&1
  echo "Started aiterm."
fi
