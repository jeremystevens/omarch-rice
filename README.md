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
