import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "MarketplaceValidation.js" as MarketplaceValidation

// Marketplace tab: browses and installs animations from the community repo.
// Everything in index.json is community-submitted and therefore untrusted:
// ids, file names and URLs all go through MarketplaceValidation before they
// reach a filesystem path or a process argument.
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
      // Validate before anything is shown or installable. An entry we cannot
      // vouch for is dropped rather than repaired — we cannot know which part
      // of it was intended.
      var checked = MarketplaceValidation.validateIndex(parsed.animations || [], root.userAnimationsDir)
      var entries = []
      var filesById = ({})
      for (var i = 0; i < checked.entries.length; i++) {
        entries.push(checked.entries[i].entry)
        filesById[checked.entries[i].entry.id] = checked.entries[i].files
      }
      root.marketplaceEntries = entries
      root._validatedFiles = filesById
      root.rejectedEntries = checked.rejected
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
  // Per-entry validated file list, keyed by animation id, built in
  // _parseIndex. The install path reads destinations from here and never
  // rebuilds a path out of index data.
  property var _validatedFiles: ({})
  // Entries the index offered that we refused, for the "N hidden" note.
  property var rejectedEntries: []
  // Ids whose last install attempt failed, so the card can say so instead of
  // silently claiming success.
  property var failedIds: []
  property string installError: ""

  function installAnimation(entry) {
    if (root.builtinIds.indexOf(entry.id) !== -1) {
      root.animationInstalled(entry.id, null)
      return
    }
    if (root.installingIds.indexOf(entry.id) !== -1) return

    // Re-validate at the point of use rather than trusting that this entry
    // came from the filtered list — installAnimation is reachable from the
    // card delegate with whatever modelData holds.
    var checked = MarketplaceValidation.validateEntry(entry, root.userAnimationsDir)
    if (!checked.ok) {
      root.installError = "Refused to install \"" + (entry && entry.id ? entry.id : "(unnamed)")
        + "\": " + checked.reason + "."
      if (entry && entry.id && root.failedIds.indexOf(entry.id) === -1) {
        root.failedIds = root.failedIds.concat([entry.id])
      }
      return
    }

    root.failedIds = root.failedIds.filter(function(id) { return id !== entry.id })
    root.installingIds = root.installingIds.concat([entry.id])
    root._installJobs.push({
      entry: entry,
      id: checked.id,
      files: checked.files,
      destDir: root.userAnimationsDir + "/" + checked.id,
      fileIndex: 0
    })
    if (!root._installBusy) _processNextJob()
  }

  function _processNextJob() {
    if (root._installJobs.length === 0) {
      root._installBusy = false
      return
    }
    root._installBusy = true
    _prepareJobDir(root._installJobs[0])
  }

  // Clear the entry's directory before writing into it, so a symlink left
  // behind by an earlier install can't redirect curl's -o target; curl's
  // --create-dirs then recreates it as a real directory. The id is already
  // known to be a single safe path segment and the destination is known to be
  // inside the animations dir, so this rm is bounded to one entry. Argv form,
  // never a shell string — no part of this is parsed by a shell.
  function _prepareJobDir(job) {
    prepareDirProcess.job = job
    prepareDirProcess.command = ["rm", "-rf", "--", job.destDir]
    prepareDirProcess.running = true
  }

  Process {
    id: prepareDirProcess
    property var job: null
    running: false
    onExited: function(code, signal) {
      var job = prepareDirProcess.job
      prepareDirProcess.job = null
      if (!job) return
      if (code !== 0) {
        _onInstallFailed(job, "could not clear the animation directory")
        return
      }
      _downloadNextFile(job)
    }
  }

  function _downloadNextFile(job) {
    if (job.fileIndex >= job.files.length) {
      _onInstallComplete(job)
      _finishJob(job)
      return
    }
    var file = job.files[job.fileIndex]
    _downloadFile(file.url, file.dest, function() {
      job.fileIndex++
      _downloadNextFile(job)
    }, job)
  }

  function _downloadFile(url, dest, callback, job) {
    downloadProcess.url = url
    downloadProcess.dest = dest
    downloadProcess.callback = callback
    downloadProcess.job = job
    downloadProcess.running = true
  }

  Process {
    id: downloadProcess
    property string url: ""
    property string dest: ""
    property var callback: null
    property var job: null
    // --fail so an HTTP error is an error rather than a saved error page,
    // --proto so a redirect cannot leave https, and the two limits so a
    // hostile or broken source cannot fill the disk or hang the queue.
    command: [
      "curl", "-sL", "--fail",
      "--proto", "=https", "--proto-redir", "=https",
      "--max-filesize", "10485760",
      "--max-time", "30",
      "--create-dirs", "-o", dest, url
    ]
    running: false
    onExited: function(code, signal) {
      var callback = downloadProcess.callback
      var job = downloadProcess.job
      downloadProcess.callback = null
      downloadProcess.job = null
      if (code !== 0) {
        // Previously the callback ran unconditionally, so a failed download
        // counted as a completed install.
        if (job) _onInstallFailed(job, "download failed for " + downloadProcess.url + " (curl exit " + code + ")")
        return
      }
      if (callback) callback()
    }
  }

  function _finishJob(job) {
    root._installJobs.shift()
    root.installingIds = root.installingIds.filter(function(id) { return id !== job.id })
    _processNextJob()
  }

  function _onInstallFailed(job, reason) {
    root.installError = "Install of \"" + job.id + "\" failed: " + reason + "."
    if (root.failedIds.indexOf(job.id) === -1) {
      root.failedIds = root.failedIds.concat([job.id])
    }
    _finishJob(job)
  }

  // Looks up the already-validated local filename for the entry's declared
  // preview, instead of deriving a path from index data a second time.
  function _previewPathFor(job) {
    var declared = job.entry.preview
    if (typeof declared !== "string" || declared === "") return ""
    var wanted = MarketplaceValidation.fileNameFromUrl(declared)
    for (var i = 0; i < job.files.length; i++) {
      if (job.files[i].filename === wanted) return job.files[i].dest
    }
    return ""
  }

  function _onInstallComplete(job) {
    var entry = job.entry
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
      _preview: _previewPathFor(job)
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
      // readOnly, then driven by key events below. An *editable*
      // QQuickTextInput connects the clipboard's dataChanged to
      // q_canPasteChanged, which reads the offered mime data on every
      // clipboard change; Qt's Wayland data-offer reader appends until EOF
      // with a per-read wait and no total byte or time ceiling, so a hostile
      // clipboard client could stall this shell's GUI thread without the user
      // pasting anything. readOnly removes that automatic read while keeping
      // the field's appearance and placeholder.
      readOnly: true
      placeholderText: "Search animations…"
      Layout.preferredWidth: Style.space(160)
      onTextChanged: {
        root.filterText = text
        if (text && root.sortMode !== "alpha") root.sortMode = "alpha"
      }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Backspace) {
          searchField.text = searchField.text.slice(0, -1)
          event.accepted = true
          return
        }
        // Escape is deliberately not handled here: Panel.qml's
        // Shortcut { sequence: "Escape" } closes the panel and resolves before
        // item key handlers, so intercepting it would not work. Backspace
        // clears the filter a character at a time, and clicking away works.
        // One printable character at a time, with a bounded total: nothing
        // here can pull in an arbitrarily large value from elsewhere.
        if (typeof event.text === "string" && event.text.length === 1 && searchField.text.length < 64) {
          var code = event.text.charCodeAt(0)
          if (code >= 0x20 && code !== 0x7f) {
            searchField.text += event.text
            event.accepted = true
          }
        }
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

  // An install we refused, or one that failed partway through.
  Text {
    Layout.fillWidth: true
    visible: root.installError !== ""
    text: root.installError
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  // Entries the index offered that failed validation. Shown rather than
  // hidden silently, so a malformed submission is visible to the user and
  // reportable upstream.
  Text {
    Layout.fillWidth: true
    visible: root.rejectedEntries.length > 0
    text: root.rejectedEntries.length + (root.rejectedEntries.length === 1
      ? " catalog entry was hidden because it failed validation."
      : " catalog entries were hidden because they failed validation.")
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
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
        failed: root.failedIds.indexOf(modelData.id) !== -1
        onInstallClicked: root.installAnimation(modelData)
        onUninstallClicked: root.animationUninstalled(modelData.id)
      }
    }
  }
}
