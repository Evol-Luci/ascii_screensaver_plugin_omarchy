import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A single card in the Marketplace tab for one available animation.
Rectangle {
  id: root

  property var entry: ({})
  property bool installed: false

  signal installClicked()
  signal uninstallClicked()

  width: Style.space(260)
  height: cardColumn.implicitHeight + Style.spacing.lg * 2
  color: Color.surface
  radius: Style.radius.md

  ColumnLayout {
    id: cardColumn
    anchors {
      top: parent.top; left: parent.left; right: parent.right
      margins: Style.spacing.lg
    }
    spacing: Style.spacing.sm

    // Preview image
    Image {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(120)
      source: root.entry.preview || ""
      fillMode: Image.PreserveAspectCrop
      clip: true
      visible: root.entry.preview !== ""

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Color.muted
        border.width: Style.normalBorderWidth
        radius: Style.radius.sm
        opacity: 0.3
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.entry.name || root.entry.id || ""
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.entry.author || ""
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.entry.description || ""
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight
    }

    Button {
      Layout.fillWidth: true
      text: root.installed ? "Uninstall" : "Install"
      onClicked: root.installed ? root.uninstallClicked() : root.installClicked()
    }
  }
}
