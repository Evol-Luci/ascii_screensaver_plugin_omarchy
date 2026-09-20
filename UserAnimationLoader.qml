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

  // scan() runs on every config save (Panel.qml's commit() triggers its own
  // config FileView reload, which calls scan() again) and can also be
  // triggered twice back-to-back at startup (both the user and bundled
  // config FileViews auto-load and each call this). Without a re-entrancy
  // guard, two overlapping scans corrupt each other's shared pendingNames/
  // loadIndex/currentName below — manifests silently get skipped or
  // attributed to the wrong directory. A scan requested while one is
  // already running is coalesced into a single follow-up pass instead.
  property bool _scanning: false
  property bool _rescanRequested: false

  function scan() {
    if (!animationsDir) return
    if (root._scanning) {
      root._rescanRequested = true
      return
    }
    root._scanning = true
    root._rescanRequested = false
    pendingNames = []
    loadIndex = 0
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
      root._scanning = false
      root.scanComplete()
      if (root._rescanRequested) root.scan()
      return
    }
    currentName = pendingNames[loadIndex]
    loadIndex++
    // A FileView reused across successive `path` reassignments only ever
    // completed its *first* load in testing here — later reassignments
    // silently never fired onLoaded or onLoadFailed, which is what made
    // multi-animation scans stop after exactly one entry. `cat` via a
    // reused Process (already proven reliable elsewhere in this plugin for
    // sequential downloads/deletes) sidesteps that entirely.
    manifestProcess.manifestName = currentName
    manifestProcess.command = ["cat", root.animationsDir + "/" + currentName + "/manifest.json"]
    manifestProcess.running = true
  }

  Process {
    id: manifestProcess
    property string manifestName: ""
    command: ["cat"]
    running: false
    stdout: StdioCollector { id: manifestCollector }
    onExited: function(code, signal) {
      var name = manifestProcess.manifestName
      try {
        var manifest = JSON.parse(manifestCollector.text)
        if (manifest && manifest.id === name) {
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
            _preview: root.animationsDir + "/" + name + "/" + (manifest.preview || "")
          }
          root.manifestLoaded(name, schemaEntry)
        }
      } catch(e) {
        console.warn("UserAnimationLoader: failed to parse manifest for", name, e)
      }
      root.loadNext()
    }
  }
}
