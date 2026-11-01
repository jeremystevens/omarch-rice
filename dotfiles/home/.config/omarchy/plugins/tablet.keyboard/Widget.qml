import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Keyboard button for tablet mode (omarch-rice/dotfiles). Hidden in laptop mode; tap to show or
// hide the on-screen keyboard. `tablet-mode on|off` pings it: omarchy-shell -q tablet.keyboard refresh
BarWidget {
  id: root
  moduleName: "tablet.keyboard"

  property bool tabletMode: false
  readonly property string flag: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tablet-mode/on"
  readonly property string script: Quickshell.env("HOME") + "/.local/bin/tablet-mode"

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  visible: tabletMode
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "tablet.keyboard"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: stateProc
    command: ["test", "-e", root.flag]
    onExited: function(exitCode) {
      root.tabletMode = exitCode === 0
    }
  }

  Component.onCompleted: root.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "On-screen keyboard"
    onPressed: Quickshell.execDetached([root.script, "keyboard", "toggle"])
  }
}
