import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The settings panel's live preview. Quickshell has no web engine, so the
// animation plays in a small borderless Chromium window
// (bin/ascii-screensaver-preview) that this component keeps glued on top of
// `slot`, an empty item in the panel's layout — so it reads as part of the
// panel. Settings reach the page through a JSONP file it polls
// (system/viewer.js); nothing is restarted when a setting changes.
//
// Hyprland knows where windows are, the panel does not (Wayland clients
// never learn their own position), so while the preview runs this polls
// `hyprctl clients -j` and moves the preview whenever the panel or the slot
// has moved.
Item {
  id: root

  property string pluginDir: ""
  property string panelTitle: ""
  property string animationName: ""
  // Whether the preview can be shown at all right now: panel open, an
  // animation page selected, slot laid out.
  property bool available: false
  property Item slot: null
  property var params: ({})

  readonly property bool running: previewProcess.running
  // Shown whenever an animation's page is open; selecting another animation
  // swaps the preview over to it.
  readonly property bool shouldRun: root.available && root.animationName !== "" && !root._halted
    && root.slot !== null && root.slot.width > 0 && root.slot.height > 0

  readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") + "/ascii-screensaver"
  readonly property string stateFile: root.runDir + "/preview-state.js"
  // Chromium derives the window's app_id from the page path (see
  // bin/ascii-screensaver-preview), which is how the window is found again.
  readonly property string appId: "chrome-_" + root.pluginDir.replace(/\//g, "_") + "_system_preview.html-Default"
  // Matches only preview pages' command lines, for cleaning up a window
  // orphaned by a shell crash or plugin reload.
  readonly property string orphanPattern: "/system/preview\\.html\\?anim="

  property string _launchedAnimation: ""
  property bool _stopRequested: false
  property string _lastStateText: ""
  property var _lastPlacement: null
  // Set when the window went away on its own (closed by hand, Chromium
  // failed), so it isn't relaunched in a loop. Cleared by picking another
  // animation or reopening the panel.
  property bool _halted: false

  onShouldRunChanged: root.refresh()
  onAnimationNameChanged: {
    root._halted = false
    root.refresh()
  }
  onAvailableChanged: if (!root.available) root._halted = false
  onParamsChanged: if (previewProcess.running) root.writeState()

  function refresh() {
    if (!root.shouldRun) {
      root.stop()
      return
    }
    if (previewProcess.running || prepareProcess.running) {
      // Switched animations while previewing: stop, and let onRunningChanged
      // relaunch with the new one.
      if (previewProcess.running && root._launchedAnimation !== root.animationName) root.stop()
      return
    }
    root._launchedAnimation = root.animationName
    root._lastPlacement = null
    prepareProcess.running = true
  }

  function stop() {
    if (!previewProcess.running) return
    root._stopRequested = true
    previewProcess.running = false
  }

  function writeState() {
    var text = "window.__previewUpdate(" + JSON.stringify(root.params || ({})) + ");\n"
    if (text === root._lastStateText) return
    root._lastStateText = text
    stateView.setText(text)
  }

  function launch() {
    if (!root.shouldRun) return
    root._lastStateText = ""
    root.writeState()
    previewProcess.command = [
      "bash", root.pluginDir + "/bin/ascii-screensaver-preview",
      root._launchedAnimation, root.stateFile,
      String(Math.round(root.slot.width)), String(Math.round(root.slot.height))
    ]
    previewProcess.running = true
  }

  function place(clientsJson) {
    if (!previewProcess.running || !root.slot) return
    var clients
    try { clients = JSON.parse(clientsJson) } catch (e) { return }

    var panel = null, preview = null
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      if (c.class === "org.quickshell" && c.title === root.panelTitle) panel = c
      else if (c.class === root.appId) preview = c
    }
    if (!panel || !preview) return

    // The slot's position inside the panel window, in the same logical
    // pixels Hyprland uses for window geometry.
    var origin = root.slot.mapToItem(null, 0, 0)
    var x = panel.at[0] + Math.round(origin.x)
    var y = panel.at[1] + Math.round(origin.y)
    var w = Math.round(root.slot.width)
    var h = Math.round(root.slot.height)
    var target = "address:" + preview.address
    var workspace = String(panel.workspace && panel.workspace.name || "")

    // Resize before moving: Hyprland resizes around the window's centre.
    if (preview.size[0] !== w || preview.size[1] !== h)
      Hyprland.dispatch("hl.dsp.window.resize({ x = " + w + ", y = " + h + ", window = \"" + target + "\" })")
    if (preview.at[0] !== x || preview.at[1] !== y || preview.size[0] !== w || preview.size[1] !== h)
      Hyprland.dispatch("hl.dsp.window.move({ x = " + x + ", y = " + y + ", window = \"" + target + "\" })")
    if (workspace !== "" && preview.workspace && preview.workspace.name !== workspace && /^[A-Za-z0-9:_-]+$/.test(workspace))
      Hyprland.dispatch("hl.dsp.window.move({ workspace = \"" + workspace + "\", silent = true, window = \"" + target + "\" })")
    // A floating panel is raised above the preview whenever it's clicked;
    // put the preview back on top. (A tiled panel is always below it.)
    if (panel.floating && panel.focusHistoryID === 0)
      Hyprland.dispatch("hl.dsp.window.alter_zorder({ mode = \"top\", window = \"" + target + "\" })")
  }

  FileView {
    id: stateView
    path: root.stateFile
    preload: false
    watchChanges: false
    printErrors: false
  }

  // Makes sure the runtime directory exists (the state file is written
  // before Chromium starts) and closes any preview window a previous shell
  // left behind.
  Process {
    id: prepareProcess
    running: false
    command: ["sh", "-c", "pkill -f -- \"$1\"; mkdir -p \"$2\"", "sh", root.orphanPattern, root.runDir]
    onExited: root.launch()
  }

  Process {
    id: previewProcess
    running: false
    onRunningChanged: {
      if (running) return
      if (root._stopRequested) {
        // We stopped it (panel closed, animation switched): start again if
        // the preview is still wanted.
        root._stopRequested = false
        Qt.callLater(root.refresh)
      } else {
        // It went away on its own (window closed, Chromium failed): don't
        // relaunch in a loop.
        root._halted = true
      }
    }
  }

  Process {
    id: clientsQuery
    running: false
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      id: clientsCollector
    }
    onExited: root.place(clientsCollector.text)
  }

  Timer {
    interval: 200
    repeat: true
    running: previewProcess.running
    onTriggered: if (!clientsQuery.running) clientsQuery.running = true
  }

  Component.onDestruction: {
    if (previewProcess.running) Quickshell.execDetached(["pkill", "-f", "--", root.orphanPattern])
  }
}
