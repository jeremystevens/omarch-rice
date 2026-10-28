.pragma library

// Shared vocabulary for the NEXUS shell components: palette, the command
// menu's actions, identity.toml parsing, search matching, and the commands
// every action runs. Nothing here launches anything on its own.

var color = {
  deep: "#0c0d0d",
  char: "#121413",
  pane: "#181a19",
  line: "#2b2f2c",
  line2: "#3a3f3b",
  white: "#e9e6dc",
  grey: "#aaa79d",
  dim: "#868980",
  faint: "#61645e",
  phos: "#4dff88",
  phos2: "#2fa35e",
  phos3: "#163d27",
  amber: "#ffb347",
  red: "#ff5f56"
}

var mono = "JetBrainsMono Nerd Font"
var pix = "Silkscreen"

// The NEXUS ANSI mark: half-block letterforms, drawn with a hard drop shadow.
var mark = [
  "█▀▄  █ █▀▀▀▀ ▀▄   ▄▀ █   █ ▄▀▀▀▀",
  "█  ▀▄█ █▄▄▄    ▀▄▀   █   █ ▀▄▄▄ ",
  "█    █ █      ▄▀ ▀▄  █   █     █",
  "▀    ▀ ▀▀▀▀▀ ▀     ▀  ▀▀▀  ▀▀▀▀ "
].join("\n")

// ---------------------------------------------------------------- commands

function focusWorkspace(id) {
  return ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"]
}
// Quickshell reports toplevel addresses without the 0x prefix Hyprland's
// address: selector needs.
function focusWindow(address) {
  var a = String(address || "")
  if (a.indexOf("0x") !== 0) a = "0x" + a
  return ["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + a + "\" })"]
}
function terminalIn(dir) { return ["setsid", "uwsm-app", "--", "xdg-terminal-exec", "--dir=" + dir] }
function editorIn(dir) { return ["setsid", "uwsm-app", "--", "xdg-terminal-exec", "--dir=" + dir, "nvim", "."] }
function filesIn(dir) { return ["setsid", "uwsm-app", "--", "nautilus", "--new-window", dir] }
function openFile(path) { return ["setsid", "uwsm-app", "--", "xdg-open", path] }
function shellToggle(id) { return ["omarchy-shell", "shell", "toggle", id, "{}"] }

// Menu-mode actions. `list` opens a numbered sub-list instead of running.
var actions = [
  { key: "t", label: "terminal",    run: ["omarchy-launch-terminal"] },
  { key: "`", label: "scratch terminal", run: ["sh", "-c", "exec \"$HOME/.config/nexus/bin/nexus-scratch\" toggle"] },
  { key: "p", label: "projects",    list: "projects" },
  { key: "w", label: "windows",     list: "windows" },
  { key: "r", label: "recent",      list: "recent" },
  { key: "e", label: "editor",      run: ["omarchy-launch-editor"] },
  { key: "b", label: "browser",     run: ["omarchy-launch-browser"] },
  { key: "f", label: "files",       run: ["omarchy-launch-nautilus"] },
  { key: "k", label: "clipboard",   run: shellToggle("omarchy.clipboard") },
  { key: "i", label: "wifi",        run: shellToggle("omarchy.network") },
  { key: "h", label: "bluetooth",   run: shellToggle("omarchy.bluetooth") },
  { key: "v", label: "volume",      run: shellToggle("omarchy.audio") },
  { key: "n", label: "night light", run: ["omarchy-toggle-nightlight"] },
  { key: "c", label: "screenshot",  run: ["omarchy-capture-screenshot"] },
  { key: "l", label: "lock",        run: ["omarchy-system-lock"] },
  { key: "s", label: "sessions",    list: "sessions" },
  { key: "j", label: "jobs",        list: "jobs" },
  { key: "x", label: "failures",    list: "failures" },
  { key: "d", label: "dev toolbox", list: "toolbox" },
  { key: "?", label: "all keys",    run: ["omarchy-menu-keybindings"] }
]

