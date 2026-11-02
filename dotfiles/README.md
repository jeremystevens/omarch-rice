# dotfiles

My personal config for [Omarchy](https://omarchy.org), plus `bootstrap.sh`, which turns a fresh Omarchy
install into my setup: packages, dotfiles, dev tools, Doom Emacs and the other projects in this repo.

```bash
git clone https://github.com/jeremystevens/omarch-rice ~/omarch-rice
~/omarch-rice/dotfiles/bootstrap.sh --dry-run      # see what it would do
~/omarch-rice/dotfiles/bootstrap.sh                # do it (add --chromebook on the Acer Spin 13)
```

## What's here
| Path | What |
| --- | --- |
| `home/` | Files that get symlinked into `~`, at the same paths |
| `home/.config/bash/dotfiles.bash` | My shell additions (loaded from `~/.bashrc`; Omarchy's own bashrc is left alone) |
| `home/.config/doom/` | Doom Emacs: Python (Eglot + basedpyright, tree-sitter, ruff on save), Chromebook keys |
| `home/.config/git/config` | Shared git settings. **No name, email or credentials**; those live in `~/.gitconfig` |
| `home/.config/mise/config.toml` | Language runtimes and CLIs managed by mise (node, python, gh, ruff, …) |
| `packages/pacman.txt` | Packages I add on top of Omarchy's own |
| `packages/uv-tools.txt` | Python CLIs installed with `uv tool install` |
| `system/keyd/default.conf` | Chromebook keyboard: the missing keys on a right-Alt layer (copied to `/etc/keyd`, not linked) |
| `system/libinput/local-overrides.quirks` | Keeps "ignore the touchpad while typing" working with keyd (copied to `/etc/libinput`) |
| `home/.local/bin/tablet-mode`, `home/.config/hypr/tablet.lua` | Tablet mode: auto-rotate and on-screen keyboard when the screen is folded back |
| `home/.config/omarchy/plugins/tablet.keyboard/` | Bar button that shows or hides the on-screen keyboard (only in tablet mode) |
| `home/.config/omarchy/hooks/theme-set.d/doom-emacs` | Recolours an open Doom Emacs when you switch Omarchy themes |
| `home/.config/atuin/`, `home/.config/lazygit/` | atuin history search (Ctrl+R, local only); lazygit diffs through delta |

Only files I've actually changed are here. Everything still at Omarchy's defaults (starship, tmux, nvim,
terminals, btop) is left to Omarchy, so its updates keep working. Hyprland, the bar and the theme are
handled by [NEXUS](../nexus-omarchy).

## bootstrap.sh
| Step | Does |
| --- | --- |
| `packages` | `sudo pacman -S --needed` the missing packages from `packages/pacman.txt` |
| `link` | Symlinks everything in `home/` into `~`, moves git name/email/credentials to `~/.gitconfig` (asks on a new machine), adds a marked block to `~/.bashrc` |
| `tools` | `mise install`, then the uv tools |
| `fonts` | Symbola (the symbol font Doom Emacs asks for), checksum-verified |
| `power` | Laptops: power-saver profile on battery. Omarchy already switches profiles when you plug in or unplug; this only changes its battery default, and only if you haven't picked one |
| `keyd` | Chromebook only (`--chromebook`, or name the step): installs keyd and its config, see below |
| `doom` | Clones and installs Doom Emacs if missing, otherwise `doom sync` |
| `nexus` | Runs `../nexus-omarchy/install.sh` (`--chromebook` is passed on) |
| `tablet` | Chromebook only: installs iio-sensor-proxy and wvkbd (AUR), hooks tablet mode into Hyprland, adds the bar button (after `nexus`, which replaces `shell.json`) |
| `aiterm` | Runs `../ai-terminal-companion/install.sh` |

```bash
./bootstrap.sh link doom          # just these steps
./bootstrap.sh status             # linked / missing / changed, per file
./bootstrap.sh adopt ~/.config/app/settings.conf   # start tracking a file
```

- Anything a link replaces is moved to `~/.local/share/dotfiles/backup-<time>/` first.
- Running it again is safe; finished steps are skipped. A full run also skips NEXUS and aiterm when
  they're already installed; name the step (`./bootstrap.sh nexus`) to reinstall.
- `adopt` refuses files that look like secrets (`.env`, keys, tokens, `.gitconfig`, …), but always look at
  a new file before committing: this repo is public.

## Chromebook keys (keyd)
The Acer Spin 13 keyboard has no Delete, Home, End, Page Up/Down, F11 or F12. Hold **right Alt**:

| right Alt + | Gives |
| --- | --- |
| Backspace | Delete |
| ← / → | Home / End |
| ↑ / ↓ | Page Up / Page Down |
| `-` / `=` | F11 / F12 |

Shift and Ctrl still combine (Shift + right Alt + → selects to the end of the line); left Alt is unchanged.
Search + arrows stay with Hyprland. After editing the config: `./bootstrap.sh keyd` (or `sudo keyd reload`).
If the keyboard ever stops responding, press Backspace + Escape + Enter together to stop keyd.

keyd types through its own virtual keyboard, which libinput doesn't treat as built-in, so it would stop
ignoring the touchpad while you type (the pointer jumps when a palm brushes it). The keyd step also
installs a libinput override, from keyd's README, that fixes this.

## Tablet mode
Fold the screen back and the Spin 13 turns into a tablet:

- The screen rotates with the device, and touch and pen follow it. In laptop mode it never rotates.
- An on-screen keyboard (wvkbd, in NEXUS colours) appears; a keyboard button in the bar shows or hides it.
- Unfold and everything goes back to normal.

`tablet-mode status` shows the current state; `tablet-mode rotate normal` straightens the screen by
hand. Hyprland can't tell whether the screen is already folded when you log in, so a session starts
in laptop mode and catches up at the next fold or unfold.

## Following the Omarchy theme
Switch themes with `omarchy theme set <name>` and everything changes together:

- **Terminals, btop, Hyprland, the bar:** Omarchy itself.
- **starship, fastfetch, lazygit, atuin, delta:** they use the terminal's colours, so they follow it.
- **Doom Emacs:** `config.el` reads the theme's `colors.toml` and recolours the main faces on top of
  `doom-one` (or `doom-one-light` for light themes). The `theme-set.d/doom-emacs` hook makes an open
  Emacs do it straight away; `M-x +omarchy-apply-colors` does the same by hand.

## Private files (USB backup)
Keys, git identity, aiterm's server addresses, NEXUS notes and shell history never go in this repo.
`./private-backup.sh` packs them into one gpg-encrypted archive (you pick the password) to keep on a USB stick:
```bash
./private-backup.sh /run/media/$USER/USB      # or no argument: ~/omarchy-private-<date>.tar.zst.gpg
./private-backup.sh list FILE                 # what's inside
./private-backup.sh restore FILE              # on the new machine, after bootstrap.sh; then gh auth login
```
Restore keeps any file it would overwrite as `name.~1~`.

## Day to day
Because the files are symlinks, editing `~/.config/doom/config.el` edits this repo. `git status` in
`~/omarch-rice` shows what changed; commit when you're happy with it.

Not in this repo on purpose: `~/.gitconfig` (name, email, credentials), `~/.config/aiterm/config.json`
(server addresses), SSH keys, and anything specific to one machine.
