import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../../nexus/lib/Nx.js" as Nx

// NEXUS command line and command menu.
//
// The command line is a 30 px strip above the status line; clicking it (or
// SUPER ;) opens the menu. Input is explicit in three modes:
//
//   menu    one letter runs its action; ▸ actions open a list.
//           "/" enters search. Esc closes.
//   list    digits 1-9 or ↑↓ + Return pick a row; each list's own letters
//           are shown in its header. Esc goes back one level.
//   search  every key is text; nothing triggers a shortcut. ↑↓ choose,
//           Return runs. Esc clears and returns to menu mode.
//
// Lists: projects (a adds one from folders found under ~, x twice removes the
// highlighted one from the list; the folder is never touched) → a project (git status, t/e/f/g/v actions, numbered tasks
// from its manifests), windows, recent files, tmux sessions, jobs (tasks
// started here, with live output, server link and stop), and the dev
// toolbox. Discovery only reads files; tasks run only when you pick one.
//
// IPC (omarchy-shell nexus ...): menu, search, jobs, failures, projects, addProject,
// project DIR, close, state.
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  property bool open: false
  property string mode: "menu"       // menu | list | search
  property string listKind: ""       // projects | addproject | project | windows | recent | sessions | jobs | failures | failure | toolbox
  property int cursor: 0
  property string query: ""
  property string textScope: ""      // project folder searched by text (search mode), or "" for everything
  property var fileHits: []          // live results from nexus-search, each tagged with its query
  property var noteHits: []
  property var textHits: []
  property string projectDir: ""     // the project open in the "project" list

  property var identity: ({})
  readonly property var projects: Nx.projectsFrom(identity, home)
  property var info: ({})            // dir -> { git, tasks, exists }
  property var candidates: []       // unlisted project folders, for "addproject"
  property string removeArmed: ""   // dir of the project the next x removes
  property var recent: []
  property var sessions: []
  property var jobs: []
  property var runs: []               // recorded task runs (failure inbox), newest first
  property string failureId: ""       // the run open in the "failure" list
  property var refs: []               // file:line references in that run's output
  property string failureOutput: ""
  readonly property int openFailures: runs.filter(Nx.isOpenFailure).length
  property string jobOutput: ""
  property var versions: ({})
  property bool podmanUp: false
  readonly property var windows: {
    var out = [], tops = Hyprland.toplevels.values
    for (var i = 0; i < tops.length; i++) out.push(tops[i])
    return out
  }

  Component.onCompleted: Nx.home = root.home

  function show(startMode, kind) {
    refreshAll()
    root.mode = startMode || "menu"
    root.listKind = kind || ""
    root.query = ""
    root.cursor = 0
    root.open = true
    Qt.callLater(root.takeFocus)
  }
  function close() {
    root.open = false
    root.mode = "menu"
    root.query = ""
    root.textScope = ""
  }
  function takeFocus() {
    if (root.mode === "search") { searchInput.text = root.query; searchInput.forceActiveFocus() }
    else keyCatcher.forceActiveFocus()
  }
  function setMode(next) {
    root.mode = next
    root.cursor = 0
    if (next !== "search") { root.query = ""; root.textScope = "" }
    Qt.callLater(root.takeFocus)
  }
  function openList(kind) {
    root.listKind = kind
    root.removeArmed = ""
    if (kind === "addproject") { root.candidates = []; scanProc.running = true }
    if (kind === "jobs") jobsProc.running = true
    if (kind === "failures") runsProc.running = true
    if (kind === "sessions") sessionsProc.running = true
    if (kind === "toolbox") { if (!root.versions.git) versionsProc.running = true; podmanProc.running = true }
    root.setMode("list")
  }
  function openProject(dir) { root.projectDir = dir; infoProc.refresh(); root.openList("project") }
  function back() {
    if (root.listKind === "project" || root.listKind === "addproject") root.openList("projects")
    else if (root.listKind === "failure") root.openList("failures")
    else root.setMode("menu")
  }

  // Actions run a moment after the menu lets go of the keyboard; otherwise
  // focusing a window loses to Hyprland restoring the previous focus.
  property var pending: null
  function run(argv) { pending = argv; runTimer.restart() }
  Timer { id: runTimer; interval: 250; onTriggered: { if (root.pending) Quickshell.execDetached(root.pending); root.pending = null } }
  function runNow(argv) { Quickshell.execDetached(argv) }

  function refreshAll() {
    recentProc.running = true
    infoProc.refresh()
    sessionsProc.running = true
    jobsProc.running = true
    runsProc.running = true
  }
  function runById(id) {
    for (var i = 0; i < runs.length; i++) if (runs[i].id === id) return runs[i]
    return null
  }
  function openFailure(id) {
    root.failureId = id
    root.refs = []
    root.failureOutput = ""
    refsProc.command = [Nx.bin("nexus-task"), "refs", id]; refsProc.running = true
    failTailProc.command = [Nx.bin("nexus-task"), "log-tail", id, "12"]; failTailProc.running = true
    root.openList("failure")
  }

  function projectByDir(dir) {
    for (var i = 0; i < projects.length; i++) if (projects[i].dir === dir) return projects[i]
    return null
  }

  // ---------------------------------------------------------- entries
  // Entries are what lists and search show: { kind, title, sub, ... }.
  function projectEntries() {
    return projects.map(function(p) {
      var inf = root.info[p.dir]
      return { kind: "project", title: p.name, dir: p.dir,
               sub: Nx.projectSub(inf, p.path) }
    })
  }
  function addEntries() {
    return candidates.map(function(c) {
      return { kind: "addproj", title: c.name, sub: c.path + (c.git ? "  ·  git" : ""), dir: c.dir }
    })
  }
  function removeProject(entry) {
    runNow([Nx.bin("nexus-project"), "rm", entry.dir])
    notify("Removed " + entry.title + " from projects", "The folder " + Nx.shortPath(entry.dir, root.home) + " is untouched")
    root.removeArmed = ""
    if (root.cursor > 0) root.cursor--
  }
  function projectActionEntries() {
    var inf = root.info[root.projectDir], s = inf && inf.session
    var resumeSub = !s ? "reattach the project session, or rebuild it"
      : s.attached ? "already open: focus its terminal"
      : s.live ? "reattach the running session"
      : s.saved ? "rebuild the saved layout (nothing restarts)"
      : "new session: nvim + a shell"
    var list = [
      { kind: "pact", key: "r", title: "resume", sub: resumeSub, act: "resume" },
      { kind: "pact", key: "t", title: "terminal", sub: "tmux session in the project", act: "term" },
      { kind: "pact", key: "e", title: "editor", sub: "nvim", act: "edit" },
      { kind: "pact", key: "f", title: "files", sub: "file manager", act: "files" },
      { kind: "pact", key: "g", title: "git", sub: "lazygit", act: "git" },
      { kind: "pact", key: "v", title: "env file", sub: ".env from .env.example, kept out of git", act: "env" },
      { kind: "pact", key: "/", title: "search text", sub: "inside this project's files (ignored and secret files skipped)", act: "grep" }
    ]
    if (inf && inf.git) list.splice(5, 0, { kind: "pact", key: "d", title: "diff", sub: "changes against HEAD, untracked files listed", act: "diff" })
    return list
  }
  function taskEntries(dir) {
    var inf = root.info[dir], p = projectByDir(dir)
    if (!inf || !inf.tasks) return []
    return inf.tasks.map(function(t) {
      return { kind: "task", title: t.label, sub: t.argv.join(" ") + "  ·  " + t.source, dir: dir,
               project: p ? p.name : Nx.baseName(dir), task: t }
    })
  }
  function windowEntries() {
    return windows.map(function(w) {
      return { kind: "window", title: Nx.appOf(w) + (w.title ? " · " + w.title : ""),
               sub: w.workspace ? "workspace " + w.workspace.id : "", address: w.address }
    })
  }
  function searchText(dir) {
    root.textScope = dir
    root.textHits = []
    searchInput.text = ""
    root.setMode("search")
  }
  // Leave search mode: a project text search goes back to that project.
  function leaveSearch() {
    var scope = root.textScope
    searchInput.text = ""
    if (scope) { root.setMode("list"); root.openProject(scope) } else root.setMode("menu")
  }
  function projectFor(path) {
    for (var i = 0; i < projects.length; i++) if (path.indexOf(projects[i].dir + "/") === 0) return projects[i]
    return null
  }
  function fileEntries() {
    return fileHits.map(function(h) {
      var p = projectFor(h.path), rel = h.path.slice(h.root.length + 1)
      return { kind: "pfile", title: Nx.baseName(h.path), sub: (p ? p.name : Nx.shortPath(h.root, root.home)) + " · " + Nx.dirOf(rel, ""), path: h.path, dir: h.root }
    })
  }
  function noteEntries() {
    return noteHits.map(function(h) {
      return { kind: "note", title: Nx.baseName(h.path).replace(/\.(md|markdown|txt|org)$/, ""), sub: Nx.shortPath(Nx.dirOf(h.path, ""), root.home), path: h.path, dir: h.root }
    })
  }
  function matchEntries() {
    return textHits.map(function(h) {
      var rel = h.path.slice(h.root.length + 1)
      return { kind: "match", title: rel + ":" + h.line, sub: h.text, dir: h.root, ref: { file: h.path, line: h.line, col: h.col } }
    })
  }

  function recentEntries() {
    return recent.map(function(r) { return { kind: "file", title: Nx.baseName(r.path), sub: Nx.dirOf(r.path, root.home), path: r.path } })
  }
  function sessionEntries() {
    return sessions.map(function(s) {
      return { kind: "session", title: s.name, name: s.name,
               sub: s.windows + " window" + (s.windows === 1 ? "" : "s") + (s.attached ? " · attached" : "") + " · " + Nx.shortPath(s.path, root.home) }
    })
  }
  function jobEntries() {
    return jobs.map(function(j) {
      return { kind: "job", title: j.project + " · " + j.label, job: j,
               sub: Nx.jobState(j) + (j.url ? " · " + j.url : "") }
    })
  }
  function failureEntries() {
    var open = runs.filter(Nx.isOpenFailure), hist = runs.filter(function(r) { return r.status === "failed" && !Nx.isOpenFailure(r) })
    function row(r, history) {
      return { kind: "failure", history: history, run: r, title: r.project + " · " + r.label,
               sub: history ? Nx.failureFate(r) : "exit " + r.exit + "  ·  " + Nx.clock(r.ended || r.started) }
    }
    return open.map(function(r) { return row(r, false) }).concat(hist.slice(0, 8).map(function(r) { return row(r, true) }))
  }
  function failureActionEntries() {
    var r = runById(failureId)
    if (!r) return []
    var list = [
      { kind: "fact", key: "o", title: "full output", sub: "saved log, end of output first", act: "output" },
      { kind: "fact", key: "r", title: "rerun", sub: r.argv.join(" ") + "  ·  in " + Nx.shortPath(r.dir, root.home), act: "rerun" }
    ]
    if (Nx.isOpenFailure(r)) list.push({ kind: "fact", key: "x", title: "dismiss", sub: "hide it; a passing run still counts as the fix", act: "dismiss" })
    return list
  }
  function refEntries() {
    var r = runById(failureId)
    return refs.map(function(f) {
      return { kind: "ref", title: f.rel + ":" + f.line + (f.col > 1 ? ":" + f.col : ""), sub: f.text, ref: f, dir: r ? r.dir : "" }
    })
  }
  function failureAction(act, r) {
    if (!r) return
    if (act === "output") { run([Nx.bin("nexus-task"), "output", r.id]); root.close(); return }
    if (act === "rerun") { startProc.command = [Nx.bin("nexus-task"), "rerun", r.id]; startProc.running = true; return }
    if (act === "dismiss") {
      runNow([Nx.bin("nexus-task"), "dismiss", r.id]); runsRefresh.restart()
      if (root.listKind === "failure") root.openList("failures")
    }
  }

  function actionEntries() {
    return Nx.actions.map(function(a) { return { kind: "action", title: a.label, sub: "key " + a.key, action: a } })
  }
  function toolboxEntries() {
    return [
      { kind: "tool", title: root.podmanUp ? "stop container socket" : "start container socket",
        sub: "podman.socket for compose · " + (root.podmanUp ? "running" : "stopped"),
        argv: ["systemctl", "--user", root.podmanUp ? "stop" : "start", "podman.socket"], stay: true },
      { kind: "tool", title: "editor health check", sub: "nvim :checkhealth",
        argv: ["setsid", "uwsm-app", "--", "xdg-terminal-exec", "nvim", "+checkhealth"] },
      { kind: "tool", title: "system monitor", sub: "btop", argv: ["omarchy-launch-or-focus-tui", "btop"] },
      { kind: "tool", title: "remove unused container images", sub: "podman image prune",
        argv: ["setsid", "uwsm-app", "--", "xdg-terminal-exec", "sh", "-c", "podman image prune; echo; read -rp 'done · Enter closes' _"] },
      { kind: "tool", title: "NEXUS developer guide", sub: "~/.config/nexus/README.md",
        argv: ["setsid", "uwsm-app", "--", "xdg-terminal-exec", "nvim", root.home + "/.config/nexus/README.md"] },
      { kind: "tool", title: "all keybindings", sub: "Omarchy key list", argv: ["omarchy-menu-keybindings"] }
    ]
  }

  readonly property var listEntries: {
    switch (listKind) {
      case "projects": return projectEntries().concat([{ kind: "addnew", title: "+ add a project", sub: "pick from folders found under ~" }])
      case "addproject": return addEntries()
      case "project": return projectActionEntries().concat(taskEntries(projectDir))
      case "windows": return windowEntries()
      case "recent": return recentEntries()
      case "sessions": return sessionEntries()
      case "jobs": return jobEntries()
      case "failures": return failureEntries()
      case "failure": return failureActionEntries().concat(refEntries())
      case "toolbox": return toolboxEntries()
    }
    return []
  }
  // Numbers address rows that have no letter of their own.
  function lettered() { return listKind === "project" ? projectActionEntries().length : (listKind === "failure" ? failureActionEntries().length : 0) }
  function numberOf(index) {
    var n = index - lettered()
    return n >= 0 ? n + 1 : 0
  }
  function entryForNumber(n) {
    return listEntries[lettered() + n - 1]
  }

  // Search results, grouped. Each group is scored on its own and capped, so
  // one busy group (windows, files) can't push the others off the list.
  readonly property var results: {
    if (mode !== "search") return []
    if (textScope) {
      return matchEntries().slice(0, 12).map(function(e, i) { e.group = i === 0 ? "text" : ""; return e })
    }
    var tasks = []
    for (var p = 0; p < projects.length; p++) tasks = tasks.concat(taskEntries(projects[p].dir))
    var groups = !query
      ? [["projects", projectEntries(), 4], ["recent", recentEntries(), 3], ["sessions", sessionEntries(), 2], ["jobs", jobEntries(), 2]]
      : [["actions", actionEntries(), 3], ["projects", projectEntries(), 3], ["tasks", tasks, 3],
         ["files", recentEntries().concat(fileEntries()), 4], ["notes", noteEntries(), 3],
         ["sessions", sessionEntries(), 2], ["jobs", jobEntries(), 2], ["windows", windowEntries(), 2]]
    var out = []
    for (var g = 0; g < groups.length; g++) {
      var name = groups[g][0], pool = groups[g][1], cap = groups[g][2], scored = []
      for (var i = 0; i < pool.length; i++) {
        var title = pool[i].kind === "task" ? pool[i].project + " · " + pool[i].title : pool[i].title
        var m = Nx.match(query, title)
        var ms = m ? null : Nx.match(query, pool[i].sub)
        if (!m && !ms) continue
        var e = Object.assign({}, pool[i])
        e.display = title
        e.match = m
        scored.push({ entry: e, score: m ? m.score : ms.score - 30 })
      }
      scored.sort(function(a, b) { return b.score - a.score })
      var seen = {}, taken = 0
      for (var k = 0; k < scored.length && taken < cap; k++) {
        var en = scored[k].entry
        if (en.path) { if (seen[en.path]) continue; seen[en.path] = true }
        en.group = taken === 0 ? name : ""
        out.push(en); taken++
      }
    }
    return out.slice(0, 14)
  }


  function projectAction(act, dir) {
    if (!dir) return
    if (act === "grep") { root.searchText(dir); return }
    if (act === "env") { runNow([Nx.bin("nexus-env"), dir]); notify("Env file ready in " + Nx.shortPath(dir, root.home), ".env stays out of git"); return }
    run([Nx.bin("nexus-dev"), act, dir])
    root.close()
  }

  function startTask(entry) {
    startProc.command = [Nx.bin("nexus-task"), "start", entry.dir, entry.project, entry.task.label, "--task-id", entry.task.id, "--"].concat(entry.task.argv)
    startProc.running = true
  }

  function notify(title, body) { runNow(["notify-send", "-a", "NEXUS", "-u", "low", title, body || ""]) }

  function exec(entry, key) {
    if (!entry) return
    switch (entry.kind) {
      case "action":
        if (entry.action.list) { root.openList(entry.action.list); return }
        run(entry.action.run); break
      case "project":
        if ("rtefgd".indexOf(key) !== -1 && key) { projectAction({ r: "resume", t: "term", e: "edit", f: "files", g: "git", d: "diff" }[key], entry.dir); return }
        root.openProject(entry.dir); return
      case "addnew": root.openList("addproject"); return
      case "addproj":
        runNow([Nx.bin("nexus-project"), "add", entry.dir])
        notify("Added " + entry.title + " to projects", Nx.shortPath(entry.dir, root.home))
        root.openList("projects")
        root.cursor = root.projects.length
        return
      case "pact": projectAction(entry.act, root.projectDir); return
      case "fact": failureAction(entry.act, runById(root.failureId)); return
      case "failure":
        if (key === "r" || key === "x" || key === "o") { failureAction({ r: "rerun", x: "dismiss", o: "output" }[key], entry.run); return }
        root.openFailure(entry.run.id); return
      case "ref": run([Nx.bin("nexus-task"), "open-ref", entry.dir, entry.ref.file, String(entry.ref.line), String(entry.ref.col)]); break
      case "task": startTask(entry); return
      case "window": run(Nx.focusWindow(entry.address)); break
      case "file": run(Nx.openFile(entry.path)); break
      case "pfile": case "note": run([Nx.bin("nexus-task"), "open-ref", entry.dir, entry.path, "1", "1"]); break
      case "match": run([Nx.bin("nexus-task"), "open-ref", entry.dir, entry.ref.file, String(entry.ref.line), String(entry.ref.col)]); break
      case "session": run([Nx.bin("nexus-dev"), "attach", entry.name]); break
      case "job":
        if (key === "s") { runNow([Nx.bin("nexus-task"), "stop", entry.job.id]); jobsRefresh.restart(); return }
        if (key === "o") { if (entry.job.url) run(["xdg-open", entry.job.url]); else return; break }
        run([Nx.bin("nexus-task"), "attach", entry.job.id]); break
      case "tool":
        runNow(entry.argv)
        if (entry.stay) { podmanTimer.restart(); return }
        break
    }
    root.close()
  }

  function moveCursor(delta, count) {
    if (count <= 0) return
    root.cursor = (root.cursor + delta + count) % count
  }

  // ---------------------------------------------------------- data
  FileView {
    path: root.home + "/.config/nexus/identity.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { root.identity = Nx.parseToml(text()); infoProc.refresh() }
    onLoadFailed: root.identity = ({})
  }
  Process {
    id: scanProc
    command: [root.home + "/.config/nexus/bin/nexus-project", "scan"]
    stdout: StdioCollector { onStreamFinished: { try { root.candidates = JSON.parse(text) } catch (e) { root.candidates = [] } } }
  }
  // Live searches: restarted (the old one killed) 150 ms after typing stops;
  // a result is used only if it still belongs to the current query.
  onQueryChanged: if (root.open && root.mode === "search") liveSearch.restart()
  onTextScopeChanged: if (root.open && root.mode === "search") liveSearch.restart()
  Timer {
    id: liveSearch
    interval: 150
    onTriggered: {
      var q = root.query
      filesProc.running = false; notesProc.running = false; textProc.running = false
      if (q.length < 2) { root.fileHits = []; root.noteHits = []; root.textHits = []; return }
      if (root.textScope) {
        textProc.forQuery = q
        textProc.command = [Nx.bin("nexus-search"), "text", root.textScope, q]
        textProc.running = true
        return
      }
      filesProc.forQuery = q
      filesProc.command = [Nx.bin("nexus-search"), "files", q].concat(root.projects.map(function(p) { return p.dir }))
      filesProc.running = true
      notesProc.forQuery = q
      notesProc.command = [Nx.bin("nexus-search"), "notes", q]
      notesProc.running = true
    }
  }
  Process {
    id: filesProc
    property string forQuery: ""
    stdout: StdioCollector { onStreamFinished: { if (filesProc.forQuery !== root.query) return; try { root.fileHits = JSON.parse(text) } catch (e) {} } }
  }
  Process {
    id: notesProc
    property string forQuery: ""
    stdout: StdioCollector { onStreamFinished: { if (notesProc.forQuery !== root.query) return; try { root.noteHits = JSON.parse(text) } catch (e) {} } }
  }
  Process {
    id: textProc
    property string forQuery: ""
    stdout: StdioCollector { onStreamFinished: { if (textProc.forQuery !== root.query) return; try { root.textHits = JSON.parse(text) } catch (e) {} } }
  }
  Process {
    id: recentProc
    command: [root.home + "/.config/nexus/bin/nexus-recent", "9"]
    stdout: StdioCollector { onStreamFinished: { try { root.recent = JSON.parse(text) } catch (e) { root.recent = [] } } }
  }
  Process {
    id: infoProc
    function refresh() {
      if (root.projects.length === 0) return
      command = [root.home + "/.config/nexus/bin/nexus-dev", "info"].concat(root.projects.map(function(p) { return p.dir }))
      running = true
    }
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var map = {}, list = JSON.parse(text)
          for (var i = 0; i < list.length; i++) map[list[i].dir] = list[i]
          root.info = map
        } catch (e) {}
      }
    }
  }
  Process {
    id: sessionsProc
    command: [root.home + "/.config/nexus/bin/nexus-dev", "sessions"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          // The task runner's own session is shown under jobs, not here.
          root.sessions = JSON.parse(text).filter(function(s) { return s.name !== "nexus-tasks" })
        } catch (e) { root.sessions = [] }
      }
    }
  }
  Process {
    id: jobsProc
    command: [root.home + "/.config/nexus/bin/nexus-task", "list"]
    stdout: StdioCollector { onStreamFinished: { try { root.jobs = JSON.parse(text) } catch (e) { root.jobs = [] } } }
  }
  Process {
    id: runsProc
    command: [root.home + "/.config/nexus/bin/nexus-task", "runs"]
    stdout: StdioCollector { onStreamFinished: { try { root.runs = JSON.parse(text) } catch (e) { root.runs = [] } } }
  }
  Timer { id: runsRefresh; interval: 300; onTriggered: runsProc.running = true }
  Process {
    id: refsProc
    stdout: StdioCollector { onStreamFinished: { try { root.refs = JSON.parse(text) } catch (e) { root.refs = [] } } }
  }
  Process {
    id: failTailProc
    stdout: StdioCollector { onStreamFinished: root.failureOutput = text }
  }
  Process {
    id: tailProc
    stdout: StdioCollector { onStreamFinished: root.jobOutput = text }
  }
  Process {
    id: startProc
    stdout: StdioCollector {
      onStreamFinished: {
        // Show the new job with its output straight away.
        root.openList("jobs")
        root.cursor = root.jobs.length
      }
    }
  }
  Process {
    id: versionsProc
    command: [root.home + "/.config/nexus/bin/nexus-dev", "versions"]
    stdout: StdioCollector { onStreamFinished: { try { root.versions = JSON.parse(text) } catch (e) {} } }
  }
  Process {
    id: podmanProc
    command: ["systemctl", "--user", "is-active", "--quiet", "podman.socket"]
    onExited: function(code) { root.podmanUp = code === 0 }
  }
  Timer { id: podmanTimer; interval: 600; onTriggered: podmanProc.running = true }
  Timer { id: jobsRefresh; interval: 400; onTriggered: jobsProc.running = true }

  // Live job list and output, only while the jobs list is on screen.
  Timer {
    running: root.open && root.mode === "list" && root.listKind === "jobs"
    interval: 1500
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      jobsProc.running = true
      var j = root.jobs[Math.min(root.cursor, root.jobs.length - 1)]
      if (j) { tailProc.command = [root.home + "/.config/nexus/bin/nexus-task", "tail", j.id, "12"]; tailProc.running = true }
      else root.jobOutput = ""
    }
  }

  IpcHandler {
    target: "nexus"
    function menu(): void { if (root.open) root.close(); else root.show("menu") }
    function search(): void { root.show("search") }
    function jobs(): void { root.show("menu"); root.openList("jobs") }
    function failures(): void { root.show("menu"); root.openList("failures") }
    function projects(): void { root.show("menu"); root.openList("projects") }
    function addProject(): void { root.show("menu"); root.openList("addproject") }
    function project(dir: string): void { root.show("menu"); root.openProject(dir) }
    function close(): void { root.close() }
    function state(): string {
      return root.open ? root.mode + (root.mode === "list" ? ":" + root.listKind : "") + (root.mode === "search" ? ":" + root.query : "") : "closed"
    }
  }

  // ---------------------------------------------------------- command line
  PanelWindow {
    id: strip
    anchors { left: true; right: true; bottom: true }
    implicitHeight: 30
    exclusiveZone: 30
    color: Nx.color.pane
    WlrLayershell.namespace: "nexus-command-line"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle { width: parent.width; height: 1; color: Nx.color.line }
    Row {
      x: 14; anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      Text { text: "nexus ▸"; color: Nx.color.phos; font.family: Nx.mono; font.pixelSize: 13; font.weight: Font.Bold }
      Text {
        text: !root.open ? "" : (root.mode === "search" ? "/" + root.query : (root.mode === "list" ? (root.listKind === "project" ? "project " + Nx.baseName(root.projectDir) : (root.listKind === "addproject" ? "add project" : root.listKind)) : ""))
        color: Nx.color.white; font.family: Nx.mono; font.pixelSize: 13
      }
      Rectangle {
        width: 8; height: 15; color: Nx.color.white
        anchors.verticalCenter: parent.verticalCenter
        visible: root.open && root.mode === "search"
      }
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
      text: !root.open ? "S ; menu · S B rail"
        : (root.mode === "search" ? "↑↓ choose · ↵ run · esc back"
          : (root.mode === "list" ? "1–9 or ↑↓ ↵ · esc back" : "letter runs · / search · esc close"))
      color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.open ? root.close() : root.show("menu")
    }
  }

  // ---------------------------------------------------------- menu
  PanelWindow {
    id: menuWindow
    visible: root.open
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    WlrLayershell.namespace: "nexus-command-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: root.mode !== "search"
      Keys.onPressed: function(event) {
        var k = event.key, txt = event.text
        if (root.mode === "menu") {
          if (k === Qt.Key_Escape) root.close()
          else if (txt === "/") root.setMode("search")
          else {
            var a = Nx.actionForKey(txt.toLowerCase())
            if (!a) return
            root.exec({ kind: "action", action: a }, "")
          }
        } else if (root.mode === "list") {
          var entries = root.listEntries, n = entries.length, cur = entries[root.cursor]
          if (root.listKind === "projects" && txt === "x" && cur && cur.kind === "project") {
            if (root.removeArmed === cur.dir) root.removeProject(cur); else root.removeArmed = cur.dir
            event.accepted = true; return
          }
          if (root.removeArmed) { root.removeArmed = ""; if (k === Qt.Key_Escape) { event.accepted = true; return } }
          if (k === Qt.Key_Escape) root.back()
          else if (k >= Qt.Key_1 && k <= Qt.Key_9) { var e = root.entryForNumber(k - Qt.Key_0); if (e) root.exec(e, "") }
          else if (k === Qt.Key_Down || k === Qt.Key_Tab) root.moveCursor(1, n)
          else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.moveCursor(-1, n)
          else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.exec(cur, "")
          else if (root.listKind === "project" && txt) {
            var acts = root.projectActionEntries()
            for (var i = 0; i < acts.length; i++) if (acts[i].key === txt) { root.exec(acts[i], ""); event.accepted = true; return }
            return
          }
          else if (root.listKind === "projects" && txt === "a") root.openList("addproject")
          else if (root.listKind === "projects" && txt && "rtefgd".indexOf(txt) !== -1 && cur && cur.kind === "project") root.exec(cur, txt)
          else if (root.listKind === "jobs" && (txt === "s" || txt === "o") && cur) root.exec(cur, txt)
          else if (root.listKind === "jobs" && txt === "c") { root.runNow([Nx.bin("nexus-task"), "clear"]); jobsRefresh.restart() }
          else if (root.listKind === "failures" && (txt === "r" || txt === "x" || txt === "o") && cur && cur.kind === "failure" && !(txt === "x" && cur.history)) root.exec(cur, txt)
          else if (root.listKind === "failures" && txt === "c") { root.runNow([Nx.bin("nexus-task"), "history-clear"]); runsRefresh.restart() }
          else if (root.listKind === "failure" && txt) {
            var facts = root.failureActionEntries()
            for (var fi = 0; fi < facts.length; fi++) if (facts[fi].key === txt) { root.exec(facts[fi], ""); event.accepted = true; return }
            return
          }
          else return
        } else return
        event.accepted = true
      }
    }

    Rectangle {
      id: card
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      width: 760
      height: content.implicitHeight + 28
      color: Nx.color.deep
      border.color: Nx.color.phos
      border.width: 1

      MouseArea { anchors.fill: parent }  // clicks inside never close the menu

      Column {
        id: content
        x: 16; y: 14
        width: card.width - 32
        spacing: 10

        // Header: mode badge and the keys for this view.
        Item {
          width: parent.width; height: 20
          Rectangle {
            id: badge
            width: badgeText.implicitWidth + 12; height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: root.mode === "search" ? Nx.color.amber : Nx.color.phos
            Text {
              id: badgeText
              anchors.centerIn: parent
              text: root.mode === "search" ? "SEARCH" : (root.mode === "list"
                ? (root.listKind === "project" ? Nx.baseName(root.projectDir).toUpperCase() : (root.listKind === "addproject" ? "ADD PROJECT" : (root.listKind === "failure" ? "FAILED RUN" : root.listKind.toUpperCase()))) : "MENU")
              color: Nx.color.deep; font.family: Nx.pix; font.pixelSize: 11
            }
          }
          Text {
            anchors.left: badge.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - badge.width - 120
            elide: Text.ElideRight
            text: {
              if (root.mode === "search" && root.textScope) return "text inside " + Nx.baseName(root.textScope) + " · ↵ opens at the line · esc back"
              if (root.mode === "search") {
                var cur = root.results[root.cursor]
                return cur && cur.kind === "project" ? "ctrl ↵ search inside this project · ↵ open" : "letters type text here, they don't run actions"
              }
              if (root.mode !== "list") return "press a letter"
              switch (root.listKind) {
                case "projects":
                  if (root.removeArmed) return "x again removes " + Nx.baseName(root.removeArmed) + " from the list · the folder stays · esc cancels"
                  return "↵ open · r resume · t e f g d · a add · x remove"
                case "addproject": return "folders under ~ with git or a manifest · ↵ adds"
                case "project": return "letters act on the project · numbers run a task"
                case "jobs": return "↵ full output · s stop · o open link · c clear finished"
                case "failures": return "↵ details · r rerun · o output · x dismiss · c clear history"
                case "failure": return "letters act on the run · numbers open the file at that line"
                case "sessions": return "↵ attach in a terminal"
              }
              return "pick a number"
            }
            color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12
          }
          Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: root.mode === "menu" ? "/ search · esc close" : "esc back"
            color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12
          }
        }

        // Project header: path and live git status.
        Column {
          visible: root.mode === "list" && root.listKind === "project"
          width: parent.width
          spacing: 2
          Text {
            text: Nx.shortPath(root.projectDir, root.home)
            color: Nx.color.white; font.family: Nx.mono; font.pixelSize: 13
            width: parent.width; elide: Text.ElideMiddle
          }
          Text {
            readonly property var inf: root.info[root.projectDir]
            text: !inf ? "reading…" : (!inf.exists ? "folder not found" : (inf.git ? Nx.gitSummary(inf.git) : "not a git repository"))
            color: inf && inf.git ? Nx.gitColor(inf.git) : Nx.color.dim
            font.family: Nx.mono; font.pixelSize: 12
          }
        }

        // Menu mode: action grid.
        Grid {
          visible: root.mode === "menu"
          columns: 4
          width: parent.width
          Repeater {
            model: Nx.actions
            Rectangle {
              required property var modelData
              width: content.width / 4; height: 40
              color: cellArea.pressed ? Nx.color.line2 : (cellArea.containsMouse ? Nx.color.pane : "transparent")
              Row {
                x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text { text: parent.parent.modelData.key; width: 12; color: Nx.color.phos; font.family: Nx.mono; font.pixelSize: 14; font.weight: Font.Bold }
                Text {
                  readonly property bool hot: parent.parent.modelData.key === "x" && root.openFailures > 0
                  text: parent.parent.modelData.label + (hot ? " " + root.openFailures : "") + (parent.parent.modelData.list ? " ▸" : "")
                  color: hot ? Nx.color.amber : Nx.color.white; font.family: Nx.mono; font.pixelSize: 14
                }
              }
              MouseArea {
                id: cellArea
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.exec({ kind: "action", action: parent.modelData }, "")
              }
            }
          }
        }

        // Search field (search mode) or a tap target that enters it (menu mode).
        Rectangle {
          visible: root.mode !== "list"
          width: parent.width; height: 40
          color: "transparent"
          border.color: root.mode === "search" ? Nx.color.amber : Nx.color.line2
          border.width: 1
          Text {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            text: "/"
            color: root.mode === "search" ? Nx.color.amber : Nx.color.dim
            font.family: Nx.mono; font.pixelSize: 15; font.weight: Font.Bold
          }
          TextInput {
            id: searchInput
            x: 32; width: parent.width - 44
            anchors.verticalCenter: parent.verticalCenter
            visible: root.mode === "search"
            color: Nx.color.white
            selectionColor: Nx.color.phos3
            font.family: Nx.mono; font.pixelSize: 15
            focus: root.mode === "search"
            cursorVisible: true
            onTextChanged: { root.query = text; root.cursor = 0 }
            Keys.onPressed: function(event) {
              var n = root.results.length
              if (event.key === Qt.Key_Escape) { root.leaveSearch(); event.accepted = true }
              else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)
                       && root.results[root.cursor] && root.results[root.cursor].kind === "project") {
                root.searchText(root.results[root.cursor].dir); event.accepted = true
              }
              else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) { root.moveCursor(1, n); event.accepted = true }
              else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) { root.moveCursor(-1, n); event.accepted = true }
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.exec(root.results[root.cursor], ""); event.accepted = true }
            }
          }
          Text {
            x: 32; anchors.verticalCenter: parent.verticalCenter
            visible: root.mode === "menu"
            text: "search actions, projects, files, notes, tasks, sessions, jobs, windows"
            color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 13
          }
          MouseArea {
            anchors.fill: parent
            visible: root.mode === "menu"
            cursorShape: Qt.IBeamCursor
            onClicked: root.setMode("search")
          }
        }

        // Lists and search results share one row style.
        Column {
          visible: root.mode !== "menu"
          width: parent.width
          Repeater {
            model: root.mode === "list" ? root.listEntries : root.results
            Rectangle {
              id: entryRow
              required property var modelData
              required property int index
              readonly property bool selected: root.cursor === index
              readonly property string lead: {
                if (root.mode === "search") return modelData.group || ""
                if (modelData.kind === "pact" || modelData.kind === "fact") return modelData.key
                return String(root.numberOf(index))
              }
              width: content.width; height: 44
              color: rowArea.pressed ? Nx.color.line2 : (selected ? Qt.rgba(0.30, 1.0, 0.53, 0.09) : (rowArea.containsMouse ? Nx.color.pane : "transparent"))
              Rectangle { visible: entryRow.selected; width: 3; height: parent.height; color: Nx.color.phos }
              Rectangle {
                // Search: a line above each group.
                visible: root.mode === "search" && !!entryRow.modelData.group && entryRow.index > 0
                width: parent.width; height: 1; color: Nx.color.line
              }
              Rectangle {
                // Divider between a project's actions and its tasks.
                visible: root.mode === "list" && ((root.listKind === "project" && entryRow.modelData.kind === "task") || (root.listKind === "failure" && entryRow.modelData.kind === "ref")
                  || (root.listKind === "failures" && entryRow.modelData.history && (entryRow.index === 0 || !root.listEntries[entryRow.index - 1].history))) && (root.listKind === "failures" || root.numberOf(entryRow.index) === 1)
                width: parent.width; height: 1; color: Nx.color.line
              }
              Text {
                id: leadText
                x: 12; anchors.verticalCenter: parent.verticalCenter
                width: root.mode === "search" ? 64 : 18
                text: entryRow.lead
                color: root.mode === "search" ? Nx.color.dim : Nx.color.phos
                font.family: Nx.mono; font.pixelSize: root.mode === "search" ? 12 : 14
                font.weight: root.mode === "search" ? Font.Normal : Font.Bold
              }
              Rectangle {
                id: pip
                visible: entryRow.modelData.kind === "job"
                anchors.left: leadText.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                width: visible ? 8 : 0; height: 8
                color: entryRow.modelData.job ? Nx.jobColor(entryRow.modelData.job) : "transparent"
              }
              Text {
                anchors.left: pip.right; anchors.leftMargin: pip.visible ? 10 : 12; anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.42
                textFormat: Text.StyledText
                text: root.mode === "search"
                  ? Nx.highlight(entryRow.modelData.display || entryRow.modelData.title, entryRow.modelData.match, Nx.color.phos)
                  : Nx.escapeHtml(entryRow.modelData.title)
                color: entryRow.modelData.kind === "task" ? Nx.color.phos
                  : entryRow.modelData.kind === "failure" ? (entryRow.modelData.history ? Nx.color.dim : Nx.color.amber)
                  : (entryRow.modelData.kind === "project" && entryRow.modelData.dir === root.removeArmed ? Nx.color.amber : Nx.color.white)
                font.family: Nx.mono; font.pixelSize: 14
                elide: Text.ElideRight
              }
              Text {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.44
                horizontalAlignment: Text.AlignRight
                text: entryRow.modelData.sub || ""
                color: entryRow.modelData.kind === "project" ? Nx.gitColor(root.info[entryRow.modelData.dir] ? root.info[entryRow.modelData.dir].git : null)
                  : (entryRow.modelData.kind === "job" ? Nx.jobColor(entryRow.modelData.job) : (entryRow.modelData.kind === "failure" && !entryRow.modelData.history ? Nx.color.amber : Nx.color.dim))
                font.family: Nx.mono; font.pixelSize: 12
                elide: Text.ElideMiddle
              }
              MouseArea {
                id: rowArea
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) root.cursor = entryRow.index
                onClicked: root.exec(entryRow.modelData, "")
              }
            }
          }
          Text {
            visible: (root.mode === "list" ? root.listEntries.length : root.results.length) === 0
            x: 12; height: 44; verticalAlignment: Text.AlignVCenter
            text: root.mode === "search"
              ? (root.textScope
                 ? (root.query.length < 2 ? "type at least 2 letters to search inside " + Nx.baseName(root.textScope)
                    : textProc.running ? "searching…" : "no line in " + Nx.baseName(root.textScope) + " contains \"" + root.query + "\"")
                 : "nothing matches \"" + root.query + "\" · in a project, / searches inside its files")
              : root.listKind === "addproject" ? (scanProc.running ? "looking…" : "no unlisted project folders · in a terminal: nexus-project add FOLDER")
              : root.listKind === "failures" ? "no failures · tasks started from a project land here when they fail"
              : root.listKind === "failure" ? "this run is no longer recorded"
              : (root.listKind === "jobs" ? "no jobs · open a project and pick a task" : (root.listKind === "sessions" ? "no tmux sessions · t in a project starts one" : "nothing here yet"))
            color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 13
          }
          Text {
            visible: root.mode === "list" && root.listKind === "project" && !!root.info[root.projectDir] && root.info[root.projectDir].exists
              && root.taskEntries(root.projectDir).length === 0
            x: 12; height: 36; verticalAlignment: Text.AlignVCenter
            text: "no tasks found in package.json, pyproject.toml (uv), Makefile or compose files"
            color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12
          }
        }

        // Jobs: live output of the selected job.
        Rectangle {
          visible: root.mode === "list" && ((root.listKind === "jobs" && root.jobs.length > 0) || root.listKind === "failure")
          width: parent.width; height: 200
          color: Nx.color.char
          border.color: Nx.color.line; border.width: 1
          Text {
            x: 10; y: 6
            text: "OUTPUT"; color: Nx.color.dim; font.family: Nx.pix; font.pixelSize: 10
          }
          Text {
            x: 10; y: 22; width: parent.width - 20; height: parent.height - 28
            text: (root.listKind === "failure" ? root.failureOutput : root.jobOutput) || "(no output yet)"
            textFormat: Text.PlainText
            color: Nx.color.grey; font.family: Nx.mono; font.pixelSize: 11
            wrapMode: Text.NoWrap; elide: Text.ElideRight; clip: true
            verticalAlignment: Text.AlignBottom
          }
        }

        // Toolbox: tool versions and shortcut help under the commands.
        Column {
          visible: root.mode === "list" && root.listKind === "toolbox"
          width: parent.width
          spacing: 6
          Rectangle { width: parent.width; height: 1; color: Nx.color.line }
          Text { text: "INSTALLED"; color: Nx.color.dim; font.family: Nx.pix; font.pixelSize: 10 }
          Text {
            width: parent.width; wrapMode: Text.Wrap
            text: {
              var v = root.versions, keys = ["git", "node", "pnpm", "python", "uv", "ruff", "nvim", "tmux", "podman", "gh", "sqlite", "http"]
              var out = []
              for (var i = 0; i < keys.length; i++) out.push(keys[i] + " " + (v[keys[i]] || "—"))
              return out.join("   ")
            }
            color: Nx.color.grey; font.family: Nx.mono; font.pixelSize: 12
          }
          Text { text: "KEYS"; color: Nx.color.dim; font.family: Nx.pix; font.pixelSize: 10 }
          Text {
            width: parent.width; wrapMode: Text.Wrap
            text: "S ; menu   p project ▸ t e f g v + numbered tasks   j jobs ▸ s stop · o link · c clear   s sessions   / search   S B rail   S ⌥ B rail keys"
            color: Nx.color.grey; font.family: Nx.mono; font.pixelSize: 12
          }
        }
      }
    }
  }
}
