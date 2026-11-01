const { app, BrowserWindow, ipcMain, clipboard, Menu, screen } = require('electron');
const path = require('path');
const os = require('os');
const fs = require('fs');
const pty = require('@lydell/node-pty');
const { Llm } = require('./llm');

// ---------------------------------------------------------------- settings
// Environment variables override ~/.config/aiterm/config.json, which overrides these defaults.
// Apps started from the Omarchy launcher don't see variables exported in a terminal, hence the file.
const CONFIG_PATH = path.join(os.homedir(), '.config', 'aiterm', 'config.json');
const DEFAULTS = {
  // Any OpenAI-compatible chat endpoint: llama.cpp's llama-server (below), Ollama
  // (http://localhost:11434/v1/chat/completions, set "model"), LM Studio, or a server on another machine.
  llmUrl: 'http://localhost:8080/v1/chat/completions',
  // Optional second server, used whenever llmUrl doesn't respond (e.g. a laptop away from home).
  fallbackUrl: '',
  healthUrl: '', // empty = work it out from llmUrl
  model: '', // needed for Ollama / LM Studio; AI Studio and llama.cpp ignore it
  maxTokens: 512,
  hotkey: 'F1',
  shell: '', // empty = your login shell ($SHELL)
};

function loadConfig() {
  let file = {};
  try {
    file = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch (err) {
    if (err.code === 'ENOENT') {
      // First run: write the defaults so there's a file to edit.
      try {
        fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
        fs.writeFileSync(CONFIG_PATH, JSON.stringify(DEFAULTS, null, 2) + '\n');
      } catch {}
    } else {
      console.error(`Ignoring ${CONFIG_PATH}: ${err.message}`);
    }
  }
  const env = process.env;
  // A key present in the file wins even when empty, so "fallbackUrl": "" turns the fallback off.
  const pick = (envName, key) => env[envName] || (key in file ? file[key] : DEFAULTS[key]);
  return {
    llmUrl: pick('COMPANION_LLM_URL', 'llmUrl'),
    fallbackUrl: pick('COMPANION_FALLBACK_URL', 'fallbackUrl'),
    healthUrl: pick('COMPANION_HEALTH_URL', 'healthUrl'),
    model: pick('COMPANION_MODEL', 'model'),
    maxTokens: Number(pick('COMPANION_MAX_TOKENS', 'maxTokens')),
    hotkey: pick('COMPANION_HOTKEY', 'hotkey'),
    shell: pick('COMPANION_SHELL', 'shell') || env.SHELL || '/bin/bash',
  };
}
const config = loadConfig();
const llm = new Llm(config);

// What the AI needs to know to suggest commands that work here. Small models don't know that
// "Omarchy" is Arch, so the base distro and package tools are spelled out.
function onPath(cmd) {
  return (process.env.PATH || '').split(':').some((dir) => dir && fs.existsSync(path.join(dir, cmd)));
}

function systemInfo() {
  let rel = '';
  try { rel = fs.readFileSync('/etc/os-release', 'utf8'); } catch {}
  const field = (key) => rel.match(new RegExp(`^${key}="?([^"\\n]+)`, 'm'))?.[1] || '';
  const id = field('ID');
  const like = field('ID_LIKE').split(/\s+/).filter(Boolean);
  const arch = id === 'arch' || like.includes('arch');
  let name = field('PRETTY_NAME') || field('NAME') || 'Linux';
  if (arch && id !== 'arch') name += ' (based on Arch Linux)';
  const omarchy = id === 'omarchy' || fs.existsSync('/usr/share/omarchy') ||
    fs.existsSync(path.join(os.homedir(), '.local', 'share', 'omarchy'));
  const desktop = process.env.HYPRLAND_INSTANCE_SIGNATURE ? 'Hyprland' : process.env.XDG_CURRENT_DESKTOP || '';
  const packages = ['pacman', 'apt', 'dnf', 'zypper'].find(onPath) || '';
  return {
    os: name,
    arch,
    omarchy,
    desktop: desktop && `${desktop}${process.env.WAYLAND_DISPLAY ? ' on Wayland' : ''}`,
    packages,
    aur: ['yay', 'paru'].filter(onPath),
    systemd: fs.existsSync('/run/systemd/system'),
  };
}

// ---------------------------------------------------------------- per-window session folder
// Each window is its own process, so give each one a private Chromium cache folder (a shared one
// can only be locked by the first window). It also holds the bash startup file below.
const sessionDir = path.join(os.tmpdir(), `aiterm-session-${process.pid}`);
app.setPath('sessionData', sessionDir);

function cleanOldSessions() {
  for (const name of fs.readdirSync(os.tmpdir())) {
    const pid = Number(name.match(/^aiterm-session-(\d+)$/)?.[1]);
    if (!pid || pid === process.pid) continue;
    try { process.kill(pid, 0); continue; } catch {} // that window is still open
    try { fs.rmSync(path.join(os.tmpdir(), name), { recursive: true, force: true }); } catch {}
  }
}

// ---------------------------------------------------------------- shell

const isDir = (dir) => {
  try { return !!dir && fs.statSync(dir).isDirectory(); } catch { return false; }
};

// `aiterm ~/code` opens there; `aiterm` opens in the directory it was typed in. Launches from the
// app launcher start in / or $HOME, so / falls back to home.
function pickCwd() {
  const args = process.argv.slice(app.isPackaged ? 1 : 2).filter((a) => !a.startsWith('-') && a !== '.');
  const fromArg = args.map((a) => path.resolve(a.replace(/^~(?=$|\/)/, os.homedir()))).find(isDir);
  if (fromArg) return fromArg;
  if (isDir(process.env.COMPANION_CWD)) return process.env.COMPANION_CWD;
  const cwd = process.cwd();
  if (cwd === '/' || cwd.startsWith(path.dirname(process.execPath))) return os.homedir();
  return cwd;
}

// Runs your normal ~/.bashrc, then reports the current directory before every prompt (OSC 7) so
// the AI knows where you are. $? is preserved so prompts like starship still show exit codes.
const BASH_HOOK = `[ -f ~/.bashrc ] && . ~/.bashrc
__aiterm_cwd() { local s=$?; printf '\\033]7;file://%s%s\\007' "\${HOSTNAME:-localhost}" "$PWD"; return $s; }
PROMPT_COMMAND="__aiterm_cwd\${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
`;

function shellCommand() {
  const exe = config.shell;
  if (path.basename(exe) === 'bash') {
    fs.mkdirSync(sessionDir, { recursive: true });
    const rc = path.join(sessionDir, 'bashrc');
    fs.writeFileSync(rc, BASH_HOOK);
    return { exe, args: ['--rcfile', rc, '-i'] };
  }
  // zsh, fish, ...: work normally, but without the hook the AI only sees the directory in your prompt text.
  return { exe, args: ['-i'] };
}

let win = null;
let shell = null;
const requests = new Map();

function startShell(cols, rows) {
  const { exe, args } = shellCommand();
  const proc = pty.spawn(exe, args, {
    name: 'xterm-256color',
    cols,
    rows,
    cwd: pickCwd(),
    env: { ...process.env, TERM: 'xterm-256color', COLORTERM: 'truecolor', TERM_PROGRAM: 'aiterm' },
  });
  shell = proc;
  proc.onData((data) => win && !win.isDestroyed() && win.webContents.send('pty:data', data));
  proc.onExit(({ exitCode }) => {
    if (shell === proc) shell = null;
    if (win && !win.isDestroyed()) win.webContents.send('pty:exit', exitCode);
  });
  return { shell: path.basename(exe), system: systemInfo() };
}

// Hang up the shell (like closing a terminal window) and wait for it to exit, killing it if it
// ignores the hang-up, so node-pty isn't still reporting the exit while the app shuts down.
let shellExited = Promise.resolve();
function killShell() {
  if (!shell) return shellExited;
  const proc = shell;
  shell = null;
  shellExited = new Promise((resolve) => {
    const timer = setTimeout(() => {
      try { proc.kill('SIGKILL'); } catch {}
      resolve();
    }, 2000);
    proc.onExit(() => {
      clearTimeout(timer);
      setTimeout(resolve, 100);
    });
  });
  try { proc.kill('SIGHUP'); } catch {}
  return shellExited;
}

// ---------------------------------------------------------------- LLM

async function streamChat(id, messages, signal) {
  const send = (channel, payload) => win && !win.isDestroyed() && win.webContents.send(channel, { id, ...payload });
  try {
    await llm.chat(messages, signal, (text) => send('ai:chunk', { text }));
    send('ai:done', {});
  } catch (err) {
    if (err.name === 'AbortError') send('ai:done', { cancelled: true });
    else send('ai:error', { message: `${err.message} (Servers are set in ${CONFIG_PATH}.)` });
  } finally {
    requests.delete(id);
  }
}

// ---------------------------------------------------------------- window

function createWindow() {
  win = new BrowserWindow({
    width: 800,
    height: 620,
    useContentSize: true,
    show: false, // shown once the renderer has sized it to the terminal grid
    backgroundColor: '#0f1117',
    title: 'AI Terminal Companion',
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  Menu.setApplicationMenu(null);
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  // The panel hotkey is caught here, before the page sees it, so it works no matter what has focus.
  win.webContents.on('before-input-event', (event, input) => {
    if (input.type !== 'keyDown' || input.isAutoRepeat) return;
    const plain = !input.control && !input.alt && !input.shift && !input.meta;
    const isHotkey = plain && input.key.toLowerCase() === config.hotkey.toLowerCase();
    const isAlternate = input.control && input.code === 'Backquote';
    if (isHotkey || isAlternate) {
      event.preventDefault();
      win.webContents.send('panel:toggle');
    }
  });
  // Safety net: never leave the window hidden if the renderer fails to size it.
  setTimeout(() => win && !win.isDestroyed() && !win.isVisible() && win.show(), 3000);
  win.on('closed', () => {
    win = null;
    killShell();
  });
}

ipcMain.handle('panel:hotkey', () => config.hotkey);

// Tiling window managers (Hyprland) decide the size of tiled windows themselves and ignore this;
// it applies to floating windows.
ipcMain.handle('window:size-to', (_e, { width, height }) => {
  if (!win || win.isDestroyed()) return;
  const { workArea } = screen.getDisplayMatching(win.getBounds());
  win.setContentSize(Math.min(Math.round(width), workArea.width), Math.min(Math.round(height), workArea.height - 40));
  win.center();
  win.show();
});

ipcMain.handle('pty:start', (_e, { cols, rows }) => (shell ? { shell: 'running' } : startShell(cols, rows)));
ipcMain.on('pty:write', (_e, data) => shell && shell.write(data));
ipcMain.on('pty:resize', (_e, { cols, rows }) => {
  if (shell && cols > 0 && rows > 0) shell.resize(cols, rows);
});

ipcMain.on('ai:ask', (_e, { id, messages }) => {
  const controller = new AbortController();
  requests.set(id, controller);
  streamChat(id, messages, controller.signal);
});
ipcMain.on('ai:cancel', (_e, id) => requests.get(id)?.abort());
ipcMain.on('ai:reset', () => llm.reset());
ipcMain.handle('ai:health', () => llm.health());

ipcMain.handle('clipboard:read', () => clipboard.readText());
ipcMain.on('clipboard:write', (_e, text) => clipboard.writeText(String(text)));

app.whenReady().then(() => {
  createWindow();
  setTimeout(cleanOldSessions, 5000);
});
let readyToQuit = false;
app.on('before-quit', (e) => {
  if (readyToQuit) return;
  e.preventDefault();
  killShell().then(() => {
    readyToQuit = true;
    app.quit();
  });
});
app.on('window-all-closed', () => app.quit());
