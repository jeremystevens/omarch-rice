# omarch-rice

My [Omarchy](https://omarchy.org) setup: dotfiles, themes and apps, each in its own folder.

| Folder | What |
| --- | --- |
| [`dotfiles/`](dotfiles) | Personal config and `bootstrap.sh`, which sets up a fresh Omarchy install with everything here |
| [`nexus-omarchy/`](nexus-omarchy) | NEXUS: a terminal-workbench theme with a command menu, project rail and dev tools |
| [`ai-terminal-companion/`](ai-terminal-companion) | A terminal with a drop-down AI panel that uses your own LLM server |

## New machine
```bash
git clone https://github.com/jeremystevens/omarch-rice ~/omarch-rice
~/omarch-rice/dotfiles/bootstrap.sh --dry-run
~/omarch-rice/dotfiles/bootstrap.sh
```
Each folder also works on its own; see its README.

## Why two `home/` folders?
Both `nexus-omarchy/home/` and `dotfiles/home/` mirror your home directory, but they're used
differently and never contain the same file:

- **`nexus-omarchy/home/`** is a theme anyone can install. Its `install.sh` *copies* the files into place.
- **`dotfiles/home/`** is my personal config. `bootstrap.sh` *symlinks* it, so editing the live files
  edits this repo.

`bootstrap.sh` runs the NEXUS installer as one of its steps, so a single command sets up both.
