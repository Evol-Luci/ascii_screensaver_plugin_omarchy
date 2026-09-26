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
  // Set by Panel.qml — animation IDs bundled with the plugin. The seed
  // marketplace catalog mirrors these 1:1, so "installing" one of them has
  // nothing to download — it just un-hides the bundled copy (see
  // Panel.qml's reinstallBuiltin).
  property var builtinIds: []
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
  property string sortMode: "alpha" // "alpha", "newest", "random"
  property var _randomPool: []

  function showRandom() {
    var pool = marketplaceEntries.slice()
    for (var i = pool.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1))
      var temp = pool[i]
      pool[i] = pool[j]
      pool[j] = temp
    }
    _randomPool = pool.slice(0, 10)
    sortMode = "random"
  }

  readonly property var filteredEntries: {
    var list = marketplaceEntries.slice()
    
    if (sortMode === "alpha") {
      list.sort(function(a, b) {
        var nameA = (a.name || "").toLowerCase()
        var nameB = (b.name || "").toLowerCase()
        if (nameA < nameB) return -1
        if (nameA > nameB) return 1
        return 0
      })
    } else if (sortMode === "newest") {
      list.reverse()
      list = list.slice(0, 10)
    } else if (sortMode === "random") {
      list = _randomPool
    }

    if (!filterText.trim()) return list
    var q = filterText.toLowerCase()
    return list.filter(function(e) {
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
      xhr.timeout = 10000
      xhr.ontimeout = function() {
        fetchRequest.active = false
        root.fetchStatus = "error"
        root.fetchError = "Request timed out after 10s — could not load marketplace index."
      }
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
  // Installs are queued and run one at a time. Each job owns its own entry
  // and file-index instead of sharing them on `root` — installing several
  // animations before the first one finishes used to overwrite that shared
  // state, so only the last click's install ever actually completed (the
  // others' downloads got silently reattributed to it or dropped).
  property var _installJobs: []
  property bool _installBusy: false
  // Ids currently queued or downloading, so a card can show "Installing…"
  // and a second click on the same card doesn't queue a redundant job.
  property var installingIds: []

  function installAnimation(entry) {
    if (root.builtinIds.indexOf(entry.id) !== -1) {
      root.animationInstalled(entry.id, null)
      return
    }
    if (root.installingIds.indexOf(entry.id) !== -1) return
    root.installingIds = root.installingIds.concat([entry.id])
    root._installJobs.push({ entry: entry, files: entry.files || [], fileIndex: 0 })
    if (!root._installBusy) _processNextJob()
  }

  function _processNextJob() {
    if (root._installJobs.length === 0) {
      root._installBusy = false
      return
    }
    root._installBusy = true
    _downloadNextFile(root._installJobs[0])
  }

  function _downloadNextFile(job) {
    if (job.fileIndex >= job.files.length) {
      _onInstallComplete(job.entry)
      root._installJobs.shift()
      root.installingIds = root.installingIds.filter(function(id) { return id !== job.entry.id })
      _processNextJob()
      return
    }
    var url = job.files[job.fileIndex]
    var filename = url.split("/").slice(-1)[0]
    var destDir = root.userAnimationsDir + "/" + job.entry.id
    var destPath = destDir + "/" + filename
    _downloadFile(url, destPath, function() {
      job.fileIndex++
      _downloadNextFile(job)
    })
  }

  function _downloadFile(url, dest, callback) {
    downloadProcess.url = url
    downloadProcess.dest = dest
    downloadProcess.callback = callback
    downloadProcess.running = true
  }

  Process {
    id: downloadProcess
    property string url: ""
    property string dest: ""
    property var callback: null
    command: ["curl", "-sL", "--create-dirs", "-o", dest, url]
    running: false
    onExited: function(code, signal) {
      if (downloadProcess.callback) downloadProcess.callback()
    }
  }

  function _onInstallComplete(entry) {
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
      Layout.preferredWidth: Style.space(160)
      onTextChanged: {
        root.filterText = text
        if (text && root.sortMode !== "alpha") root.sortMode = "alpha"
      }
    }

    Button {
      text: "A-Z"
      selected: root.sortMode === "alpha"
      onClicked: root.sortMode = "alpha"
    }

    Button {
      text: "10 Newest"
      selected: root.sortMode === "newest"
      onClicked: root.sortMode = "newest"
    }

    Button {
      text: "Random 10"
      selected: root.sortMode === "random"
      onClicked: root.showRandom()
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
        installing: root.installingIds.indexOf(modelData.id) !== -1
        onInstallClicked: root.installAnimation(modelData)
        onUninstallClicked: root.animationUninstalled(modelData.id)
      }
    }
  }
}
