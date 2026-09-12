import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ConfigPaths.js" as ConfigPaths

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool closingFromHost: false
  readonly property bool opened: window.visible

  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string schemaPath: root.pluginDir + "/params.schema.json"

  property var schema: ({})
  property var persistedConfig: ({ enabled: true, mode: "random", selectedAnimation: "terrarium", animations: [] })
  property bool configLoaded: false

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
  }

  function close() {
    closingFromHost = true
    window.visible = false
  }

  function requestClose() {
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.evol-luci.ascii-screensaver")
    } else {
      window.visible = false
    }
  }

  function saveConfig() {
    var text = JSON.stringify(root.persistedConfig, null, 2) + "\n"
    if (userConfigFile.loaded) userConfigFile.setText(text)
    else bundledConfigFile.setText(text)
  }

  function parsePersistedConfig(jsonText) {
    try {
      var parsed = JSON.parse(jsonText)
      if (parsed && typeof parsed === "object") root.persistedConfig = parsed
    } catch (e) {
      console.warn("ascii-screensaver Settings.qml: failed to parse config:", e)
    }
    root.configLoaded = true
  }

  function animationEntry(name) {
    var list = root.persistedConfig.animations || []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].name === name) return list[i]
    }
    var created = { name: name, enabled: true, weight: 2, params: ({}) }
    list.push(created)
    root.persistedConfig.animations = list
    return created
  }

  function paramValue(animationName, paramName, fallback) {
    var entry = root.animationEntry(animationName)
    var value = entry.params ? entry.params[paramName] : undefined
    return value !== undefined ? value : fallback
  }

  function setParamValue(animationName, paramName, value) {
    var entry = root.animationEntry(animationName)
    if (!entry.params) entry.params = ({})
    entry.params[paramName] = value
    root.saveConfig()
  }

  FileView {
    id: schemaFile
    path: root.schemaPath
    watchChanges: false
    onLoaded: {
      try { root.schema = JSON.parse(text()) } catch (e) { root.schema = ({}) }
    }
  }

  FileView {
    id: userConfigFile
    path: ConfigPaths.userConfigPath()
    watchChanges: true
    printErrors: false
    onLoaded: root.parsePersistedConfig(text())
    onLoadFailed: function(error) { bundledConfigFile.reload() }
    onFileChanged: reload()
  }

  FileView {
    id: bundledConfigFile
    path: ConfigPaths.bundledConfigPath(root.pluginDir)
    watchChanges: true
    printErrors: false
    onLoaded: root.parsePersistedConfig(text())
    onLoadFailed: function(error) { root.configLoaded = true }
    onFileChanged: reload()
  }

  FloatingWindow {
    id: window
    visible: false
    title: "ASCII Screensaver Settings"
    color: Color.background
    implicitWidth: Style.space(640)
    implicitHeight: Style.space(760)
    minimumSize: Qt.size(Style.space(420), Style.space(420))

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide((root.manifest && root.manifest.id) || "io.github.evol-luci.ascii-screensaver")
      }
    }

    Shortcut {
      sequence: "Escape"
      onActivated: root.requestClose()
    }

    ScrollView {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      clip: true

      ColumnLayout {
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)

          Toggle {
            label: "Enabled"
            checked: root.persistedConfig.enabled !== false
            onClicked: {
              root.persistedConfig.enabled = !checked
              root.saveConfig()
            }
          }

          Dropdown {
            label: "Mode"
            value: root.persistedConfig.mode === "single" ? "single" : "random"
            options: ["random", "single"]
            onChanged: function(newValue) {
              root.persistedConfig.mode = newValue
              root.saveConfig()
            }
          }
        }

        Dropdown {
          Layout.fillWidth: true
          visible: root.persistedConfig.mode === "single"
          label: "Selected animation"
          value: root.persistedConfig.selectedAnimation || "terrarium"
          options: Object.keys(root.schema)
          onChanged: function(newValue) {
            root.persistedConfig.selectedAnimation = newValue
            root.saveConfig()
          }
        }

        PanelSeparator { Layout.fillWidth: true }

        PanelSectionHeader { text: "Timing" }

        PanelSlider {
          Layout.fillWidth: true
          minimum: 10
          maximum: 3600
          step: 5
          integer: true
          value: root.persistedConfig.screensaverDelaySeconds !== undefined
            ? root.persistedConfig.screensaverDelaySeconds : 150
          onReleased: function(newValue) {
            root.persistedConfig.screensaverDelaySeconds = Math.round(newValue)
            root.saveConfig()
          }
        }

        PanelSlider {
          Layout.fillWidth: true
          minimum: 10
          maximum: 3600
          step: 5
          integer: true
          value: root.persistedConfig.lockDelaySeconds !== undefined
            ? root.persistedConfig.lockDelaySeconds : 300
          onReleased: function(newValue) {
            root.persistedConfig.lockDelaySeconds = Math.round(newValue)
            root.saveConfig()
          }
        }

        Button {
          text: "Preview Now"
          onClicked: Quickshell.execDetached(["bash", root.pluginDir + "/bin/ascii-screensaver-launch", "force"])
        }

        PanelSeparator { Layout.fillWidth: true }

        Repeater {
          model: Object.keys(root.schema)
          delegate: ColumnLayout {
            id: animationSection
            required property string modelData
            readonly property string animationName: modelData
            readonly property var animationSchema: root.schema[animationName] || { title: animationName, params: ({}) }
            Layout.fillWidth: true
            spacing: Style.space(6)

            PanelSectionHeader { text: animationSection.animationSchema.title || animationSection.animationName }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(12)

              Toggle {
                label: "Enabled"
                checked: root.animationEntry(animationSection.animationName).enabled !== false
                onClicked: {
                  root.animationEntry(animationSection.animationName).enabled = !checked
                  root.saveConfig()
                }
              }

              PanelSlider {
                Layout.fillWidth: true
                visible: root.persistedConfig.mode !== "single"
                minimum: 0
                maximum: 20
                step: 1
                integer: true
                value: root.animationEntry(animationSection.animationName).weight || 0
                onReleased: function(newValue) {
                  root.animationEntry(animationSection.animationName).weight = Math.round(newValue)
                  root.saveConfig()
                }
              }
            }

            Repeater {
              model: Object.keys(animationSection.animationSchema.params || {})
              delegate: RowLayout {
                id: paramRow
                required property string modelData
                readonly property string paramName: modelData
                readonly property var paramSchema: animationSection.animationSchema.params[paramName]
                Layout.fillWidth: true

                PanelSlider {
                  Layout.fillWidth: true
                  visible: paramRow.paramSchema.type === "range"
                  minimum: paramRow.paramSchema.min !== undefined ? paramRow.paramSchema.min : 0
                  maximum: paramRow.paramSchema.max !== undefined ? paramRow.paramSchema.max : 1
                  step: paramRow.paramSchema.step !== undefined ? paramRow.paramSchema.step : 0.1
                  integer: paramRow.paramSchema.integer === true
                  value: root.paramValue(animationSection.animationName, paramRow.paramName, paramRow.paramSchema.value)
                  onReleased: function(newValue) {
                    root.setParamValue(animationSection.animationName, paramRow.paramName,
                      paramRow.paramSchema.integer === true ? Math.round(newValue) : newValue)
                  }
                }

                Dropdown {
                  Layout.fillWidth: true
                  visible: paramRow.paramSchema.type === "select"
                  label: paramRow.paramName
                  value: String(root.paramValue(animationSection.animationName, paramRow.paramName, paramRow.paramSchema.value))
                  options: paramRow.paramSchema.options || []
                  onChanged: function(newValue) {
                    root.setParamValue(animationSection.animationName, paramRow.paramName, newValue)
                  }
                }
              }
            }

            PanelSeparator { Layout.fillWidth: true }
          }
        }
      }
    }
  }
}
