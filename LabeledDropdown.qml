import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Dropdown carries its own label but has no room for explanatory text,
// so the description sits under it.
ColumnLayout {
  id: root

  property string label: ""
  property string description: ""
  property string value: ""
  property var options: []

  signal changed(string value)

  spacing: Style.spacing.xxs

  Dropdown {
    Layout.fillWidth: true
    label: root.label
    value: root.value
    options: root.options
    onChanged: function (v) { root.changed(v) }
  }

  Text {
    Layout.fillWidth: true
    visible: root.description !== ""
    text: root.description
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