function actionForKey(text) {
  for (var i = 0; i < actions.length; i++) if (actions[i].key === text) return actions[i]
  return null
}

// ---------------------------------------------------------------- identity

// Reads the small subset of TOML identity.toml uses: [sections],
// key = "string" | true | false | number, and # comments.
function parseToml(text) {
  var out = {}, section = out
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (!line || line.charAt(0) === "#") continue
    var sec = line.match(/^\[([^\]]+)\]$/)
    if (sec) { section = out[sec[1]] = out[sec[1]] || {}; continue }
    var kv = line.match(/^("?)([^"=]+?)\1\s*=\s*(.+)$/)
    if (!kv) continue
    var raw = kv[3].replace(/\s+#.*$/, "")
    var value
    var str = raw.match(/^"((?:[^"\\]|\\.)*)"$/)
    if (str) value = str[1].replace(/\\"/g, "\"").replace(/\\\\/g, "\\")
    else if (raw === "true" || raw === "false") value = raw === "true"
    else if (!isNaN(Number(raw))) value = Number(raw)
    else continue
    section[kv[2].replace(/\s+$/, "")] = value
  }
  return out
}

function projectsFrom(identity, home) {
  var list = []
  var p = identity.projects || {}
  for (var name in p) {
    var path = String(p[name])
    list.push({ name: name, path: path, dir: path.replace(/^~/, home) })
  }
  return list
}

// ---------------------------------------------------------------- display

function shortPath(path, home) {
  var s = String(path || "")
  if (home && s.indexOf(home) === 0) s = "~" + s.slice(home.length)
  return s
}
function dirOf(path, home) {
  var s = shortPath(path, home)
  var i = s.lastIndexOf("/")
  return i > 0 ? s.slice(0, i) : s
}
function baseName(path) {
  var s = String(path || "")
  return s.slice(s.lastIndexOf("/") + 1)
}

function appOf(toplevel) {
  if (!toplevel) return ""
  if (toplevel.wayland && toplevel.wayland.appId) {
    var id = String(toplevel.wayland.appId)
    return id.slice(id.lastIndexOf(".") + 1) || id
  }
  var ipc = toplevel.lastIpcObject
  return ipc && ipc["class"] ? String(ipc["class"]) : "window"
}

// ---------------------------------------------------------------- search

// Case-insensitive substring match. Earlier and word-start matches rank
// higher. Returns null when there is no match, otherwise
// { score, start, end } for highlighting. (Loose subsequence matching was
// dropped: "tri" matched half the window titles on screen.)
function match(query, text) {
  var q = String(query || "").toLowerCase(), t = String(text || "").toLowerCase()
  if (!q) return { score: 0, start: -1, end: -1 }
  var at = t.indexOf(q)
  if (at === -1) return null
  var wordStart = at === 0 || !/[a-z0-9]/.test(t.charAt(at - 1))
  return { score: 100 - Math.min(at, 60) + (wordStart ? 25 : 0), start: at, end: at + q.length }
}

function escapeHtml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}
function highlight(text, m, colour) {
  if (!m || m.start < 0) return escapeHtml(text)
  return escapeHtml(text.slice(0, m.start)) + "<b><font color='" + colour + "'>"
    + escapeHtml(text.slice(m.start, m.end)) + "</font></b>" + escapeHtml(text.slice(m.end))
}

// ---------------------------------------------------------------- readouts

function rate(bytesPerSecond) {
  if (bytesPerSecond === null || bytesPerSecond === undefined) return "—"
  var b = bytesPerSecond
  if (b < 1024) return Math.round(b) + "B"
  if (b < 1048576) return Math.round(b / 1024) + "K"
  return (b / 1048576).toFixed(1) + "M"
}
function tempColor(c) {
  if (c === null || c === undefined) return color.dim
  if (c >= 85) return color.red
  if (c >= 70) return color.amber
  return color.white
}
function batteryColor(pct, status) {
  if (pct === null || pct === undefined) return color.dim
  if (status === "Charging" || status === "Full") return color.white
  if (pct <= 10) return color.red
  if (pct <= 20) return color.amber
  return color.white
}

