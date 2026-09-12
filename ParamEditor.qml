import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "ParamMeta.js" as ParamMeta

// One row of the animation detail pane: renders whichever control suits
// this parameter's schema entry and reports the coerced value back.
ColumnLayout {
  id: root

  property string animationName: ""
  property string paramName: ""
  property var spec: ({})
  property var currentValue: undefined

  readonly property bool isBoolean: ParamMeta.isBooleanParam(spec)
  readonly property string label: ParamMeta.formatLabel(paramName)
  readonly property string description: ParamMeta.describe(paramName, animationName)
  readonly property var effectiveValue: currentValue !== undefined ? currentValue : (spec ? spec.value : undefined)

  signal edited(var value)

  Layout.fillWidth: true
  spacing: 0

  Toggle {
    Layout.fillWidth: true
    visible: root.isBoolean
    label: root.label
    description: root.description
    checked: Number(root.effectiveValue) === 1
    // Toggle reports the click, not the new state, so derive it here.
    onClicked: root.edited(Number(root.effectiveValue) === 1 ? 0 : 1)
  }

  LabeledSlider {
    Layout.fillWidth: true
    visible: !root.isBoolean && root.spec && root.spec.type === "range"
    label: root.label
    description: root.description
    value: Number(root.effectiveValue)
    minimum: root.spec && root.spec.min !== undefined ? root.spec.min : 0
    maximum: root.spec && root.spec.max !== undefined ? root.spec.max : 1
    step: root.spec && root.spec.step !== undefined ? root.spec.step : 0.1
    integer: root.spec && root.spec.integer === true
    onReleased: function (v) {
      root.edited(root.spec && root.spec.integer === true ? Math.round(v) : v)
    }
  }

  LabeledDropdown {
    Layout.fillWidth: true
    visible: !root.isBoolean && root.spec && root.spec.type === "select"
    label: root.label
    description: root.description
    value: String(root.effectiveValue)
    options: root.spec && root.spec.options ? root.spec.options : []
    onChanged: function (v) {
      // Dropdowns hand back strings; numeric selects (symmetry: 4/6/8/12)
      // must go back to disk as numbers.
      root.edited(ParamMeta.coerceSelectValue(v, root.spec ? root.spec.value : ""))
    }
  }
}
