# AI Terminal Companion (Linux / Omarchy)

A terminal with a drop-down AI panel that uses an LLM server you run yourself: on the same machine, or on
another computer on your network (handy for a laptop too small to run a model). No cloud account needed.

You use your normal shell. Click the **AI Companion** bar at the top (or press <kbd>F1</kbd>) and a panel
slides down where you can ask about what's on screen. Suggested commands come back as cards you can
**Insert** onto your prompt line, **Run**, or **Copy**. The AI never runs anything by itself.

The AI is told what system it's on: the distro (read from `/etc/os-release`, so Omarchy is recognised as
Arch), the desktop, the package manager, an AUR helper (yay or paru) and systemd. On Arch it answers with
pacman / yay / systemctl commands, and any command card that looks like Windows (PowerShell, winget,
`C:\`…) or another distro (apt, dnf, snap, brew…) is labelled and asks before running.

## Requirements
- Arch Linux / Omarchy (any Linux with bash should work)
- Node.js and npm to build it: `sudo pacman -S --needed nodejs npm`
- An LLM server with an OpenAI-compatible chat API, e.g. llama.cpp's `llama-server`, Ollama or LM Studio

## Install
```bash
./install.sh
```
It builds the app and installs it for your user (no sudo): the app in `~/.local/share/aiterm`, an `aiterm`
command in `~/.local/bin`, and a desktop entry so the Omarchy launcher (<kbd>Super</kbd>+<kbd>Space</kbd>)
finds **AI Terminal Companion**. Then point it at your server (see [Settings](#settings)).

| Start it from | How |
| --- | --- |
| App launcher | **AI Terminal Companion** |
| Any terminal | `aiterm` opens in the current folder; `aiterm ~/code` opens there |

After changing the code, `./rebuild.sh` closes any open windows (it asks first), rebuilds, reinstalls and
starts it again. `./uninstall.sh` removes it (your settings are kept).
To run from source without installing: `npm install && npm start`.

## Using it
| Key / control | What it does |
| --- | --- |
| **AI Companion** bar | Click to open or close the panel. The dot is green when a server is reachable and its model is loaded; hover it to see which one |
| <kbd>F1</kbd> | Open or close the panel, wherever focus is (<kbd>Ctrl</kbd>+<kbd>`</kbd> also works) |
| <kbd>Esc</kbd> (in panel) | Stop the current answer, or close the panel |
| **Explain last output** | Ask about the latest terminal output or error |
| **include terminal output** | Send the last ~60 terminal lines with your question |
| **Insert** | Paste the command onto your prompt line without running it (multi-line commands stay intact) |
| **Run** | Paste and press Enter. Commands that delete, use sudo, overwrite files, etc. are marked ⚠ and ask first |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> / <kbd>V</kbd> | Copy / paste (also <kbd>Ctrl</kbd>+<kbd>C</kbd> with a selection, <kbd>Ctrl</kbd>+<kbd>V</kbd>, right-click) |

If your desktop already uses F1 (on a Chromebook, for example, the top row is often bound to brightness,
volume and so on), set `"hotkey"` to another key.

The panel shows your current directory, which is also sent to the AI. In bash it's tracked by a small
prompt hook (OSC 7) added after your `~/.bashrc`, so your prompt (starship etc.) keeps working. In zsh or
fish everything works except that the AI only sees the directory if your prompt prints it.

## Settings
Edit `~/.config/aiterm/config.json` (created with the defaults on first start), then open a new window:
```json
{
  "llmUrl": "http://localhost:8080/v1/chat/completions",
  "fallbackUrl": "",
  "healthUrl": "",
  "model": "",
  "maxTokens": 512,
  "hotkey": "F1",
  "shell": ""
}
```
| Key | Meaning |
| --- | --- |
| `llmUrl` | Main server. Any OpenAI-compatible `/v1/chat/completions` URL: llama.cpp (`http://HOST:8080/...`), Ollama (`http://HOST:11434/...`), LM Studio (`http://HOST:1234/...`) |
| `fallbackUrl` | Optional second server, used whenever the main one doesn't respond (e.g. one reachable from outside your home network). `""` = none |
| `healthUrl` | What the status dot checks for the main server. Empty = `/v1/models` on the same host |
| `model` | Model name, needed for Ollama / LM Studio |
| `maxTokens` | Maximum answer length |
| `hotkey` | Single key that toggles the panel, e.g. `F12` |
| `shell` | Shell to run; empty = your login shell |

Environment variables `COMPANION_LLM_URL`, `COMPANION_FALLBACK_URL`, `COMPANION_HEALTH_URL`, `COMPANION_MODEL`, `COMPANION_MAX_TOKENS`,
`COMPANION_HOTKEY`, `COMPANION_SHELL` and `COMPANION_CWD` override the file for one launch.

Before each question (and every 30 seconds for the status dot) the app checks the main server, then the
fallback, and uses the first one that answers. A server on another computer must listen on the network
(e.g. `llama-server --host 0.0.0.0`) and have its port open in that computer's firewall.

## Models
Answers are only as good as the model. The prompt is kept small enough for a 4k context, so 3–4B models
work, but they often get shell commands slightly wrong and occasionally loop (the app cuts a reply off when
it starts repeating itself). A coder model (e.g. Qwen 2.5 Coder 7B) or an 8B instruct model does much better.

## Notes
- With the server off or no network, the dot turns red and questions fail with an explanation; the terminal
  itself works normally.
- In Hyprland the window tiles like any other; the 120 × 30 starting size only applies to floating windows.
- If the app won't start with a sandbox error, start it once with `aiterm --no-sandbox` to confirm, and report it.

## License
MIT — see [LICENSE](LICENSE).
