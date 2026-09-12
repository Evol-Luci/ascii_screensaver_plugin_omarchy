import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "ParamMeta.js" as ParamMeta

// Everything about one animation: whether it plays, how often it is
// picked, and its own parameters.
ColumnLayout {
  id: root

  property string animationName: ""
  property var animationSchema: ({})
  property var entry: ({})
  property bool randomMode: true

  readonly property var paramNames: animationSchema && animationSchema.params
    ? Object.keys(animationSchema.params) : []

  signal enabledToggled(bool value)
  signal weightChanged(int weight)
  signal paramEdited(string paramName, var value)

  spacing: Style.spacing.xl

  Text {
    Layout.fillWidth: true
    text: root.animationSchema && root.animationSchema.title
      ? root.animationSchema.title : ParamMeta.formatLabel(root.animationName)
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
    wrapMode: Text.WordWrap
  }

  Text {
    Layout.fillWidth: true
    visible: text !== ""
    text: root.animationSchema && root.animationSchema.hint ? root.animationSchema.hint : ""
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Toggle {
    Layout.fillWidth: true
    label: "Enabled"
    description: root.randomMode
      ? "Allow this animation to be picked when the screensaver starts."
      : "Only matters in random mode. Single mode always plays the animation chosen under General."
    checked: root.entry && root.entry.enabled !== false
    onClicked: root.enabledToggled(!(root.entry && root.entry.enabled !== false))
  }

  LabeledSlider {
    Layout.fillWidth: true
    visible: root.randomMode
    label: "Random weight"
    description: "How likely this animation is compared to the others. A weight of 0 means it is never picked; doubling the weight roughly doubles how often it appears."
    value: root.entry && root.entry.weight !== undefined ? root.entry.weight : 0
    minimum: 0
    maximum: 20
    step: 1
    integer: true
    onReleased: function (v) { root.weightChanged(Math.round(v)) }
  }

  PanelSeparator {
    Layout.fillWidth: true
    visible: root.paramNames.length > 0
  }

  PanelSectionHeader {
    text: "Appearance"
    visible: root.paramNames.length > 0
  }

  Text {
    Layout.fillWidth: true
    visible: root.paramNames.length === 0
    text: "This animation has no adjustable settings."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: root.paramNames

    delegate: ParamEditor {
      required property string modelData

      Layout.fillWidth: true
      animationName: root.animationName
      paramName: modelData
      spec: root.animationSchema.params[modelData]
      currentValue: root.entry && root.entry.params ? root.entry.params[modelData] : undefined
      onEdited: function (value) { root.paramEdited(modelData, value) }
    }
  }

  Item { Layout.fillHeight: true }
}
