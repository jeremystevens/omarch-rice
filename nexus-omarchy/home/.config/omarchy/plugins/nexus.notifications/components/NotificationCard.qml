// Notification card. Pure presentational — no service, Notification, or
// ListModel references. The popup container drives lifetime; the history
// panel drives static rendering. Both use the same component.
//
// NEXUS version (cloned from Omarchy's omarchy.notifications plugin).
// Only the visuals differ from upstream:
//   - hard-edged charcoal card with a graphite hairline
//   - severity edge + pip: low = dim, normal = phosphor, critical = amber
//   - meta line (APP · time), mono title and body
//   - countdown hairline along the bottom when `progress` is set
// Icon resolution, glyph fallback, sanitising and click handling are as
// upstream.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../NotificationLogic.js" as NotificationLogic
import "../../../../nexus/lib/Nx.js" as Ns

BorderSurface {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  // Nerd Font glyph rendered in the icon slot when no real icon is set.
  // Used by omarchy-notification-send so user-action toasts (`Silenced
  // notifications` etc.) show their bell/lock/etc. glyph without leaking
  // into the summary text.
  property string glyph: ""
  // NotificationUrgency: Low=0, Normal=1, Critical=2 (upstream).
  property int urgency: 1
  property double timestamp: 0
  property int cornerRadius: 0
  // Remaining lifetime 0..1 from the popup slot; -1 hides the countdown.
  property real progress: -1

  // System monospace font injected by the container.
  property string fontFamily: ""

  readonly property bool hovered: hoverTracker.hovered

  signal closeRequested()
  signal cardClicked()
  // Prefer per-notification media/avatar data, then fall back to the app icon.
  // The `check` flag avoids Qt's missing-texture placeholder for unknown names.
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  readonly property bool hasGlyph: glyph.length > 0
  readonly property bool compactGlyph: NotificationLogic.shouldRenderCompactGlyph(glyph, smallIconSource, singleLineToast)
  readonly property bool hasSmallIcon: smallIconSource.length > 0
  readonly property bool summaryStartsWithGlyph: NotificationLogic.summaryStartsWithGlyph(summary)
  readonly property bool singleLineToast: sanitizedBody.length === 0
  readonly property bool collapseRedundantIcon: singleLineToast && !hasGlyph && summaryStartsWithGlyph
  readonly property string sanitizedBody: sanitizeBody(body)
  readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)

  readonly property color severityColor: urgency === 2 ? Ns.color.amber : (urgency === 0 ? Ns.color.dim : Ns.color.phos2)
  readonly property string metaText: {
    var parts = []
    if (app.length > 0) parts.push(app.toUpperCase())
    if (urgency === 2) parts.push("URGENT")
    if (timestamp > 0) parts.push(Qt.formatDateTime(new Date(timestamp), "h:mm AP"))
    return parts.join(" · ")
  }
  // No chamfer in NEXUS: the card is a plain rectangle.
  readonly property int chamferX: 0
  readonly property int chamferY: 0

  function sanitizeBody(s) {
    return NotificationLogic.sanitizeBody(s, app, appIcon)
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: Style.space(380)
  implicitHeight: mainColumn.implicitHeight
  radius: 0
  // The NS outline below replaces the surface fill and border; the theme
  // sets [notifications] border-width = 0 so BorderSurface draws nothing.
  color: "transparent"
  borderSpec: Border.surfaceSpec("notifications", "border", Commons.Color.notifications.border, 0)
  clip: true

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.notifications.background
    border.color: root.hovered ? Ns.color.dim : Ns.color.line2
    border.width: 1
  }

  // Severity edge down the left side, and the countdown along the bottom.
  Rectangle {
    x: 0; y: 0
    width: 3; height: root.height
    color: root.severityColor
  }
  Rectangle {
    visible: root.progress >= 0
    x: 3; y: root.height - 2
    width: (root.width - 4) * Math.max(0, Math.min(1, root.progress))
    height: 2
    color: root.severityColor
    opacity: 0.8
  }

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.closeRequested()
      } else {
        root.cardClicked()
      }
    }
  }

  ColumnLayout {
    id: mainColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 0

    // Meta line: severity pip, APP · URGENT · time.
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 16
      Layout.rightMargin: 16
      Layout.topMargin: 11
      spacing: 8
      visible: root.metaText.length > 0

      Rectangle {
        Layout.preferredWidth: 7; Layout.preferredHeight: 7
        Layout.alignment: Qt.AlignVCenter
        color: root.severityColor
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: root.metaText
        color: root.urgency === 2 ? Ns.color.amber : Ns.color.dim
        font.family: Ns.mono
        font.pixelSize: 10
        font.letterSpacing: 1.6
        elide: Text.ElideRight
      }
    }

    // Text content.
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 16
      Layout.rightMargin: 16
      Layout.topMargin: root.metaText.length > 0 ? 6 : 12
      Layout.bottomMargin: 14
      spacing: root.collapseRedundantIcon ? 0 : (root.compactGlyph ? 8 : 12)

      Item {
        id: smallIconSlot
        Layout.preferredWidth: visible ? 36 : 0
        Layout.preferredHeight: visible ? 36 : 0
        Layout.alignment: Qt.AlignTop
        // Hide the slot when the icon failed to resolve (themed-icon name
        // not in the user's icon theme) AND we don't have a glyph fallback
        // — prevents rendering Qt's pink broken-image placeholder.
        visible: !root.collapseRedundantIcon && !root.compactGlyph && (root.hasSmallIcon || root.hasGlyph) && (root.hasGlyph || smallIconImage.status !== Image.Error)

        Image {
          id: smallIconImage
          anchors.fill: parent
          source: root.smallIconSource
          sourceSize.width: smallIconSlot.width * Screen.devicePixelRatio
          sourceSize.height: smallIconSlot.height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          visible: !root.hasGlyph || smallIconImage.status === Image.Ready
        }

        // Glyph fallback (Nerd Font character) when no image icon is
        // available. Used by omarchy-notification-send's `-g` flag.
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: root.hasGlyph && smallIconImage.status !== Image.Ready
          text: root.glyph
          color: Commons.Color.notifications.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.alignment: Qt.AlignTop
        visible: root.compactGlyph
        text: root.glyph
        color: Commons.Color.notifications.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 4

        Text {
          // The spec defines the summary as a single line of plain text, so
          // AutoText could only ever promote a hostile string to rich text.
          // The body below is StyledText on purpose — see Service.qml's
          // bodyMarkupSupported — and is stripped in NotificationLogic.
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: root.summary.length > 0
          text: root.summary
          font.family: Ns.mono
          font.weight: Font.Bold
          font.pixelSize: 14
          color: Ns.color.white
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        Text {
          Layout.fillWidth: true
          visible: root.sanitizedBody.length > 0
          text: root.styledBody
          textFormat: Text.StyledText
          font.family: Ns.mono
          font.pixelSize: 12
          lineHeight: 1.3
          color: Ns.color.grey
          linkColor: Ns.color.phos
          wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          elide: Text.ElideRight
          maximumLineCount: 4
        }
      }
    }
  }

}
