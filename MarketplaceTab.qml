import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Marketplace tab: browses and installs animations from the community repo.
ColumnLayout {
  id: root
  spacing: 0

  // Set by Panel.qml — the full list of animation IDs currently in the config
  property var installedIds: []
  // Set by Panel.qml — user animations dir path
  property string userAnimationsDir: ""

  signal animationInstalled(string animId, var schemaEntry)
  signal animationUninstalled(string animId)

  readonly property string indexUrl:
    "https://raw.githubusercontent.com/Evol-Luci/ascii-screensaver-animations/refs/heads/main/index.json"

  property var marketplaceEntries: []   // parsed from index.json
  property string fetchStatus: "idle"   // "idle" | "loading" | "error" | "ready"
  property string fetchError: ""
  property string filterText: ""

  readonly property var filteredEntries: {
    if (!filterText.trim()) return marketplaceEntries
    var q = filterText.toLowerCase()
    return marketplaceEntries.filter(function(e) {
      return (e.name || "").toLowerCase().indexOf(q) !== -1
        || (e.description || "").toLowerCase().indexOf(q) !== -1
        || (e.author || "").toLowerCase().indexOf(q) !== -1
    })
  }

  function isInstalled(animId) {
    return root.installedIds.indexOf(animId) !== -1
  }

  function fetch() {
    root.fetchStatus = "loading"
    root.fetchError = ""
    fetchRequest.active = true
  }

  // --- network fetch ---
  property string _rawJson: ""

  Timer {
    id: fetchRequest
    interval: 0
    repeat: false
    running: false
    property bool active: false
    onActiveChanged: if (active) { running = true }
    onTriggered: {
      var xhr = new XMLHttpRequest()
      xhr.open("GET", root.indexUrl, true)
      xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        fetchRequest.active = false
        if (xhr.status === 200) {
          root._rawJson = xhr.responseText
          root._parseIndex()
        } else {
          root.fetchStatus = "error"
          root.fetchError = "HTTP " + xhr.status + " — could not load marketplace index."
        }
      }
      xhr.send()
    }
  }

  function _parseIndex() {
    try {
      var parsed = JSON.parse(root._rawJson)
      root.marketplaceEntries = parsed.animations || []
      root.fetchStatus = "ready"
    } catch(e) {
      root.fetchStatus = "error"
      root.fetchError = "Failed to parse marketplace index: " + e
    }
  }

  // Auto-fetch on first show
  property bool _fetched: false
  onVisibleChanged: {
    if (visible && !_fetched) {
      _fetched = true
      root.fetch()
    }
  }

  // --- Install logic ---
  property var _installQueue: []
  property int _installQueueIndex: 0
  property var _installTarget: null

  function installAnimation(entry) {
    root._installTarget = entry
    root._installQueue = entry.files || []
    root._installQueueIndex = 0
    _downloadNext()
  }

  function _downloadNext() {
    if (root._installQueueIndex >= root._installQueue.length) {
      _onInstallComplete()
      return
    }
    var url = root._installQueue[root._installQueueIndex]
    var filename = url.split("/").slice(-1)[0]
    var destDir = root.userAnimationsDir + "/" + root._installTarget.id
    var destPath = destDir + "/" + filename
    _downloadFile(url, destPath, function() {
      root._installQueueIndex++
      _downloadNext()
    })
  }

  function _downloadFile(url, dest, callback) {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", url, true)
    xhr.responseType = "text"
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status === 200) {
        writeProcess.dest = dest
        writeProcess.content = xhr.responseText
        writeProcess.callback = callback
        writeProcess.running = true
      } else {
        console.warn("MarketplaceTab: failed to download", url, xhr.status)
        callback()
      }
    }
    xhr.send()
  }

  Process {
    id: writeProcess
    property string dest: ""
    property string content: ""
    property var callback: null
    command: ["bash", "-c",
      "mkdir -p '" + dest.substring(0, dest.lastIndexOf("/")) + "' && " +
      "cat > '" + dest + "'"]
    running: false
    stdin: content
    onExited: function(code, signal) {
      if (writeProcess.callback) writeProcess.callback()
    }
  }

  function _onInstallComplete() {
    var entry = root._installTarget
    var params = {}
    var paramsArr = entry.params || []
    for (var i = 0; i < paramsArr.length; i++) {
      var p = paramsArr[i]
      var spec = { type: p.type }
      if (p.defaultValue !== undefined) spec.value = p.defaultValue
      if (p.min !== undefined) spec.min = p.min
      if (p.max !== undefined) spec.max = p.max
      if (p.step !== undefined) spec.step = p.step
      if (p.integer !== undefined) spec.integer = p.integer
      if (p.options !== undefined) spec.options = p.options
      params[p.key] = spec
    }
    var schemaEntry = {
      title: entry.name,
      hint: entry.description || "",
      params: params,
      _source: "marketplace",
      _manifestVersion: entry.version || "1.0.0",
      _author: entry.author || "",
      _preview: root.userAnimationsDir + "/" + entry.id + "/" + (entry.preview ? entry.preview.split("/").slice(-1)[0] : "")
    }
    root.animationInstalled(entry.id, schemaEntry)
  }

  // --- UI ---
  
  // Toolbar
  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: Style.spacing.lg
    Layout.bottomMargin: Style.spacing.sm
    spacing: Style.spacing.md

    PanelSectionHeader {
      text: "Marketplace"
    }

    Item { Layout.fillWidth: true }

    TextField {
      id: searchField
      placeholderText: "Search animations…"
      Layout.preferredWidth: Style.space(200)
      onTextChanged: root.filterText = text
    }

    Button {
      text: root.fetchStatus === "loading" ? "Loading…" : "Refresh"
      enabled: root.fetchStatus !== "loading"
      onClicked: root.fetch()
    }
  }

  // Status / error
  Text {
    Layout.fillWidth: true
    visible: root.fetchStatus === "error"
    text: root.fetchError
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  // Animation cards (Flow without a nested ScrollView, so the outer panel ScrollView handles it)
  Flow {
    Layout.fillWidth: true
    padding: Style.spacing.md
    spacing: Style.spacing.md
    visible: root.fetchStatus === "ready"

    Repeater {
      model: root.filteredEntries
      delegate: MarketplaceCard {
        required property var modelData
        entry: modelData
        installed: root.isInstalled(modelData.id)
        onInstallClicked: root.installAnimation(modelData)
        onUninstallClicked: root.animationUninstalled(modelData.id)
      }
    }
  }
}
