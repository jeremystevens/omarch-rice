import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Ui
import "../../../nexus/lib/Nx.js" as Nx

// Workspaces 1-5, numbers only, in four states:
//   active    phosphor block, charcoal digit
//   occupied  off-white digit with a green tick underneath
//   empty     dim digit
//   urgent    amber block (Hyprland's urgent flag), until visited
// Workspaces 6-10 are not shown unless they hold windows; then a "+n" cell
// appears and jumps to the first of them. Scrolling steps through 1-5.
BarWidget {
  id: root
  moduleName: "nexus.workspaces"

  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

  function info(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      if (w.id !== id) continue
      var tops = w.toplevels.values, urgent = !!w.urgent
      for (var j = 0; j < tops.length && !urgent; j++) urgent = !!tops[j].urgent
      return { windows: tops.length, urgent: urgent }
    }
    return { windows: 0, urgent: false }
  }

  readonly property var overflow: {
    var ids = [], values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++)
      if (values[i].id > 5 && values[i].toplevels.values.length > 0) ids.push(values[i].id)
    return ids.sort(function(a, b) { return a - b })
  }

  function focusWorkspace(id) { Quickshell.execDetached(Nx.focusWorkspace(id)) }

  implicitWidth: root.vertical ? root.barSize : row.implicitWidth + 12
  implicitHeight: root.vertical ? row.implicitHeight + 12 : root.barSize

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) {
      var next = root.focusedId + (event.angleDelta.y > 0 ? -1 : 1)
      root.focusWorkspace(next < 1 ? 5 : (next > 5 ? 1 : next))
    }
  }

  Grid {
    id: row
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 6
    spacing: 2

    Repeater {
      model: [1, 2, 3, 4, 5]

      Item {
        id: cell
        required property int modelData
        readonly property var wsInfo: root.info(modelData)
        readonly property bool active: root.focusedId === modelData
        readonly property bool urgent: wsInfo.urgent && !active
        readonly property bool occupied: wsInfo.windows > 0

        width: 30
        height: root.vertical ? 26 : root.barSize - 6

        Rectangle {
          anchors.fill: parent
          color: cell.active ? Nx.color.phos
            : (cell.urgent ? Nx.color.amber
              : (area.pressed ? Nx.color.line2 : (area.containsMouse ? Nx.color.line : "transparent")))
        }
        Text {
          anchors.centerIn: parent
          text: String(cell.modelData)
          color: cell.active || cell.urgent ? Nx.color.deep : (cell.occupied ? Nx.color.white : Nx.color.faint)
          font.family: Nx.mono
          font.pixelSize: 13
          font.weight: cell.active || cell.urgent || cell.occupied ? Font.Bold : Font.Normal
        }
        Rectangle {
          visible: cell.occupied && !cell.active && !cell.urgent
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          width: 10; height: 2
          color: Nx.color.phos2
        }
        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focusWorkspace(cell.modelData)
          onContainsMouseChanged: {
            if (!root.bar) return
            var tip = "Workspace " + cell.modelData + " · "
              + (cell.active ? "active" : cell.urgent ? "needs attention" : cell.occupied ? cell.wsInfo.windows + " window" + (cell.wsInfo.windows === 1 ? "" : "s") : "empty")
            if (containsMouse) root.bar.showTooltip(cell, tip)
            else root.bar.hideTooltip(cell)
          }
        }
      }
    }

    Item {
      visible: root.overflow.length > 0
      width: 30
      height: root.vertical ? 26 : root.barSize - 6
      Text {
        anchors.centerIn: parent
        text: "+" + root.overflow.length
        color: root.overflow.indexOf(root.focusedId) !== -1 ? Nx.color.phos : Nx.color.grey
        font.family: Nx.mono
        font.pixelSize: 12
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.focusWorkspace(root.overflow[0])
      }
    }
  }
}
