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
| `keyd` | Chromebook only (`--chromebook`, or name the step): installs keyd and its config, see below |
| `doom` | Clones and installs Doom Emacs if missing, otherwise `doom sync` |
| `nexus` | Runs `../nexus-omarchy/install.sh` (`--chromebook` is passed on) |
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

## Day to day
Because the files are symlinks, editing `~/.config/doom/config.el` edits this repo. `git status` in
`~/omarch-rice` shows what changed; commit when you're happy with it.

Not in this repo on purpose: `~/.gitconfig` (name, email, credentials), `~/.config/aiterm/config.json`
(server addresses), SSH keys, and anything specific to one machine.
