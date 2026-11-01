-- Tablet mode for the Acer Chromebook Spin 13 (omarch-rice/dotfiles; loaded by a block in
-- hyprland.lua that `bootstrap.sh tablet` adds).
-- Fold the screen back: it follows the accelerometer and the on-screen keyboard appears.
-- Unfold: back to normal. `tablet-mode status` shows what it thinks is going on.

o.bind("switch:on:Tablet Mode Switch", nil, "$HOME/.local/bin/tablet-mode on", { locked = true })
o.bind("switch:off:Tablet Mode Switch", nil, "$HOME/.local/bin/tablet-mode off", { locked = true })
o.launch_on_start("$HOME/.local/bin/tablet-mode daemon")
