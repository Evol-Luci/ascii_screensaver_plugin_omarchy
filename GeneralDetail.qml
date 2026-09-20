import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as C
import Quickshell
import Quickshell.Io
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
  property bool barIconEnabled: true

  // Deliberately not named modeChanged/selectedAnimationChanged: QML
  // already generates those for the properties above, and redeclaring
  // them makes the whole component fail to load.
  signal enabledToggled(bool value)
  signal modeSelected(string value)
  signal animationSelected(string value)
  signal screensaverDelayChanged(int seconds)
  signal lockDelayChanged(int seconds)
  signal previewRequested()
  signal barIconToggled(bool value)

  // Clipboard operation state — one per button, kept simple.
  property string menuCopyStatus: ""   // "", "copied", "error"
  property string hotkeyText: ""       // user types their key here
  property string hotkeyCopyStatus: "" // "", "copied", "error"

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

  Toggle {
    Layout.fillWidth: true
    label: "Show bar icon"
    description: "Show a quick-access button in the status bar that opens this settings panel. You can also manage this from the bar widget settings."
    checked: root.barIconEnabled
    onClicked: root.barIconToggled(!root.barIconEnabled)
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

  // ------------------------------------------------------------------ //
  //  Getting started                                                     //
  // ------------------------------------------------------------------ //

  PanelSeparator { Layout.fillWidth: true }

  PanelSectionHeader { text: "Getting started" }

  Text {
    Layout.fillWidth: true
    text: "The bar icon above is the easiest way to open this panel. You can also add this panel to the Omarchy settings menu, or bind a keyboard shortcut — the snippets below show how."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  // ── Settings menu ──────────────────────────────────────────────────── //

  Text {
    Layout.fillWidth: true
    text: "Add to Omarchy settings menu"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
  }

  Text {
    Layout.fillWidth: true
    text: "Add the following entry to ~/.config/omarchy/extensions/omarchy-menu.jsonc (create the file if it doesn't exist). Changes are merged live — no shell restart needed."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  // Code block — menu snippet
  Rectangle {
    Layout.fillWidth: true
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
    radius: Style.cornerRadius
    implicitHeight: menuSnippet.implicitHeight + Style.spacing.lg * 2

    Text {
      id: menuSnippet
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.spacing.lg
      text: "\"setup.ascii-screensaver\": {\n  \"icon\": \"󱄄\",\n  \"label\": \"ASCII Screensaver\",\n  \"action\": \"omarchy-shell shell summon io.github.evol-luci.ascii-screensaver '{}'\"\n}"
      color: Color.foreground
      font.family: "monospace"
      font.pixelSize: Style.font.caption
      wrapMode: Text.WrapAnywhere
    }
  }

  RowLayout {
    spacing: Style.spacing.md

    Button {
      text: root.menuCopyStatus === "copied" ? "Copied!" : (root.menuCopyStatus === "error" ? "Copy failed" : "Copy snippet")
      enabled: root.menuCopyStatus !== "copied"
      onClicked: menuCopyProc.run()
    }

    Text {
      visible: root.menuCopyStatus === "copied"
      text: "Paste into ~/.config/omarchy/extensions/omarchy-menu.jsonc"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Text {
      visible: root.menuCopyStatus === "error"
      text: "wl-copy not found — copy the snippet manually."
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }

  // ── Keyboard shortcut ──────────────────────────────────────────────── //

  Text {
    Layout.fillWidth: true
    text: "Bind a keyboard shortcut"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
  }

  Text {
    Layout.fillWidth: true
    text: "Add this line to your Hyprland config (usually ~/.config/hypr/hyprland.conf). Replace F12 with your preferred key. Changes take effect immediately."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  // Key entry field
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.md

    Text {
      text: "Key:"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    // C.TextField from QtQuick.Controls — matches the pattern used by Scout, Daybook, etc.
    C.TextField {
      id: hotkeyField
      implicitWidth: Style.space(80)
      placeholderText: "F12"
      text: root.hotkeyText
      color: Color.foreground
      placeholderTextColor: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      background: Rectangle {
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
        border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.2)
        radius: Style.cornerRadius
      }
      onTextEdited: {
        root.hotkeyText = text
        root.hotkeyCopyStatus = ""
      }
    }
  }

  // Code block — hyprland bind snippet (updates live as user types)
  Rectangle {
    Layout.fillWidth: true
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
    radius: Style.cornerRadius
    implicitHeight: hyprSnippet.implicitHeight + Style.spacing.lg * 2

    Text {
      id: hyprSnippet
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.spacing.lg
      text: "bind = SUPER, " + (root.hotkeyText.trim() !== "" ? root.hotkeyText.trim() : "F12")
            + ", exec, omarchy-shell shell summon io.github.evol-luci.ascii-screensaver '{}'"
      color: Color.foreground
      font.family: "monospace"
      font.pixelSize: Style.font.caption
      wrapMode: Text.WrapAnywhere
    }
  }

  RowLayout {
    spacing: Style.spacing.md

    Button {
      text: root.hotkeyCopyStatus === "copied" ? "Copied!" : (root.hotkeyCopyStatus === "error" ? "Copy failed" : "Copy snippet")
      enabled: root.hotkeyCopyStatus !== "copied"
      onClicked: hotkeyCopyProc.run()
    }

    Text {
      visible: root.hotkeyCopyStatus === "copied"
      text: "Paste into ~/.config/hypr/hyprland.conf"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    Text {
      visible: root.hotkeyCopyStatus === "error"
      text: "wl-copy not found — copy the snippet manually."
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }

  // ── Clipboard processes ────────────────────────────────────────────── //

  Process {
    id: menuCopyProc

    function run() {
      var snippet = "\"setup.ascii-screensaver\": {\n  \"icon\": \"󱄄\",\n  \"label\": \"ASCII Screensaver\",\n  \"action\": \"omarchy-shell shell summon io.github.evol-luci.ascii-screensaver '{}'\"\n}"
      menuCopyProc.command = ["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]
      menuCopyProc.running = true
    }

    onExited: function(exitCode) {
      root.menuCopyStatus = (exitCode === 0) ? "copied" : "error"
      if (exitCode === 0) menuResetTimer.restart()
    }
  }

  Timer {
    id: menuResetTimer
    interval: 4000
    repeat: false
    onTriggered: root.menuCopyStatus = ""
  }

  Process {
    id: hotkeyCopyProc

    function run() {
      var key = root.hotkeyText.trim() !== "" ? root.hotkeyText.trim() : "F12"
      var snippet = "bind = SUPER, " + key + ", exec, omarchy-shell shell summon io.github.evol-luci.ascii-screensaver '{}'"
      hotkeyCopyProc.command = ["bash", "-c", "printf '%s' " + JSON.stringify(snippet) + " | wl-copy"]
      hotkeyCopyProc.running = true
    }

    onExited: function(exitCode) {
      root.hotkeyCopyStatus = (exitCode === 0) ? "copied" : "error"
      if (exitCode === 0) hotkeyResetTimer.restart()
    }
  }

  Timer {
    id: hotkeyResetTimer
    interval: 4000
    repeat: false
    onTriggered: root.hotkeyCopyStatus = ""
  }

  Item { Layout.fillHeight: true }
}
