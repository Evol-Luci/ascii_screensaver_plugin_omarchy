import QtQuick
import QtQuick.Layouts
import qs.Commons

// A selectable row in the left-hand list: title plus a muted status line.
Rectangle {
  id: root

  property string title: ""
  property string subtitle: ""
  property bool selected: false
  property bool dimmed: false

  signal clicked()

  implicitHeight: column.implicitHeight + Style.spacing.lg * 2
  radius: Style.cornerRadius
  color: selected ? Color.menu.selectedBackground
    : (mouse.containsMouse ? Color.menu.selectedBackground : "transparent")
  opacity: selected || mouse.containsMouse ? 1.0 : (dimmed ? 0.55 : 1.0)

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.spacing.xl
    anchors.rightMargin: Style.spacing.xl
    spacing: Style.spacing.xxs

    Text {
      Layout.fillWidth: true
      text: root.title
      textFormat: Text.PlainText
      color: root.selected ? Color.menu.selectedText : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      elide: Text.ElideRight
    }

    Text {
      Layout.fillWidth: true
      visible: root.subtitle !== ""
      text: root.subtitle
      textFormat: Text.PlainText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
