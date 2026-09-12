import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "ParamMeta.js" as ParamMeta

// PanelSlider with the label, description and live numeric readout it
// lacks on its own.
ColumnLayout {
  id: root

  property string label: ""
  property string description: ""
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false

  // Tracks the knob while dragging so the readout moves with it, then
  // falls back to the persisted value once released.
  property real displayValue: value

  // Lets a caller render the readout in its own units ("2m 30s" rather
  // than "150"). Empty means plain numeric formatting.
  property string valueText: ""

  signal released(real value)

  spacing: Style.spacing.xxs
  onValueChanged: displayValue = value

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.md

    Text {
      Layout.fillWidth: true
      text: root.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      elide: Text.ElideRight
    }

    Text {
      text: root.valueText !== "" ? root.valueText : ParamMeta.formatValue(root.displayValue)
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      horizontalAlignment: Text.AlignRight
      // Reserve room for the widest value so the label beside it does not
      // twitch sideways as the number changes width mid-drag.
      Layout.minimumWidth: Style.space(44)
    }
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

  PanelSlider {
    Layout.fillWidth: true
    value: root.value
    minimum: root.minimum
    maximum: root.maximum
    step: root.step
    integer: root.integer
    onMoved: function (v) { root.displayValue = v }
    onReleased: function (v) { root.released(v) }
  }
}
