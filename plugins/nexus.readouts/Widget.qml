import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "../../../nexus/lib/Nx.js" as Nx

// Compact status-line readings: cpu, mem, temperature, battery, download.
// Sampled every 5 s by nexus-telemetry from /proc and /sys. Missing data
// shows as "—". Clicking battery or network opens Omarchy's panel; the
// others open btop.
BarWidget {
  id: root
  moduleName: "nexus.readouts"

  property var t: ({})

  readonly property var items: [
    { label: "cpu", value: t.cpu === null || t.cpu === undefined ? "—" : t.cpu + "%", tint: Nx.color.white, open: "btop",
      tip: "CPU " + (t.cpu === undefined ? "—" : t.cpu + "%") + (t.mhz ? " · " + (t.mhz / 1000).toFixed(1) + " GHz" : "") + (t.load !== undefined ? " · load " + t.load : "") },
    { label: "mem", value: t.memTotalKb ? ((t.memTotalKb - t.memAvailKb) / 1048576).toFixed(1) + "G" : "—", tint: Nx.color.white, open: "btop",
      tip: t.memTotalKb ? "Memory " + ((t.memTotalKb - t.memAvailKb) / 1048576).toFixed(1) + " of " + (t.memTotalKb / 1048576).toFixed(1) + " GiB" : "Memory not reported" },
    { label: "", value: t.tempC === null || t.tempC === undefined ? "—°" : t.tempC + "°", tint: Nx.tempColor(t.tempC), open: "btop",
      tip: "CPU package " + (t.tempC === null || t.tempC === undefined ? "not reported" : t.tempC + " °C") + (t.fanRpm ? " · fan " + t.fanRpm + " rpm" : "") },
    { label: "bat", value: t.battery === null || t.battery === undefined ? "ac" : t.battery + "%" + (t.batteryStatus === "Charging" ? "+" : ""),
      tint: Nx.batteryColor(t.battery, t.batteryStatus), open: "omarchy.power",
      tip: t.battery === null || t.battery === undefined ? "No battery" : "Battery " + t.battery + "% · " + String(t.batteryStatus || "").toLowerCase() },
    { label: "", value: t.iface ? "▼" + Nx.rate(t.rxRate) : "offline", tint: t.iface ? Nx.color.phos2 : Nx.color.amber, open: "omarchy.network",
      tip: t.iface ? (t.ssid || t.iface) + " · ▼ " + Nx.rate(t.rxRate) + "/s ▲ " + Nx.rate(t.txRate) + "/s" : "No route to the internet" }
  ]

  function open(target) {
    if (target === "btop") Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
    else Quickshell.execDetached(["omarchy-shell", "shell", "toggle", target, "{}"])
  }

  Process {
    running: true
    command: [Quickshell.env("HOME") + "/.config/nexus/bin/nexus-telemetry", "5"]
    stdout: SplitParser { onRead: function(line) { try { root.t = JSON.parse(line) } catch (e) {} } }
  }

  implicitWidth: root.vertical ? root.barSize : row.implicitWidth + 16
  implicitHeight: root.vertical ? row.implicitHeight + 12 : root.barSize

  Grid {
    id: row
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.items.length
    columnSpacing: 14
    rowSpacing: 6

    Repeater {
      model: root.items
      Item {
        id: cell
        required property var modelData
        implicitWidth: text.implicitWidth
        implicitHeight: root.vertical ? text.implicitHeight : root.barSize
        Text {
          id: text
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.StyledText
          text: (cell.modelData.label ? "<font color='" + Nx.color.dim + "'>" + cell.modelData.label + "</font> " : "")
            + "<font color='" + cell.modelData.tint + "'>" + cell.modelData.value + "</font>"
          font.family: Nx.mono
          font.pixelSize: 13
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.open(cell.modelData.open)
          onContainsMouseChanged: {
            if (!root.bar) return
            if (containsMouse) root.bar.showTooltip(cell, cell.modelData.tip)
            else root.bar.hideTooltip(cell)
          }
        }
      }
    }
  }
}
