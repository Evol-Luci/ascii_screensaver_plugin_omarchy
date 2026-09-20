import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ConfigPaths.js" as ConfigPaths
import "ParamMeta.js" as ParamMeta

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool closingFromHost: false
  readonly property bool opened: window.visible

  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string schemaPath: root.pluginDir + "/params.schema.json"

  property var schema: ({})
  property var userSchema: ({})
  property var persistedConfig: ({ enabled: true, mode: "random", selectedAnimation: "terrarium", animations: [] })
  property bool configLoaded: false

  // "" is the welcome pane, "general" the shared settings, anything else
  // is an animation name.
  property string selection: ""

  readonly property var animationNames: {
    var builtIn = Object.keys(root.schema)
    var user = Object.keys(root.userSchema)
    var all = builtIn.slice()
    for (var i = 0; i < user.length; i++) {
      if (all.indexOf(user[i]) === -1) all.push(user[i])
    }
    return all
  }

  function schemaFor(name) {
    return root.schema[name] || root.userSchema[name] || ({ title: name, params: ({}) })
  }
  readonly property bool randomMode: root.persistedConfig.mode !== "single"

  // A payload of {"select": "bonsai"} opens straight to that animation,
  // or {"select": "general"} to the shared settings, so a keybinding can
  // deep-link to one page instead of always landing on the welcome pane.
  function open(payloadJson) {
    closingFromHost = false
    try {
      var payload = JSON.parse(payloadJson || "{}")
      if (payload && typeof payload.select === "string") root.selection = payload.select
    } catch (e) {
      // A malformed payload just means the default welcome pane.
    }
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

  // Reassigning the property is what makes QML re-evaluate the bindings
  // that read it; mutating the object in place changes the data silently
  // and leaves the panel showing stale values.
  function commit() {
    root.persistedConfig = Object.assign({}, root.persistedConfig)
    root.saveConfig()
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
      console.warn("ascii-screensaver Panel.qml: failed to parse config:", e)
    }
    root.configLoaded = true
    userAnimLoader.scan()
  }

  // Read-only lookup. Bindings call this, so it must never mutate the
  // config — creating entries during binding evaluation causes both stale
  // renders and binding loops.
  function entryFor(name) {
    var list = root.persistedConfig.animations || []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].name === name) return list[i]
    }
    return { name: name, enabled: true, weight: 2, params: ({}) }
  }

  // Mutating counterpart, only ever called from an edit handler.
  function ensureEntry(name) {
    var list = root.persistedConfig.animations || []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].name === name) return list[i]
    }
    var created = { name: name, enabled: true, weight: 2, params: ({}) }
    list.push(created)
    root.persistedConfig.animations = list
    return created
  }

  function setAnimationEnabled(name, value) {
    ensureEntry(name).enabled = value
    commit()
  }

  function setAnimationWeight(name, weight) {
    ensureEntry(name).weight = weight
    commit()
  }

  function setParamValue(name, paramName, value) {
    var entry = ensureEntry(name)
    if (!entry.params) entry.params = ({})
    entry.params[paramName] = value
    commit()
  }

  function uninstallAnimation(name) {
    var list = root.persistedConfig.animations || []
    var filtered = []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].name !== name) filtered.push(list[i])
    }
    root.persistedConfig.animations = filtered
    if (root.userSchema[name] !== undefined) {
      var newUserSchema = Object.assign({}, root.userSchema)
      delete newUserSchema[name]
      root.userSchema = newUserSchema
    }
    if (root.selection === name) root.selection = ""
    root.commit()
  }

  function paramCount(name) {
    var definition = root.schemaFor(name)
    return definition && definition.params ? Object.keys(definition.params).length : 0
  }

  function sidebarSubtitle(name) {
    var entry = entryFor(name)
    var count = paramCount(name)
    var settings = count + (count === 1 ? " setting" : " settings")
    if (entry.enabled === false) return "Off · " + settings
    if (root.randomMode && Number(entry.weight) === 0) return "Never picked · " + settings
    if (root.randomMode) return "Weight " + Number(entry.weight || 0) + " · " + settings
    return settings
  }

  function enabledCount() {
    var total = 0
    for (var i = 0; i < root.animationNames.length; i++) {
      if (entryFor(root.animationNames[i]).enabled !== false) total++
    }
    return total
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

  UserAnimationLoader {
    id: userAnimLoader
    animationsDir: ConfigPaths.userAnimationsDir()
    onManifestLoaded: function(name, schemaEntry) {
      var updated = Object.assign({}, root.userSchema)
      updated[name] = schemaEntry
      root.userSchema = updated
    }
  }

  FloatingWindow {
    id: window
    visible: false
    title: "ASCII Screensaver Settings"
    color: Color.background
    implicitWidth: Style.space(860)
    implicitHeight: Style.space(680)
    minimumSize: Qt.size(Style.space(360), Style.space(360))

    // Below this the two panes cannot both stay readable, so only one is
    // shown at a time.
    readonly property bool narrow: width < Style.space(620)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide((root.manifest && root.manifest.id) || "io.github.evol-luci.ascii-screensaver")
      }
    }

    Shortcut {
      sequence: "Escape"
      onActivated: root.requestClose()
    }

    RowLayout {
      anchors.fill: parent
      spacing: 0

      // ------------------------------------------------------------ sidebar
      Item {
        Layout.fillHeight: true
        Layout.fillWidth: window.narrow
        Layout.preferredWidth: window.narrow ? -1 : Style.space(248)
        visible: !window.narrow || root.selection === ""

        ScrollView {
          id: sidebarScroll
          anchors.fill: parent
          contentWidth: availableWidth
          clip: true

          ColumnLayout {
            width: sidebarScroll.availableWidth
            spacing: Style.spacing.xxs

            Item { Layout.preferredHeight: Style.spacing.lg }

            SidebarRow {
              Layout.fillWidth: true
              Layout.leftMargin: Style.spacing.md
              Layout.rightMargin: Style.spacing.md
              title: "General"
              subtitle: root.persistedConfig.enabled === false
                ? "Screensaver off"
                : (root.randomMode ? "Random · " + ParamMeta.formatDuration(root.persistedConfig.screensaverDelaySeconds !== undefined ? root.persistedConfig.screensaverDelaySeconds : 150)
                                   : "Single · " + ParamMeta.formatDuration(root.persistedConfig.screensaverDelaySeconds !== undefined ? root.persistedConfig.screensaverDelaySeconds : 150))
              selected: root.selection === "general"
              onClicked: root.selection = "general"
            }

            PanelSeparator {
              Layout.fillWidth: true
              Layout.topMargin: Style.spacing.sm
              Layout.bottomMargin: Style.spacing.sm
              Layout.leftMargin: Style.spacing.xl
              Layout.rightMargin: Style.spacing.xl
            }

            SidebarRow {
              Layout.fillWidth: true
              Layout.leftMargin: Style.spacing.md
              Layout.rightMargin: Style.spacing.md
              title: "Marketplace"
              subtitle: "Browse & install animations"
              selected: root.selection === "marketplace"
              onClicked: root.selection = "marketplace"
            }

            PanelSeparator {
              Layout.fillWidth: true
              Layout.topMargin: Style.spacing.sm
              Layout.bottomMargin: Style.spacing.sm
              Layout.leftMargin: Style.spacing.xl
              Layout.rightMargin: Style.spacing.xl
            }

            PanelSectionHeader {
              text: "Animations"
              Layout.leftMargin: Style.spacing.xl
            }

            Repeater {
              model: root.animationNames

              delegate: SidebarRow {
                required property string modelData

                Layout.fillWidth: true
                Layout.leftMargin: Style.spacing.md
                Layout.rightMargin: Style.spacing.md
                title: root.schemaFor(modelData) && root.schemaFor(modelData).title
                  ? root.schemaFor(modelData).title : ParamMeta.formatLabel(modelData)
                subtitle: root.sidebarSubtitle(modelData)
                selected: root.selection === modelData
                dimmed: root.entryFor(modelData).enabled === false
                onClicked: root.selection = modelData
              }
            }

            Item { Layout.preferredHeight: Style.spacing.lg }
          }
        }
      }

      Rectangle {
        visible: !window.narrow
        Layout.fillHeight: true
        Layout.preferredWidth: Style.normalBorderWidth
        color: Color.muted
        opacity: 0.25
      }

      // ------------------------------------------------------------- detail
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !window.narrow || root.selection !== ""

        ScrollView {
          id: detailScroll
          anchors.fill: parent
          contentWidth: availableWidth
          clip: true

          ColumnLayout {
            // Binding to the ScrollView's availableWidth (rather than
            // parent.width) is what makes the pane reflow when the window
            // is resized.
            width: detailScroll.availableWidth
            spacing: Style.spacing.lg

            Item { Layout.preferredHeight: Style.spacing.md }

            Button {
              Layout.leftMargin: Style.spacing.xl
              visible: window.narrow
              text: "Back"
              onClicked: root.selection = ""
            }

            WelcomePane {
              Layout.fillWidth: true
              Layout.maximumWidth: Style.space(680)
              Layout.leftMargin: Style.spacing.xl
              Layout.rightMargin: Style.spacing.xl
              visible: root.selection === ""
              animationCount: root.animationNames.length
              enabledCount: root.enabledCount()
              mode: root.persistedConfig.mode || "random"
            }

            GeneralDetail {
              Layout.fillWidth: true
              Layout.maximumWidth: Style.space(680)
              Layout.leftMargin: Style.spacing.xl
              Layout.rightMargin: Style.spacing.xl
              visible: root.selection === "general"
              screensaverEnabled: root.persistedConfig.enabled !== false
              mode: root.persistedConfig.mode || "random"
              selectedAnimation: root.persistedConfig.selectedAnimation || "terrarium"
              animationOptions: root.animationNames
              barIconEnabled: root.persistedConfig.showBarIcon !== false
              screensaverDelaySeconds: root.persistedConfig.screensaverDelaySeconds !== undefined
                ? root.persistedConfig.screensaverDelaySeconds : 150
              lockDelaySeconds: root.persistedConfig.lockDelaySeconds !== undefined
                ? root.persistedConfig.lockDelaySeconds : 300

              onEnabledToggled: function (value) {
                root.persistedConfig.enabled = value
                root.commit()
              }
              onModeSelected: function (value) {
                root.persistedConfig.mode = value
                root.commit()
              }
              onAnimationSelected: function (value) {
                root.persistedConfig.selectedAnimation = value
                root.commit()
              }
              onScreensaverDelayChanged: function (seconds) {
                root.persistedConfig.screensaverDelaySeconds = seconds
                root.commit()
              }
              onLockDelayChanged: function (seconds) {
                root.persistedConfig.lockDelaySeconds = seconds
                root.commit()
              }
              onBarIconToggled: function (value) {
                root.persistedConfig.showBarIcon = value
                root.commit()
              }
              onPreviewRequested: Quickshell.execDetached(["bash", root.pluginDir + "/bin/ascii-screensaver-launch", "force"])
            }


            AnimationDetail {
              Layout.fillWidth: true
              Layout.maximumWidth: Style.space(680)
              Layout.leftMargin: Style.spacing.xl
              Layout.rightMargin: Style.spacing.xl
              visible: root.selection !== "" && root.selection !== "general" && root.selection !== "marketplace"
              animationName: root.selection
              isUserInstalled: root.userSchema[root.selection] !== undefined
              onUninstallRequested: root.uninstallAnimation(root.selection)
              animationSchema: root.schemaFor(root.selection) || ({ title: root.selection, params: ({}) })
              entry: root.entryFor(root.selection)
              randomMode: root.randomMode

              onEnabledToggled: function (value) { root.setAnimationEnabled(root.selection, value) }
              onWeightChanged: function (weight) { root.setAnimationWeight(root.selection, weight) }
              onParamEdited: function (paramName, value) { root.setParamValue(root.selection, paramName, value) }
              onPreviewRequested: Quickshell.execDetached(

                ["bash", root.pluginDir + "/bin/ascii-screensaver-launch", "force", root.selection])
            }

            MarketplaceTab {
              Layout.fillWidth: true
              Layout.fillHeight: true
              visible: root.selection === "marketplace"
              installedIds: root.animationNames
              userAnimationsDir: ConfigPaths.userAnimationsDir()

              onAnimationInstalled: function(animId, schemaEntry) {
                var updated = Object.assign({}, root.userSchema)
                updated[animId] = schemaEntry
                root.userSchema = updated
                root.ensureEntry(animId)
                root.commit()
              }
              onAnimationUninstalled: function(animId) {
                root.uninstallAnimation(animId)
              }
            }


            Item { Layout.preferredHeight: Style.spacing.xl }
          }
        }
      }
    }
  }
}
