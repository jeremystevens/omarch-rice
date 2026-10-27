import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../../nexus/lib/Nx.js" as Nx

// NEXUS workbench rail on the left edge.
//
// Open (244 px reserved): projects from identity.toml, the Hyprland windows
// on the current workspace, recent files from GTK's recently-used list, and
// the NEXUS keys. Collapsed (44 px reserved): p / w / r buttons that peek
// the full rail over the desktop without taking space back from windows.
//
// Every row is a 44 px target. Projects: tap or Return opens a terminal
// there; with keyboard focus, e opens nvim and f opens Files. Windows: tap
// or Return focuses that window. Recent files: open with the default app.
//
// IPC (omarchy-shell nexus-rail ...): toggle (SUPER B), focus (SUPER ALT B).
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateFile: home + "/.local/state/nexus/rail-collapsed"

  property bool collapsed: false
  property bool peek: false          // collapsed rail shown over the desktop
  property bool keyboard: false      // rail holds keyboard focus
  property int cursor: -1
  readonly property bool expanded: !collapsed || peek
  property bool grabArmed: false

  onPeekChanged: rearm()
  onKeyboardChanged: rearm()
  function rearm() {
    grabArmed = false
    if (peek || keyboard) armTimer.restart()
  }
  Timer { id: armTimer; interval: 150; onTriggered: root.grabArmed = root.peek || root.keyboard }

  property var identity: ({})
  readonly property var projects: Nx.projectsFrom(identity, home)
  property var recent: []
  property var info: ({})            // dir -> { exists, git, tasks } from nexus-dev
  property var sessions: []          // tmux sessions (not the task runner's)
  property var jobs: []              // tasks started through NEXUS

  readonly property var workspace: Hyprland.focusedWorkspace
  readonly property var windows: {
    var out = [], tops = workspace ? workspace.toplevels.values : []
    for (var i = 0; i < tops.length; i++) out.push(tops[i])
    return out
  }
  readonly property var elsewhere: {
    var ids = [], values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      if (w.id > 0 && (!workspace || w.id !== workspace.id) && w.toplevels.values.length > 0) ids.push(w.id)
    }
    return ids.sort(function(a, b) { return a - b })
  }

  // Flat list of everything the keyboard cursor can land on, in rail order.
  readonly property var items: {
    var out = []
    for (var i = 0; i < projects.length; i++) out.push({ kind: "project", ref: projects[i] })
    for (var s = 0; s < sessions.length; s++) out.push({ kind: "session", ref: sessions[s] })
    for (var b = 0; b < jobs.length; b++) out.push({ kind: "job", ref: jobs[b] })
    for (var j = 0; j < Math.min(6, windows.length); j++) out.push({ kind: "window", ref: windows[j] })
    for (var k = 0; k < recent.length; k++) out.push({ kind: "file", ref: recent[k] })
    return out
  }
  function indexOf(kind, ref) {
    for (var i = 0; i < items.length; i++) if (items[i].kind === kind && items[i].ref === ref) return i
    return -1
  }

  // Actions run a moment after the rail lets go of the keyboard; dispatched
  // in the same instant, Hyprland hands focus back to the previous window
  // and a "focus this window" request loses the race.
  property var pending: null
  function run(argv) { pending = argv; runTimer.restart() }
  Timer { id: runTimer; interval: 250; onTriggered: { if (root.pending) Quickshell.execDetached(root.pending); root.pending = null } }

  function activate(item, secondary) {
    if (!item) return
    if (item.kind === "project") {
      var act = { t: "term", e: "edit", f: "files", g: "git" }[secondary]
      // Tap / Return opens the project panel (git status, actions, tasks).
      run(act ? [Nx.bin("nexus-dev"), act, item.ref.dir] : ["omarchy-shell", "nexus", "project", item.ref.dir])
    } else if (item.kind === "session") {
      run([Nx.bin("nexus-dev"), "attach", item.ref.name])
    } else if (item.kind === "job") {
      run(["omarchy-shell", "nexus", "jobs"])
    } else if (item.kind === "window") {
      run(Nx.focusWindow(item.ref.address))
    } else if (item.kind === "file") {
      run(Nx.openFile(item.ref.path))
    }
    leave()
  }

  function leave() {
    keyboard = false
    peek = false
    cursor = -1
  }

  function setCollapsed(value) {
    collapsed = value
    peek = false
    saveState.command = ["sh", "-c", (value ? "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"" : "rm -f \"$1\""), "sh", stateFile]
    saveState.running = true
  }

  function focusRail() {
    if (collapsed) peek = true
    keyboard = true
    cursor = items.length > 0 ? 0 : -1
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function move(delta) {
    if (items.length === 0) return
    cursor = cursor < 0 ? 0 : (cursor + delta + items.length) % items.length
  }

  // ------------------------------------------------------------ data
  FileView {
    path: root.home + "/.config/nexus/identity.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.identity = Nx.parseToml(text())
    onLoadFailed: root.identity = ({})
  }

  Process {
    id: recentProc
    command: [root.home + "/.config/nexus/bin/nexus-recent", "5"]
    stdout: StdioCollector { onStreamFinished: { try { root.recent = JSON.parse(text) } catch (e) { root.recent = [] } } }
  }
  FileView {
    path: root.home + "/.local/share/recently-used.xbel"
    watchChanges: true
    printErrors: false
    onFileChanged: recentProc.running = true
  }

  Process {
    running: true
    command: ["test", "-f", root.stateFile]
    onExited: function(code) { root.collapsed = code === 0 }
  }
  Process { id: saveState }

  Component.onCompleted: { Nx.home = root.home; recentProc.running = true }

  // Project status, tmux sessions and jobs: read on change and on a slow
  // timer, only while the rail is expanded (nothing polls while collapsed).
  Process {
    id: infoProc
    function refresh() {
      if (root.projects.length === 0) { root.info = ({}); return }
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
    stdout: StdioCollector { onStreamFinished: { try { root.sessions = JSON.parse(text).filter(function(s) { return s.name !== "nexus-tasks" }) } catch (e) { root.sessions = [] } } }
  }
  Process {
    id: jobsProc
    command: [root.home + "/.config/nexus/bin/nexus-task", "list"]
    stdout: StdioCollector { onStreamFinished: { try { root.jobs = JSON.parse(text) } catch (e) { root.jobs = [] } } }
  }
  onProjectsChanged: infoProc.refresh()
  onExpandedChanged: if (expanded) { infoProc.refresh(); sessionsProc.running = true; jobsProc.running = true }
  Timer {
    running: root.expanded
    interval: 4000
    repeat: true
    property int tick: 0
    onTriggered: {
      tick++
      if (!sessionsProc.running) sessionsProc.running = true
      if (!jobsProc.running) jobsProc.running = true
      if (tick % 4 === 0 && !infoProc.running) infoProc.refresh()   // git status every 16 s
    }
  }

  IpcHandler {
    target: "nexus-rail"
    function toggle(): void { root.setCollapsed(!root.collapsed) }
    function focus(): void { if (root.keyboard) root.leave(); else root.focusRail() }
    function state(): string {
      return (root.collapsed ? "collapsed" : "open") + (root.peek ? "+peek" : "")
        + (root.keyboard ? " keyboard cursor=" + root.cursor + (root.items[root.cursor] ? " " + root.items[root.cursor].kind
          + (root.items[root.cursor].kind === "window" ? " " + root.items[root.cursor].ref.address : "") : "") : "")
    }
  }

  // ------------------------------------------------------------ window
  PanelWindow {
    id: panel
    anchors { left: true; top: true; bottom: true }
    implicitWidth: root.expanded ? 244 : 44
    exclusiveZone: root.collapsed ? 44 : 244
    color: "transparent"
    WlrLayershell.namespace: "nexus-rail"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Clicking outside ends peek / keyboard mode. The grab is armed only
    // after the rail has settled: armed in the same frame the rail widens,
    // Hyprland clears it at once and the mode would end before it began.
    HyprlandFocusGrab {
      windows: [panel]
      active: root.grabArmed
      onCleared: if (root.grabArmed) root.leave()
    }

    Rectangle {
      anchors.fill: parent
      color: Nx.color.deep
      Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: root.keyboard ? Nx.color.phos2 : Nx.color.line }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: root.keyboard
      Keys.onPressed: function(event) {
        var k = event.key
        if (k === Qt.Key_Escape) root.leave()
        else if (k === Qt.Key_Down || k === Qt.Key_Tab || k === Qt.Key_J) root.move(1)
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab || k === Qt.Key_K) root.move(-1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.activate(root.items[root.cursor], "")
        else if ((k === Qt.Key_T || k === Qt.Key_E || k === Qt.Key_F || k === Qt.Key_G) && root.items[root.cursor] && root.items[root.cursor].kind === "project")
          root.activate(root.items[root.cursor], event.text)
        else return
        event.accepted = true
      }
    }

    // ---------------------------------------------------- collapsed strip
    Column {
      visible: !root.expanded
      width: 44
      Repeater {
        model: [
          { glyph: "N", tip: "expand rail", act: "expand" },
          { glyph: "p", tip: "projects", act: "peek" },
          { glyph: "w", tip: "windows", act: "peek" },
          { glyph: "r", tip: "recent files", act: "peek" },
          { glyph: "»", tip: "expand rail", act: "expand" }
        ]
        Item {
          required property var modelData
          required property int index
          width: 44; height: 44
          Rectangle { anchors.fill: parent; anchors.margins: 2; color: stripArea.pressed ? Nx.color.line2 : (stripArea.containsMouse ? Nx.color.line : "transparent") }
          Text {
            anchors.centerIn: parent
            text: parent.modelData.glyph
            color: index === 0 ? Nx.color.phos : (index === 4 ? Nx.color.dim : Nx.color.white)
            font.family: Nx.mono; font.pixelSize: index === 0 ? 16 : 14; font.weight: index === 0 ? Font.Bold : Font.Normal
          }
          MouseArea {
            id: stripArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.modelData.act === "expand" ? root.setCollapsed(false) : root.peek = true
          }
        }
      }
    }

    // ---------------------------------------------------- full rail
    Flickable {
      visible: root.expanded
      anchors.fill: parent
      anchors.rightMargin: 1
      contentHeight: body.implicitHeight + 12
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: body
        width: parent.width

        // Mark and machine
        Item {
          width: parent.width; height: markText.implicitHeight + 46
          Text {
            id: markText
            x: 14; y: 14
            text: Nx.mark
            color: Nx.color.phos
            font.family: Nx.mono; font.pixelSize: 8; font.weight: Font.Bold
            lineHeight: 1.0
            style: Text.Raised; styleColor: Nx.color.phos3
          }
          Text {
            x: 14; anchors.top: markText.bottom; anchors.topMargin: 8
            text: root.identity.identity && root.identity.identity.tagline ? root.identity.identity.tagline : "cyberdeck"
            color: Nx.color.dim
            font.family: Nx.mono; font.pixelSize: 12
            width: parent.width - 28; elide: Text.ElideRight
          }
          // Collapse control in the corner, 44 px target.
          Item {
            anchors.right: parent.right; anchors.top: parent.top
            width: 44; height: 44
            Text { anchors.centerIn: parent; text: root.collapsed ? "×" : "«"; color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 14 }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root.collapsed ? root.leave() : root.setCollapsed(true)
            }
          }
        }

        SectionHead { label: "projects"; key: "p" }
        Repeater {
          model: root.projects
          RailRow {
            required property var modelData
            kind: "project"; ref: modelData
            title: modelData.name
            readonly property var inf: root.info[modelData.dir]
            sub: inf && !inf.exists ? "missing · " + modelData.path : (inf && inf.git ? Nx.gitSummary(inf.git) : modelData.path)
            subColor: inf && inf.git ? Nx.gitColor(inf.git) : Nx.color.dim
            hint: hasCursor ? "↵ t e f g" : ""
          }
        }
        EmptyRow { visible: root.projects.length === 0; text: "add projects in ~/.config/nexus/identity.toml" }

        SectionHead { visible: root.sessions.length > 0; label: "tmux sessions"; key: "s"; topGap: 8 }
        Repeater {
          model: root.sessions
          RailRow {
            required property var modelData
            kind: "session"; ref: modelData
            title: modelData.name
            sub: modelData.windows + " window" + (modelData.windows === 1 ? "" : "s") + (modelData.attached ? " · attached" : "") + " · " + Nx.shortPath(modelData.path, root.home)
          }
        }

        SectionHead { visible: root.jobs.length > 0; label: "jobs"; key: "j"; topGap: 8 }
        Repeater {
          model: root.jobs
          RailRow {
            required property var modelData
            kind: "job"; ref: modelData
            pip: Nx.jobColor(modelData)
            title: modelData.project + " · " + modelData.label
            sub: Nx.jobState(modelData) + (modelData.url ? " · " + modelData.url.replace(/^https?:\/\//, "") : "")
            subColor: Nx.jobColor(modelData)
          }
        }

        SectionHead { label: "windows · " + (root.workspace ? root.workspace.id : "–"); key: "w"; topGap: 8 }
        Repeater {
          model: root.windows.slice(0, 6)
          RailRow {
            required property var modelData
            kind: "window"; ref: modelData
            title: Nx.appOf(modelData)
            sub: modelData.title || ""
            current: modelData.activated
            urgent: !!modelData.urgent
          }
        }
        EmptyRow { visible: root.windows.length === 0; text: "no windows on this workspace" }
        EmptyRow { visible: root.windows.length > 6; text: "+" + (root.windows.length - 6) + " more · w in the command menu" }
        Item {
          visible: root.elsewhere.length > 0
          width: parent.width; height: 28
          Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "elsewhere"; color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12 }
          Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: root.elsewhere.join(" · "); color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12 }
        }

        SectionHead { label: "recent files"; key: "r"; topGap: 8 }
        Repeater {
          model: root.recent
          RailRow {
            required property var modelData
            kind: "file"; ref: modelData
            title: Nx.baseName(modelData.path)
            sub: Nx.dirOf(modelData.path, root.home)
          }
        }
        EmptyRow { visible: root.recent.length === 0; text: "no recent files yet" }

        SectionHead { label: "keys"; topGap: 8 }
        Repeater {
          model: [["S ;", "command menu"], ["S B", root.collapsed ? "expand rail" : "collapse rail"], ["S ⌥ B", "focus rail"]]
          Item {
            required property var modelData
            width: body.width; height: 26
            Rectangle {
              x: 14; anchors.verticalCenter: parent.verticalCenter
              width: keyText.implicitWidth + 10; height: 18
              color: "transparent"; border.color: Nx.color.line2; border.width: 1
              Text { id: keyText; anchors.centerIn: parent; text: parent.parent.modelData[0]; color: Nx.color.white; font.family: Nx.mono; font.pixelSize: 11 }
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]; color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12 }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ parts
  component SectionHead: Item {
    property string label: ""
    property string key: ""
    property int topGap: 0
    width: body.width; height: visible ? 26 + topGap : 0
    Text {
      x: 14; y: topGap + 7
      text: label.toUpperCase()
      color: Nx.color.dim
      font.family: Nx.pix; font.pixelSize: 11; font.letterSpacing: 0.8
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 14; y: topGap + 5
      text: key
      color: Nx.color.phos2
      font.family: Nx.mono; font.pixelSize: 12
    }
  }

  component EmptyRow: Item {
    property alias text: t.text
    width: body.width; height: visible ? 30 : 0
    Text {
      id: t
      x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
      color: Nx.color.dim; font.family: Nx.mono; font.pixelSize: 12
      elide: Text.ElideRight
    }
  }

  component RailRow: Item {
    id: row
    property string kind: ""
    property var ref: null
    property string title: ""
    property string sub: ""
    property string hint: ""
    property bool current: false
    property bool urgent: false
    property color subColor: Nx.color.dim
    property color pip: "transparent"
    readonly property int myIndex: root.indexOf(kind, ref)
    readonly property bool hasCursor: root.keyboard && root.cursor === myIndex && myIndex >= 0

    width: body.width; height: 44

    Rectangle {
      anchors.fill: parent
      color: area.pressed ? Nx.color.line2 : (row.hasCursor ? Qt.rgba(0.30, 1.0, 0.53, 0.07) : (area.containsMouse ? Nx.color.pane : "transparent"))
    }
    Rectangle {
      visible: row.current || row.urgent
      width: 3; height: parent.height
      color: row.urgent ? Nx.color.amber : Nx.color.phos2
    }
    Rectangle {
      visible: row.hasCursor
      anchors.fill: parent
      color: "transparent"
      border.color: Nx.color.phos
      border.width: 2
    }
    Rectangle {
      id: pipMark
      visible: row.pip !== Qt.color("transparent") && row.kind === "job"
      x: 14; anchors.verticalCenter: parent.verticalCenter
      width: 8; height: 8; color: row.pip
    }
    Column {
      x: pipMark.visible ? 30 : 14; anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - 14 - (hintText.visible ? hintText.implicitWidth + 8 : 0)
      Text {
        width: parent.width
        text: row.title
        color: row.urgent ? Nx.color.amber : (row.current ? Nx.color.phos : Nx.color.white)
        font.family: Nx.mono; font.pixelSize: 13
        elide: Text.ElideRight
      }
      Text {
        visible: row.sub.length > 0
        width: parent.width
        text: row.sub
        color: row.subColor
        font.family: Nx.mono; font.pixelSize: 11
        elide: Text.ElideMiddle
      }
    }
    Text {
      id: hintText
      visible: row.hint.length > 0
      anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
      text: row.hint
      color: Nx.color.phos2
      font.family: Nx.mono; font.pixelSize: 11
    }
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(event) {
        // Right-click on a project opens it in the editor.
        root.activate({ kind: row.kind, ref: row.ref }, event.button === Qt.RightButton && row.kind === "project" ? "e" : "")
      }
    }
  }
}
