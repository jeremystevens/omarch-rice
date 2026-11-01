# Personal shell additions, sourced from ~/.bashrc by a block that bootstrap.sh adds.
# Omarchy's own defaults stay in ~/.bashrc; put your aliases, exports and functions here.

# uv and other tools installed to ~/.local/bin
[[ -r $HOME/.local/bin/env ]] && . "$HOME/.local/bin/env"

# Doom Emacs CLI (`doom sync`, `doom doctor`, ...)
[[ -d $HOME/.config/emacs/bin ]] && export PATH="$PATH:$HOME/.config/emacs/bin"

# atuin: searchable history on Ctrl+R (replaces fzf's). It needs bash-preexec, which has to be
# loaded after everything else that uses the prompt hook (starship), so this stays at the end.
if command -v atuin >/dev/null && [[ -r /usr/share/bash-preexec/bash-preexec.sh ]]; then
  source /usr/share/bash-preexec/bash-preexec.sh
  eval "$(atuin init bash --disable-up-arrow)"
fi
