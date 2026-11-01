# Personal shell additions, sourced from ~/.bashrc by a block that bootstrap.sh adds.
# Omarchy's own defaults stay in ~/.bashrc; put your aliases, exports and functions here.

# uv and other tools installed to ~/.local/bin
[[ -r $HOME/.local/bin/env ]] && . "$HOME/.local/bin/env"

# Doom Emacs CLI (`doom sync`, `doom doctor`, ...)
[[ -d $HOME/.config/emacs/bin ]] && export PATH="$PATH:$HOME/.config/emacs/bin"
