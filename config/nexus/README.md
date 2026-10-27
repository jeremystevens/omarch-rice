# NEXUS

Terminal-workbench desktop for Omarchy 4.0.6 / Hyprland 0.56.2 on the Acer
Chromebook Spin 13 (1440×960 logical). Installed 2026-10-26. Username and
hostname (`nitestryker@cyberdeck`) are unchanged.

## Keys

| Keys | Action |
|---|---|
| `SUPER ;` | Command menu (open / close) |
| `SUPER B` | Rail: collapse or expand (remembered) |
| `SUPER ALT B` | Rail: keyboard focus |
| `SUPER 1`–`5` | Workspaces, as before |
| Everything else | Unchanged Omarchy bindings (`omarchy menu keybindings --print`) |

All three NEXUS keys were unbound before NEXUS. The old NS-01 keys (`SUPER D`,
``SUPER ` ``) were removed with NS-01's Deck View and switcher.

### Command menu

- **Menu mode** (when it opens): one letter runs an action. `p` projects, `w`
  windows and `r` recent open a numbered list. `/` enters search. `Esc` closes.
- **List mode**: `1`–`9`, or `↑ ↓` and `Return`, pick a row. On projects, `e`
  opens nvim there and `f` opens Files. `Esc` goes back to the menu.
- **Search mode** (`/`): every key is text, and nothing triggers a shortcut. It
  searches actions, projects, windows and recent files by substring. `↑ ↓`
  choose, `Return` runs, `Esc` clears and goes back to menu mode.
- Letters: t terminal · p projects · w windows · r recent · e editor ·
  b browser · f files · k clipboard · i wifi · h bluetooth · v volume ·
  n night light · c screenshot · l lock · ? all keys.
- Tap or click works everywhere. Rows are 40–44 px, and tapping the search
  field enters search mode.

### Rail

- **Projects** come from `identity.toml`. Tap or `Return` opens a terminal in
  the project folder. With keyboard focus, `e` opens nvim and `f` opens Files.
  Right-click opens nvim.
- **Windows** are the Hyprland windows on the current workspace. Tap or
  `Return` focuses that window. The active window has a phosphor edge and an
  urgent window has an amber one. "elsewhere" lists other workspaces that
  have windows.
- **Recent files** come from GTK's `~/.local/share/recently-used.xbel`, and
  open with the default app. Only apps that record recent files add to it.
- Collapsed, the rail is 44 px with `p`, `w`, `r` and `»`. Tapping a letter
  shows the full rail over the desktop, and tapping outside or pressing `Esc`
  hides it.

## Workspace states (status line)

Phosphor block = active · off-white number with a green tick = has windows ·
dim = empty · amber block = urgent. Omarchy sets `focus_on_activate`, so
apps that ask for attention usually get focus straight away; amber appears for
apps that flag urgency without asking to be activated. NEXUS adds no window
rules and starts no apps.

## Personal details

`~/.config/nexus/identity.toml`: `[identity]` (`name`, `tagline`) and
`[projects]` (`name = "path"`). Saving it updates the rail and the menu.
Only what you write is shown.

## Components

| Part | Location |
|---|---|
| Theme (colors, shell styling, wallpaper) | `~/.config/omarchy/themes/nexus/` (wallpaper source in `src/wallpaper.py`) |
| Status-line widgets | `~/.config/omarchy/plugins/nexus.{tag,workspaces,readouts}/` |
| Rail | `~/.config/omarchy/plugins/nexus.rail/` |
| Command line and menu | `~/.config/omarchy/plugins/nexus.command/` |
| Notification cards | `~/.config/omarchy/plugins/nitestryker.notifications/` (Omarchy clone; the id carries your username, which is never shown) |
| Shared code | `~/.config/nexus/lib/Nx.js` |
| Helpers | `~/.config/nexus/bin/nexus-telemetry`, `nexus-recent` |
| Keys | the NEXUS block at the end of `~/.config/hypr/bindings.lua` |
| Fonts | Silkscreen in `~/.local/share/fonts/nexus/` (OFL); JetBrains Mono was already installed |

Startup: everything loads with the Omarchy shell at login, with no extra
daemons or units. The status line samples `/proc` and `/sys` every 5 s. The
rail and menu redraw on Hyprland events. Nothing animates continuously.

After editing the rail or command QML (services), run `omarchy restart shell`.
Status-line widgets reload on save.

## Status line position

The status line is designed for the bottom edge, under the command line. Omarchy
moves the bar to the nearest edge after a 200 ms press-and-hold or a short drag
on empty bar space, which a resting finger on the touchscreen can trigger.
`omarchy bar position bottom` puts it back. NEXUS works on any edge.

## Rollback

```bash
ns01 list                          # snapshots
ns01 rollback 20261026-222505      # NS-01 dashboard as it was before NEXUS
ns01 rollback 20261026-212226      # your desktop before any of this
```

Each rollback first saves the current config under
`~/.local/share/ns01/pre-rollback-<stamp>/`. The old NS-01 plugins are still
on disk, disabled.

## Health check

`ns01 doctor` checks the touchscreen fix, theme, Hyprland config, shell, rail,
command menu and font.

## Developer workstation (added 2026-10-26)

### Tools

| Area | Installed through | Notes |
|---|---|---|
| git, gcc, make, gdb, curl, jq, ripgrep, fd, fzf, bat, tmux, lazygit, sqlite3 | already present | reused |
| git-lfs, cmake, wget, 7zip, tree, HTTPie (`http`) | `omarchy pkg add` (pacman) | `git lfs install` done for your user |
| Node 24 LTS, pnpm, ruff, shellcheck, shfmt | mise (`~/.config/mise/config.toml`) | mise is the only runtime manager; Node 26.12.0 stays installed for projects that pin it |
| Python 3, uv | already present (mise, `~/.local/bin/uv`) | never `pip install` globally; use `uv add` / `uv add --dev` per project |
| TypeScript, pytest, eslint, prettier | per project | `pnpm add -D typescript`, `uv add --dev pytest` |
| Podman (rootless) + compose | pacman | no daemon; Docker (rootful) is installed but disabled at boot |

### Starting a project

1. Add it to `~/.config/nexus/identity.toml` under `[projects]`, for example
   `my-app = "~/Projects/my-app"`. Quote names with spaces: `"my app" = "~/Projects/my app"`.
2. `SUPER ;` then `p`, then the project's number (or tap it in the rail).
3. In the project panel: `t` opens a terminal in a tmux session named after
   the project (it reattaches if one exists), `e` nvim, `f` Files, `g` lazygit,
   `v` creates `.env` from `.env.example` (mode 600, ignored by git).
4. The numbered rows are tasks read from the project's manifests. Nothing runs
   until you pick one.

New projects: `uv init my-tool` (Python) or `pnpm init` (web), then add them
to `identity.toml`.

### Tasks and jobs

- Tasks come from `package.json` scripts (pnpm, yarn, bun or npm, chosen by
  lockfile), uv projects (`[project.scripts]`, plus pytest and ruff when the
  project uses them), Makefile targets and compose files. Manifests are only
  read; no project code runs during discovery.
- A task runs in its own window of the tmux session `nexus-tasks`. Its
  output stays after it exits.
- `j` (jobs): live output of the selected job. `Return` opens the full
  output in a terminal, `s` stops (Ctrl-C, then TERM), `o` opens the link,
  `c` clears finished jobs.
- A link appears only when a localhost URL printed by the task matches a port
  that one of the task's own processes is listening on.
- Servers are reachable on this machine only. NEXUS never exposes them or
  changes firewall rules.

### Sessions

`s` lists real tmux sessions (`Return` attaches). The rail shows them too.

### Containers

The container socket is off at boot. Use `d` (toolbox) and "start container
socket" before `podman compose up`, then "stop container socket" when done.
`podman run` works without the socket. Images stay out of the way of your
disk: "remove unused container images" is in the toolbox.

### Editor (nvim / LazyVim)

LazyVim extras enabled in `~/.config/nvim/lazyvim.json`: TypeScript, JSON,
Python, YAML, Markdown, Prettier, ESLint, DAP. NEXUS additions are in
`~/.config/nvim/lua/plugins/nexus-dev.lua` (bash, HTML, CSS, shfmt, ruff
formatting). Language servers come from Mason; shellcheck, shfmt and ruff
binaries come from mise. Search with `<space>/` (grep) and `<space><space>`
(files), git with `<space>gg` (lazygit), debug with `<space>d…`. Run
`:checkhealth` from the toolbox to check the editor.

### Secrets

- `~/.config/git/ignore` keeps `.env`, `.env.*` (except `.env.example`), keys and
  `.netrc` out of every repository.
- `nexus-env DIR` (or `v` in a project) sets up `.env` safely and warns if git
  already tracks one.
- Shell history skips commands that start with a space (Omarchy's
  `HISTCONTROL=ignoreboth`). Start a command with a space when it carries a secret.

### Left for you

- `gh auth login` (GitHub CLI), and any registry or API logins.
- Projects: only `omarch-rice` and `tries` are listed. Add others as you create them.
