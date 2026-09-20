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
      root.loadNext()
    }
  }
}
