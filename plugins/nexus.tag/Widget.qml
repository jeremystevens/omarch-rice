import QtQuick
import Quickshell
import qs.Ui
import "../../../nexus/lib/Nx.js" as Nx

// NEXUS tag at the start of the status line. Click: command menu.
// Right-click: Omarchy menu.
BarWidget {
  id: root
  moduleName: "nexus.tag"

  implicitWidth: root.vertical ? root.barSize : label.implicitWidth + 20
  implicitHeight: root.vertical ? label.implicitWidth + 20 : root.barSize

  Rectangle {
    anchors.fill: parent
    color: area.pressed ? Nx.color.phos : (area.containsMouse ? "#38bd6c" : Nx.color.phos2)
  }
  Text {
    id: label
    anchors.centerIn: parent
    rotation: root.vertical ? -90 : 0
    text: "NEXUS"
    color: Nx.color.deep
    font.family: Nx.mono
    font.pixelSize: 13
    font.weight: Font.Bold
    font.letterSpacing: 0.6
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(event) {
      if (event.button === Qt.RightButton)
        Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "omarchy.menu", "{\"menu\":\"root\"}"])
      else
        Quickshell.execDetached(["omarchy-shell", "nexus", "menu"])
    }
  }
}
