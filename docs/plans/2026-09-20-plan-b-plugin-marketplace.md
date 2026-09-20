# Plan B: Plugin Install/Uninstall + Marketplace Tab

> **For agentic workers:** Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class install/uninstall support to every animation in the plugin panel, and add a Marketplace tab that fetches, browses, and installs animations from the `ascii-screensaver-animations` monorepo.

**Architecture:** The panel's animation list is already driven by `params.schema.json` (the `animationNames` property). We extend this to also discover animations installed by the user into `~/.config/omarchy/ascii-screensaver/animations/` via their `manifest.json` files. Uninstall removes the config entry entirely. A new `MarketplaceTab.qml` component handles the browse/install surface; it fetches `index.json` from GitHub via `XMLHttpRequest` in QML (Quickshell's `Io` module), caches it in memory for the session, and exposes an Install button per animation.

**Tech Stack:** QML, Quickshell (Io, FileView, Process), JavaScript (ES5-compatible for QML engine)

**Prerequisite:** Plan A must be complete and the `ascii-screensaver-animations` repo must be live with a valid `index.json` before Plan B's marketplace fetch will return real data.

## Global Constraints

- User animations dir: `~/.config/omarchy/ascii-screensaver/animations/` (XDG_CONFIG_HOME aware, same pattern as `ConfigPaths.js`)
- Index URL: `https://raw.githubusercontent.com/Evol-Luci/ascii-screensaver-animations/refs/heads/main/index.json`
- Uninstall = remove config entry only; never delete files
- All new QML components follow the existing style: `import qs.Commons`, `import qs.Ui`, use `Style.*`, `Color.*`
- No new npm/node dependencies — pure QML + JS
- The schema for built-in animations remains `params.schema.json`; user-installed animations use their `manifest.json` `params` array, converted to the same schema shape at load time

---

### Task 1: Extend ConfigPaths.js with user animations dir

**Files:**
- Modify: `ConfigPaths.js`

- [ ] **Step 1: Add `userAnimationsDir()` function**