// ---------------------------------------------------------------- dev

var home = ""
function bin(name) { return home + "/.config/nexus/bin/" + name }

// "main ↑1 · 2 staged · 3 changed · 1 new" / "main · clean" / "" (no git)
function gitSummary(g) {
  if (!g) return ""
  var head = g.detached ? "detached " + g.commit : g.branch
  if (g.ahead) head += " ↑" + g.ahead
  if (g.behind) head += " ↓" + g.behind
  if (g.clean) return head + " · clean"
  var parts = []
  if (g.conflicted) parts.push(g.conflicted + " conflict" + (g.conflicted === 1 ? "" : "s"))
  if (g.staged) parts.push(g.staged + " staged")
  if (g.unstaged) parts.push(g.unstaged + " changed")
  if (g.untracked) parts.push(g.untracked + " new")
  return head + " · " + parts.join(" · ")
}
// Compact form for project rows: "main ●3 ↑1", "main ✓", "detached a1b2c3d ●1".
function gitCompact(g) {
  if (!g) return ""
  var out = g.detached ? "detached " + g.commit : g.branch
  var changes = g.staged + g.unstaged + g.untracked
  if (g.conflicted) out += " !" + g.conflicted
  if (changes) out += " ●" + changes
  if (!g.conflicted && !changes) out += " ✓"
  if (g.ahead) out += " ↑" + g.ahead
  if (g.behind) out += " ↓" + g.behind
  return out
}
// Project tmux session: open in a terminal, running in the background, or
// only a saved layout Resume can rebuild.
function sessionMark(s) {
  if (!s) return ""
  if (s.attached) return "▶ open"
  if (s.live) return "◆ running"
  if (s.saved) return "◇ saved"
  return ""
}
// One-line project row text: git, session, or the path when there is neither.
function projectSub(inf, path) {
  if (inf && !inf.exists) return "missing · " + path
  if (!inf) return path
  var parts = []
  if (inf.git) parts.push(gitCompact(inf.git))
  var m = sessionMark(inf.session)
  if (m) parts.push(m)
  return parts.length ? parts.join("  ·  ") : path
}

function gitColor(g) {
  if (!g) return color.dim
  if (g.conflicted) return color.red
  return g.clean ? color.dim : color.amber
}

// Failure inbox: a run that failed and nobody resolved, dismissed or
// superseded yet.
function isOpenFailure(r) {
  return r.status === "failed" && !r.resolved_at && !r.dismissed_at && !r.superseded_by
}
function clock(epoch) {
  var d = new Date(epoch * 1000)
  var hh = d.getHours(), mm = d.getMinutes()
  var today = new Date().toDateString() === d.toDateString()
  return (today ? "" : (d.getMonth() + 1) + "/" + d.getDate() + " ") + (hh < 10 ? "0" : "") + hh + ":" + (mm < 10 ? "0" : "") + mm
}
function failureFate(r) {
  if (r.resolved_at) return "resolved " + clock(r.resolved_at) + " by a passing run"
  if (r.superseded_by) return "replaced by a newer failure"
  if (r.dismissed_at) return "dismissed " + clock(r.dismissed_at)
  return ""
}

// State of a task started through nexus-task.
function jobState(j) {
  if (j.running) return "running"
  if (j.state === "cancelled") return "cancelled"
  if (j.exitCode === 0) return "done"
  if (j.exitCode === null || j.exitCode === undefined) return "stopped"
  return "exit " + j.exitCode
}
function jobColor(j) {
  if (j.running) return color.phos
  if (j.state === "cancelled") return color.grey
  if (j.exitCode === 0) return color.dim
  if (j.exitCode === null || j.exitCode === undefined) return color.grey
  return color.amber
}
