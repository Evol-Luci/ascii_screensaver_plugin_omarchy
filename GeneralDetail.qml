import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "ParamMeta.js" as ParamMeta

// Settings that apply to the screensaver as a whole, rather than to one
// animation.
ColumnLayout {
  id: root

  property bool screensaverEnabled: true
  property string mode: "random"
  property string selectedAnimation: "terrarium"
  property var animationOptions: []
  property int screensaverDelaySeconds: 150
  property int lockDelaySeconds: 300

  // Deliberately not named modeChanged/selectedAnimationChanged: QML
  // already generates those for the properties above, and redeclaring
  // them makes the whole component fail to load.
  signal enabledToggled(bool value)
  signal modeSelected(string value)
  signal animationSelected(string value)
  signal screensaverDelayChanged(int seconds)
  signal lockDelayChanged(int seconds)
  signal previewRequested()

  spacing: Style.spacing.xl

  Text {
    Layout.fillWidth: true
    text: "General"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
  }

  Toggle {
    Layout.fillWidth: true
    label: "Screensaver enabled"
    description: "Turn the whole screensaver off without uninstalling the plugin. The lock screen still works."
    checked: root.screensaverEnabled
    onClicked: root.enabledToggled(!root.screensaverEnabled)
  }

  LabeledDropdown {
    Layout.fillWidth: true
    label: "Launch mode"
    description: "Random picks a different enabled animation each time, weighted per animation. Single always plays the same one."
    value: root.mode
    options: ["random", "single"]
    onChanged: function (v) { root.modeSelected(v) }
  }

  LabeledDropdown {
    Layout.fillWidth: true
    visible: root.mode === "single"
    label: "Animation to play"
    description: "The animation shown every time the screensaver starts."
    value: root.selectedAnimation
    options: root.animationOptions
    onChanged: function (v) { root.animationSelected(v) }
  }

  PanelSeparator { Layout.fillWidth: true }

  PanelSectionHeader { text: "Timing" }

  LabeledSlider {
    Layout.fillWidth: true
    label: "Screensaver after"
    description: "How long the machine sits idle before the screensaver starts."
    valueText: ParamMeta.formatDuration(displayValue)
    value: root.screensaverDelaySeconds
    minimum: 10
    maximum: 3600
    step: 5
    integer: true
    onReleased: function (v) { root.screensaverDelayChanged(Math.round(v)) }
  }

  LabeledSlider {
    Layout.fillWidth: true
    label: "Lock after"
    description: "How long the machine sits idle before the screen locks. Set this longer than the screensaver delay, or the screensaver never gets a chance to show."
    valueText: ParamMeta.formatDuration(displayValue)
    value: root.lockDelaySeconds
    minimum: 10
    maximum: 3600
    step: 5
    integer: true
    onReleased: function (v) { root.lockDelayChanged(Math.round(v)) }
  }

  Text {
    Layout.fillWidth: true
    visible: root.lockDelaySeconds <= root.screensaverDelaySeconds
    text: "The lock currently fires at or before the screensaver, so the screensaver will not be seen."
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  PanelSeparator { Layout.fillWidth: true }

  Button {
    text: "Preview now"
    onClicked: root.previewRequested()
  }

  Text {
    Layout.fillWidth: true
    // Deliberately different from the per-animation preview button: this
    // one exercises the real selection, which is how you check whether
    // your weighting feels right.
    text: root.mode === "single"
      ? "Runs the screensaver full screen, playing the animation chosen above. Move the mouse or press a key to dismiss it."
      : "Runs the screensaver full screen, picking an animation at random exactly as it would on idle — so run it a few times to check your weights. To preview one specific animation, open it on the left instead."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Item { Layout.fillHeight: true }
}