Open [`ConfigPaths.js`](file:///home/lucievol/Documents/ascii_screensaver_plugin_omarchy/ConfigPaths.js) and add after `bundledConfigPath`:

```js
function userAnimationsDir() {
  var xdgConfigHome = Quickshell.env("XDG_CONFIG_HOME")
  var home = Quickshell.env("HOME")
  var configHome = xdgConfigHome && xdgConfigHome.length > 0 ? xdgConfigHome : (home + "/.config")
  return configHome + "/omarchy/ascii-screensaver/animations"
}
```

Also add `userAnimationsDir` to the `module.exports` block at the bottom:

```js
if (typeof module !== "undefined") {
  module.exports = {
    userConfigPath: userConfigPath,
    bundledConfigPath: bundledConfigPath,
    userAnimationsDir: userAnimationsDir
  }
}
```

- [ ] **Step 2: Verify the existing ConfigPaths tests still pass (if any)**

```bash
node -e "
  var Quickshell = { env: function(k) { return process.env[k] || ''; } };
  var m = require('./ConfigPaths.js');
  console.log(m.userConfigPath());
  console.log(m.userAnimationsDir());
"
# Expected: paths printed without error
```

- [ ] **Step 3: Commit**

```bash
git add ConfigPaths.js
git commit -m "feat: add userAnimationsDir() to ConfigPaths.js"
```

---

### Task 2: Add uninstall logic to Panel.qml

**Files:**
- Modify: `Panel.qml`

Uninstall = remove the animation's entry from `persistedConfig.animations` entirely. The animation disappears from the sidebar list because `animationNames` is derived from `root.schema` (built-ins) merged with `root.userAnimationIds` (user-installed) — after removal the schema entry is also removed from `root.userSchema`.

- [ ] **Step 1: Add `uninstallAnimation(name)` function to Panel.qml's `Item { id: root }` block**

After the existing `setParamValue` function (around line 122), add:

```qml
// Removes the animation's config entry entirely and, for user-installed
// animations, removes it from userSchema so it disappears from the sidebar.
function uninstallAnimation(name) {
  // Remove from config
  var list = root.persistedConfig.animations || []
  var filtered = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].name !== name) filtered.push(list[i])
  }
  root.persistedConfig.animations = filtered
  // Remove from userSchema if it's a user-installed animation
  if (root.userSchema[name] !== undefined) {
    var newUserSchema = Object.assign({}, root.userSchema)
    delete newUserSchema[name]
    root.userSchema = newUserSchema
  }
  // Navigate away if we were looking at this animation
  if (root.selection === name) root.selection = ""
  root.commit()
}
```

- [ ] **Step 2: Add `userSchema` and `installedIds` properties to the root Item**

Near the top of `Panel.qml`, after `property var schema: ({})`, add:

```qml
// Schema entries loaded from user-installed animation manifest.json files.
// Merged with the built-in schema at read time via animationNames.
property var userSchema: ({})

// Combined ordered list of animation names: built-ins first, then user-installed.
readonly property var animationNames: {
  var builtIn = Object.keys(root.schema)
  var user = Object.keys(root.userSchema)
  var all = builtIn.slice()
  for (var i = 0; i < user.length; i++) {
    if (all.indexOf(user[i]) === -1) all.push(user[i])
  }
  return all
}
```

> Note: the existing `readonly property var animationNames: Object.keys(root.schema)` on line 30 must be **replaced** by the above.

- [ ] **Step 3: Add `schemaFor(name)` helper used by AnimationDetail**

After the new `animationNames` property, add:

```qml
// Returns the schema entry for an animation, checking built-in then user.
function schemaFor(name) {
  return root.schema[name] || root.userSchema[name] || ({ title: name, params: ({}) })
}
```

Update all existing references to `root.schema[root.selection]` in Panel.qml to use `root.schemaFor(root.selection)`:
- Line 258: `root.schema[modelData]` → `root.schemaFor(modelData)`
- Line 259: `root.schema[modelData].title` → `root.schemaFor(modelData).title`
- Line 370: `root.schema[root.selection]` → `root.schemaFor(root.selection)`

- [ ] **Step 4: Commit**

```bash
git add Panel.qml
git commit -m "feat: add uninstallAnimation() and userSchema support to Panel.qml"
```

---

### Task 3: Add user animation discovery (FileView scanning)

**Files:**
- Modify: `Panel.qml`
- Create: `UserAnimationLoader.qml`

Quickshell's `FileView` reads a single file. To discover user animations we use a `Process` to list the user animations dir, then load each `manifest.json` found.

- [ ] **Step 1: Create `UserAnimationLoader.qml`**

This component scans the user animations dir and emits `manifestLoaded(string name, var schemaEntry)` for each valid manifest found.

```qml
import QtQuick
import Quickshell
import Quickshell.Io

// Scans the user animations directory and emits manifestLoaded for each
// valid animation manifest found.
Item {
  id: root

  property string animationsDir: ""

  signal manifestLoaded(string name, var schemaEntry)
  signal scanComplete()

  function scan() {
    if (!animationsDir) return
    listProcess.running = true
  }

  // Step 1: list subdirectory names
  Process {
    id: listProcess
    command: ["bash", "-c", "ls -1 '" + root.animationsDir + "' 2>/dev/null || true"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var name = line.trim()
        if (name) pendingNames.push(name)
      }
    }
    onExited: function(code, signal) {
      loadNext()
    }
  }

  property var pendingNames: []
  property int loadIndex: 0
  property string currentName: ""

  function loadNext() {
    if (loadIndex >= pendingNames.length) {
      root.scanComplete()
      return
    }
    currentName = pendingNames[loadIndex]
    loadIndex++
    manifestView.path = root.animationsDir + "/" + currentName + "/manifest.json"
    manifestView.reload()
  }

  FileView {
    id: manifestView
    path: ""
    watchChanges: false
    printErrors: false
    onLoaded: {
      try {
        var manifest = JSON.parse(text())
        if (manifest && manifest.id === root.currentName) {
          // Convert manifest params array to schema params object
          var params = {}
          var paramsArr = manifest.params || []
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
            title: manifest.name,
            hint: manifest.description || "",
            params: params,
            _source: "user",
            _manifestVersion: manifest.version || "1.0.0",
            _author: manifest.author || "",
            _preview: root.animationsDir + "/" + root.currentName + "/" + (manifest.preview || "")
          }
          root.manifestLoaded(root.currentName, schemaEntry)
        }
      } catch(e) {
        console.warn("UserAnimationLoader: failed to parse manifest for", root.currentName, e)
      }
      root.loadNext()
    }
    onLoadFailed: function(error) {
      // Not a valid animation folder, skip silently
      root.loadNext()
    }
  }
}
```

- [ ] **Step 2: Add `UserAnimationLoader` to Panel.qml**

After the existing `FileView` blocks (around line 174), add:

```qml
UserAnimationLoader {
  id: userAnimLoader
  animationsDir: ConfigPaths.userAnimationsDir()
  onManifestLoaded: function(name, schemaEntry) {
    var updated = Object.assign({}, root.userSchema)
    updated[name] = schemaEntry
    root.userSchema = updated
  }
  onScanComplete: {
    // Scan done — userSchema is fully populated
  }
}
```

Trigger the scan when config is loaded. In `parsePersistedConfig`, after `root.configLoaded = true`, add:

```qml
userAnimLoader.scan()
```

- [ ] **Step 3: Commit**

```bash
git add UserAnimationLoader.qml Panel.qml
git commit -m "feat: scan and load user-installed animation manifests"
```

---

### Task 4: Add Uninstall button to AnimationDetail.qml

**Files:**
- Modify: `AnimationDetail.qml`

- [ ] **Step 1: Add `isUserInstalled` property and `uninstallRequested` signal**

At the top of `AnimationDetail.qml`, after existing properties:

```qml
property bool isUserInstalled: false
signal uninstallRequested()
```

- [ ] **Step 2: Add Uninstall button below the existing Preview button row**

After the closing `}` of the existing `RowLayout` with the Preview button (around line 64), add:

```qml
RowLayout {
  Layout.fillWidth: true
  spacing: Style.spacing.lg
  visible: true  // shown for ALL animations

  Button {
    text: "Uninstall animation"
    onClicked: root.uninstallRequested()
  }

  Text {
    Layout.fillWidth: true
    text: root.isUserInstalled
      ? "Removes this animation from your panel and rotation. Files stay on disk."
      : "Removes this animation from your panel and rotation. Re-install it from the Marketplace tab."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
```

- [ ] **Step 3: Wire up `uninstallRequested` in Panel.qml**

In Panel.qml, find the `AnimationDetail` block (around line 363) and add:

```qml
isUserInstalled: root.userSchema[root.selection] !== undefined
onUninstallRequested: root.uninstallAnimation(root.selection)
```

- [ ] **Step 4: Commit**

```bash
git add AnimationDetail.qml Panel.qml
git commit -m "feat: add Uninstall button to AnimationDetail"
```

---

### Task 5: Create MarketplaceTab.qml

**Files:**
- Create: `MarketplaceTab.qml`

This is the main Marketplace tab component. It fetches `index.json`, displays animation cards with Install/Uninstall buttons, and exposes a Refresh button.

- [ ] **Step 1: Create `MarketplaceTab.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Marketplace tab: browses and installs animations from the community repo.
Item {
  id: root

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
  // Downloads all files listed in the marketplace entry to userAnimationsDir.
  property var _installQueue: []
  property int _installQueueIndex: 0
  property var _installTarget: null  // the marketplace entry being installed

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
    // Convert marketplace params array to schema entry
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
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // Toolbar
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: Style.spacing.lg
      Layout.leftMargin: Style.spacing.xl
      Layout.rightMargin: Style.spacing.xl
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
      Layout.leftMargin: Style.spacing.xl
      Layout.rightMargin: Style.spacing.xl
      visible: root.fetchStatus === "error"
      text: root.fetchError
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }

    // Animation cards
    ScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentWidth: availableWidth
      clip: true
      visible: root.fetchStatus === "ready"

      Flow {
        width: parent.width
        padding: Style.spacing.xl
        spacing: Style.spacing.md

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

    Item {
      Layout.fillHeight: true
      visible: root.fetchStatus !== "ready"
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add MarketplaceTab.qml
git commit -m "feat: add MarketplaceTab.qml with fetch, install, and search"
```

---

### Task 6: Create MarketplaceCard.qml

**Files:**
- Create: `MarketplaceCard.qml`

A single animation card shown in the marketplace grid.

- [ ] **Step 1: Create `MarketplaceCard.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A single card in the Marketplace tab for one available animation.
Rectangle {
  id: root

  property var entry: ({})
  property bool installed: false

  signal installClicked()
  signal uninstallClicked()

  width: Style.space(260)
  height: cardColumn.implicitHeight + Style.spacing.lg * 2
  color: Color.surface
  radius: Style.radius.md

  ColumnLayout {
    id: cardColumn
    anchors {
      top: parent.top; left: parent.left; right: parent.right
      margins: Style.spacing.lg
    }
    spacing: Style.spacing.sm

    // Preview image
    Image {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(120)
      source: root.entry.preview || ""
      fillMode: Image.PreserveAspectCrop
      clip: true
      visible: root.entry.preview !== ""

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Color.muted
        border.width: Style.normalBorderWidth
        radius: Style.radius.sm
        opacity: 0.3
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.entry.name || root.entry.id || ""
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.entry.author || ""
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.entry.description || ""
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight
    }

    Button {
      Layout.fillWidth: true
      text: root.installed ? "Uninstall" : "Install"
      onClicked: root.installed ? root.uninstallClicked() : root.installClicked()
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add MarketplaceCard.qml
git commit -m "feat: add MarketplaceCard.qml"
```

---

### Task 7: Wire the Marketplace tab into Panel.qml

**Files:**
- Modify: `Panel.qml`

Add the Marketplace tab to the sidebar and detail area, and wire up `animationInstalled` / `animationUninstalled` signals.

- [ ] **Step 1: Add a "Marketplace" entry to the sidebar**

In Panel.qml, in the sidebar `ColumnLayout`, after the `PanelSeparator` that follows the General row (around line 242), add a second separator and a Marketplace row before the Animations section header:

```qml
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
```

- [ ] **Step 2: Add `MarketplaceTab` to the detail area**

In the detail area `ColumnLayout`, after the closing `}` of `AnimationDetail` (around line 379), add:

```qml
MarketplaceTab {
  Layout.fillWidth: true
  Layout.fillHeight: true
  visible: root.selection === "marketplace"
  installedIds: root.animationNames
  userAnimationsDir: ConfigPaths.userAnimationsDir()

  onAnimationInstalled: function(animId, schemaEntry) {
    // Add to userSchema so it appears in the sidebar
    var updated = Object.assign({}, root.userSchema)
    updated[animId] = schemaEntry
    root.userSchema = updated
    // Add config entry with defaults
    root.ensureEntry(animId)
    root.commit()
  }
  onAnimationUninstalled: function(animId) {
    root.uninstallAnimation(animId)
  }
}
```

- [ ] **Step 3: Handle `visible` for existing detail panes**

Ensure `WelcomePane`, `GeneralDetail`, and `AnimationDetail` all exclude `"marketplace"` from their `visible` conditions. Update:

- `WelcomePane`: `visible: root.selection === ""`  ✅ (already correct)
- `GeneralDetail`: `visible: root.selection === "general"` ✅ (already correct)
- `AnimationDetail`: change `visible: root.selection !== "" && root.selection !== "general"` to:

```qml
visible: root.selection !== "" && root.selection !== "general" && root.selection !== "marketplace"
```

- [ ] **Step 4: Commit**

```bash
git add Panel.qml
git commit -m "feat: wire Marketplace tab into panel sidebar and detail area"
```

---

### Task 8: Manual verification

No automated tests exist for QML in this project. Verify manually:

- [ ] **Step 1: Launch Omarchy with the updated plugin**

Open the ASCII Screensaver settings panel.

- [ ] **Step 2: Verify sidebar shows "Marketplace" entry**

Expected: Marketplace row appears in the sidebar between General and the Animations section.

- [ ] **Step 3: Click Marketplace — verify index.json is fetched**

Expected: After a moment, animation cards appear. All 30 built-in animations show "Uninstall" (they're already installed). Community animations show "Install".

- [ ] **Step 4: Click Refresh — verify re-fetch works**

Expected: Cards disappear briefly then reappear.

- [ ] **Step 5: Uninstall one built-in animation (e.g. "moon")**

Expected: "moon" disappears from the Animations sidebar list. It still shows in the Marketplace as "Not installed" / Install button.

- [ ] **Step 6: Re-install "moon" from Marketplace**

Expected: "moon" reappears in the Animations sidebar list with default params.

- [ ] **Step 7: Verify screensaver.config.json after uninstall/reinstall**

```bash
cat ~/.config/omarchy/ascii-screensaver/screensaver-config.json | python3 -m json.tool | grep moon
# After uninstall: no output
# After reinstall: shows the moon entry with enabled: true, weight: 1
```

- [ ] **Step 8: Commit any fixes found during verification**

- [ ] **Step 9: Final commit**

```bash
git add -A
git commit -m "feat: animations marketplace and install/uninstall system complete"
```

---

Plan B is complete when: every animation has an Uninstall button, the Marketplace tab fetches and displays the community index, Install/Uninstall work end-to-end, and the config file correctly reflects the install state.
