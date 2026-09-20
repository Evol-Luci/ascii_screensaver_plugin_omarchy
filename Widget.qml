import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ConfigPaths.js" as ConfigPaths

// Bar widget entry point for ASCII Screensaver.
// Renders a single WidgetButton that summons the existing FloatingWindow
// settings panel via the omarchy-shell IPC — no duplicate UI needed.
//
// Visibility is driven by two sources in priority order:
//   1. Our own screensaver-config.json (written by the General page toggle).
//   2. The bar widget settings object from the manifest schema (default true).
// This lets the in-panel toggle work without cross-entrypoint communication.

BarWidget {
  id: root
  moduleName: "io.github.evol-luci.ascii-screensaver"

  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")

  // Config from our own screensaver-config.json (undefined = not yet loaded).
  property var ownConfig: ({})
  property bool ownConfigLoaded: false

  // Bar widget setting from the manifest schema (injected via `settings`).
  readonly property bool settingShowIcon: settings ? settings.showBarIcon !== false : true

  // Our own config key takes precedence once loaded; otherwise fall back to
  // the manifest setting.
  readonly property bool showIcon: ownConfigLoaded
    ? (ownConfig.showBarIcon !== false)
    : settingShowIcon

  implicitWidth:  showIcon ? button.implicitWidth  : 0
  implicitHeight: showIcon ? button.implicitHeight : 0
  visible: showIcon

  // Watch the same user config path that Panel.qml writes to, so toggling
  // "Show bar icon" in the General page is reflected here immediately.
  FileView {
    id: userConfigFile
    path: ConfigPaths.userConfigPath()
    watchChanges: true
    printErrors: false
    onLoaded: parseConfig(text())
    onLoadFailed: bundledConfigFile.reload()
    onFileChanged: reload()
  }

  FileView {
    id: bundledConfigFile
    path: ConfigPaths.bundledConfigPath(root.pluginDir)
    watchChanges: true
    printErrors: false
    onLoaded: parseConfig(text())
    onLoadFailed: function(error) { root.ownConfigLoaded = true }
    onFileChanged: reload()
  }

  function parseConfig(jsonText) {
    try {
      var parsed = JSON.parse(jsonText)
      if (parsed && typeof parsed === "object") root.ownConfig = parsed
    } catch (e) {
      // Malformed config — keep defaults.
    }
    root.ownConfigLoaded = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Nerd Font: nf-md-monitor (󱄄, U+F1104) — matches the README's suggested icon.
    text: "\uDB84\uDD04"
    tooltipText: "ASCII Screensaver — open settings"
    Accessible.name: "Open ASCII Screensaver settings"
    Accessible.role: Accessible.Button
    Accessible.onPressAction: button.triggerPress(Qt.LeftButton)
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton)
        Quickshell.execDetached([
          "omarchy-shell", "shell", "summon",
          "io.github.evol-luci.ascii-screensaver", "{}"
        ])
    }
  }
}
