# NEXUS developer tools

The developer setup that goes with NEXUS (installed on an Acer Chromebook
Spin 13), and how to use it. The full guide is in `~/.config/nexus/README.md`.

## Programming languages and runtimes

| Language / runtime | Version | Managed by | Notes |
|---|---|---|---|
| Node.js | 24.22.1 (LTS, default) | mise | 26.12.0 also installed; pin it per project with `mise use node@26` |
| Python | 3.15.1 | mise | already present; use uv for projects |
| Bash / shell | system | — | linted with shellcheck, formatted with shfmt |
| C / C++ | gcc 16.2.1 | pacman | already present |

No Go, Rust or Java was installed, because no existing project needs them.

## Installed in this setup

| Tool | Version | Installed with | What it's for |
|---|---|---|---|
| pnpm | 12.15.0 | mise | Node package manager |
| ruff | 0.17.3 | mise | Python linter and formatter |
| shellcheck | 0.11.0 | mise | shell script linter |
| shfmt | 3.14.1 | mise | shell script formatter |
| git-lfs | 3.8.0 | pacman | large files in git (enabled for your user) |
| cmake | 4.4.4 | pacman | C/C++ build system |
| wget | 1.25.0 | pacman | downloads |
| 7zip (`7z`) | 26.04 | pacman | archives |
| tree | 2.3.2 | pacman | directory listings |
| HTTPie (`http`) | 3.2.4 | pacman | HTTP/API client |
| Podman | 6.1.4 | pacman | rootless containers, no daemon |

## Already present and reused

git 2.56, gh 2.103 (GitHub CLI), uv 0.13.6, make, gdb 18.1 (debugger),
pkg-config, curl, jq, ripgrep (`rg`), fd, fzf 0.74, bat, tmux 3.8,
lazygit 0.66, sqlite3 3.54, nvim 0.12 (LazyVim), zip/unzip, tar, xz, zstd,
docker + docker-compose (Docker is disabled at boot; see Containers).

## Per-project tools (not installed globally)

| Tool | Add it with |
|---|---|
| TypeScript | `pnpm add -D typescript @types/node` |
| ESLint / Prettier | `pnpm add -D eslint prettier` |
| pytest | `uv add --dev pytest` |
| ruff (project-pinned) | `uv add --dev ruff` |

Never `pip install` globally. Use `uv add` inside a project, or `uv tool install` for a standalone CLI.

## Editor: nvim (LazyVim)

- **Extras enabled:** TypeScript, JSON, Python, YAML, Markdown, Prettier, ESLint, DAP (debugging).
- **Extra config:** `~/.config/nvim/lua/plugins/nexus-dev.lua` adds bash, HTML and CSS, plus shfmt and ruff formatting.
- **Language servers (Mason):** vtsls, json-lsp, html-lsp, css-lsp, bash-language-server, pyright, ruff, eslint-lsp, yaml-language-server, marksman.
- **Debuggers:** js-debug-adapter (Node/Chrome) and debugpy (Python).
- **Useful keys:**

| Keys | Action |
|---|---|
| `<space><space>` | find files |
| `<space>/` | search text in the project |
| `<space>gg` | lazygit |
| `<space>cf` | format |
| `<space>d…` | debugging |
| `:checkhealth` | editor health |

## Common commands

```bash
# New projects
uv init my-tool && cd my-tool && uv add --dev pytest ruff
mkdir my-app && cd my-app && pnpm init && pnpm add -D typescript

# Python
uv run pytest            # tests
uv run ruff check .      # lint
uv run ruff format .     # format

# Node
pnpm install
pnpm run dev             # or build / test / lint, per package.json
pnpm exec tsc --noEmit   # typecheck

# Shell scripts
shellcheck script.sh
shfmt -i 2 -w script.sh

# HTTP / data
http GET localhost:3000/api      # HTTPie
sqlite3 dev.db

# Git
git lfs track "*.psd"
lazygit
gh auth login            # not done yet; run it yourself

# Containers (rootless Podman)
podman run --rm -it docker.io/library/alpine:3.22 sh
systemctl --user start podman.socket   # needed for compose
podman compose up
systemctl --user stop podman.socket
podman image prune                     # free disk space

# Runtimes
mise ls                  # installed tools and versions
mise use node@24         # pin a version in the current project
```

## Secrets and .env files

- `~/.config/git/ignore` keeps `.env`, `.env.*` (except `.env.example`), `*.pem`, `*.key` and `.netrc` out of every repo.
- `~/.config/nexus/bin/nexus-env [dir]` creates `.env.example` and `.env` (mode 600) and checks `.gitignore`.
- Commands that start with a space are not saved in shell history.

## NEXUS shortcuts for development

| Keys | Action |
|---|---|
| `SUPER ;` | command menu |
| `p` | projects; then `t` terminal (tmux), `e` nvim, `f` files, `g` lazygit, `v` env file, numbers run tasks |
| `j` | jobs: `Return` full output, `s` stop, `o` open link, `c` clear finished |
| `s` | tmux sessions |
| `d` | dev toolbox (container socket, health check, versions) |
| `/` | search everything |
| `SUPER B` / `SUPER ALT B` | collapse the rail / focus the rail with the keyboard |

Projects are listed in `~/.config/nexus/identity.toml` under `[projects]`.

## Helper scripts (`~/.config/nexus/bin/`)

| Script | Does |
|---|---|
| `nexus-dev` | project git status and tasks, tmux sessions, tool versions, open terminal/editor/files/git |
| `nexus-task` | run, list, tail, stop and clear tasks in the `nexus-tasks` tmux session |
| `nexus-env` | safe `.env` setup |
| `nexus-recent` | recent files list |
| `nexus-telemetry` | status-line readings |

## Disk use

About 1.3 GB in total: language servers 632 MB, Node 24 204 MB, system
packages 278 MB, the rest small.
