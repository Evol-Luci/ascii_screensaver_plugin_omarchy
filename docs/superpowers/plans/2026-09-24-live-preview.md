# Live Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a hot-reloading floating Live Preview window for the ascii-screensaver Omarchy panel.

**Architecture:** A modified Chromium launch script spawns a floating, pinned preview window. The QML UI writes parameter changes to a JSON file in `/tmp`, which `viewer.html` polls repeatedly to hot-reload its inner iframe.

**Tech Stack:** Bash, QML, JavaScript, HTML, Hyprland.

## Global Constraints
- Do not modify the fullscreen screensaver behavior.
- Ensure the preview window is automatically closed when the panel is closed or the toggle is switched off.
- File polling mechanism must not impact main screensaver performance (only active when `preview_mode=1`).

---

### Task 1: Update Launcher for Preview Mode

**Files:**
- Modify: `bin/ascii-screensaver-cmd`

**Interfaces:**
- Consumes: Environment variable `PREVIEW=1`.
- Produces: A Chromium window with `--class="ascii-screensaver-preview"`, `--window-size=600,450`, `--disable-web-security`, and no `--start-fullscreen`. Also outputs a Hyprland rule to make it float and pin.

- [ ] **Step 1: Write implementation for preview mode**
Update `bin/ascii-screensaver-cmd` to check for `PREVIEW=1`. If set, use specific Chromium flags and execute Hyprland floating rules. Add `--disable-web-security` to allow local file fetching.

```bash
# In bin/ascii-screensaver-cmd, right before launching chromium:
if [[ "${PREVIEW:-}" == "1" ]]; then
  SCREENSAVER_CLASS="ascii-screensaver-preview"
  CHROMIUM_FLAGS="--window-size=600,450 --disable-web-security"
  hyprctl keyword windowrulev2 "float,class:^(ascii-screensaver-preview)$" &>/dev/null
  hyprctl keyword windowrulev2 "pin,class:^(ascii-screensaver-preview)$" &>/dev/null
  hyprctl keyword windowrulev2 "center,class:^(ascii-screensaver-preview)$" &>/dev/null
else
  CHROMIUM_FLAGS="--start-fullscreen"
fi

# Then pass $CHROMIUM_FLAGS to the chromium command instead of hardcoded --start-fullscreen.
```

- [ ] **Step 2: Modify the URL generation for preview mode**
If `PREVIEW=1`, append `preview_mode=1` to the `HTML_URL`.

```bash
if [[ "${PREVIEW:-}" == "1" ]]; then
  HTML_URL="${HTML_URL}&preview_mode=1"
fi
```

- [ ] **Step 3: Commit**
```bash
git add bin/ascii-screensaver-cmd
git commit -m "feat: add PREVIEW mode support to launch script"
```

---

### Task 2: Hot-Reload Polling in viewer.html

**Files:**
- Modify: `system/viewer.html`

**Interfaces:**
- Consumes: URL parameter `preview_mode=1`. File `/tmp/ascii-screensaver-preview.json`.
- Produces: Dynamically updates the `iframe.src`.

- [ ] **Step 1: Write polling loop in viewer.html**
In the `<script>` tag of `viewer.html`, parse the URL. If `preview_mode` is set, set up a `setInterval`.

```javascript
// Near the top of the script in system/viewer.html
const isPreviewMode = params.get('preview_mode') === '1';
let currentPreviewParams = "";

if (isPreviewMode) {
    setInterval(async () => {
        try {
            const res = await fetch('file:///tmp/ascii-screensaver-preview.json', { cache: 'no-store' });
            if (res.ok) {
                const data = await res.json();
                const newParams = new URLSearchParams(data).toString();
                if (newParams !== currentPreviewParams) {
                    currentPreviewParams = newParams;
                    // Hot reload the iframe src
                    const iframe = document.getElementById('anim-frame');
                    if (iframe) {
                        iframe.src = `file://${animPath}?${newParams}`;
                    }
                }
            }
        } catch (e) {
            // Silently ignore fetch errors
        }
    }, 300);
}
```

- [ ] **Step 2: Commit**
```bash
git add system/viewer.html
git commit -m "feat: add hot-reload polling for preview mode"
```

---

### Task 3: QML Integration

**Files:**
- Modify: `AnimationDetail.qml`

**Interfaces:**
- Consumes: User interaction on sliders/dropdowns.
- Produces: Writes JSON to `/tmp/ascii-screensaver-preview.json` and spawns `ascii-screensaver-cmd` via Quickshell `Process`.

- [ ] **Step 1: Write file output logic in AnimationDetail.qml**
Add a `Process` component to run `echo <json> > /tmp/ascii-screensaver-preview.json` whenever parameters change.

```qml
// In AnimationDetail.qml, add an IO process to write state:
Process {
    id: previewStateWriter
    running: false
}

function updatePreviewState() {
    if (!previewProcess.running) return;
    
    // Gather all current param values
    var state = {};
    for (var i = 0; i < root.paramNames.length; i++) {
        var key = root.paramNames[i];
        state[key] = root.entry.params && root.entry.params[key] !== undefined 
            ? root.entry.params[key] 
            : root.animationSchema.params[key].defaultValue;
    }
    
    // Ensure we also send standard preview mode parameters if needed
    
    var jsonStr = JSON.stringify(state);
    previewStateWriter.command = ["bash", "-c", "echo '" + jsonStr + "' > /tmp/ascii-screensaver-preview.json"];
    previewStateWriter.running = true;
}
```

- [ ] **Step 2: Replace Preview Button and manage process**
Change the existing Preview button to a Toggle button, and bind it to a `Process` that launches `PREVIEW=1` mode. Ensure the process dies when the panel closes or component is destroyed.

```qml
// Modify the Preview button area in AnimationDetail.qml:
Process {
    id: previewProcess
    running: false
    command: [
        "env",
        "PREVIEW=1",
        "ANIMATION=" + root.animationName,
        "bash", root.pluginDir + "/bin/ascii-screensaver-cmd"
    ]
}

Component.onDestruction: {
    if (previewProcess.running) {
        previewProcess.running = false;
        // Ensure cleanup just in case
        var cleanup = Qt.createQmlObject('import Quickshell.Io; Process { running: true; command: ["pkill", "-f", "ascii-screensaver-preview"] }', root);
    }
}

// In the Button for preview:
Button {
    text: previewProcess.running ? "Stop Live Preview" : "Start Live Preview"
    onClicked: {
        if (previewProcess.running) {
            previewProcess.running = false;
        } else {
            updatePreviewState(); // Write initial state
            previewProcess.running = true;
        }
    }
}

// In onParamEdited (or wherever params change):
onParamEdited: function(paramName, value) {
    // existing param update logic...
    updatePreviewState();
}
```

- [ ] **Step 3: Commit**
```bash
git add AnimationDetail.qml
git commit -m "feat: add QML Live Preview toggle and state writing"
```
