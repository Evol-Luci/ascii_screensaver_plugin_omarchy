# Native Settings Panel — Handoff Packet (Private → Public Repo)

**Purpose of this document:** everything learned building the native QML
settings panel in the **private** repo (`ascii-screensaver-git` /
`/home/lucievol/Documents/ascii_screensaver`), so the same work can be
built in the **public** repo (`ascii_screensaver_plugin_omarchy`) instead.
Paste this file into the public repo's working directory and pick up from
here — do not repeat the research already captured below.

**Why this handoff exists:** the private-repo build was done first by
mistake (should have been done directly in public). Per the user: stop
private-repo panel work now; the live plugin install has been repointed
back to the public repo (confirmed clean, `kinds: ["service"]`, `idle
status.screensaver == 150`, no panel yet). All panel work continues in
the public repo from here.

**Related docs already committed in the private repo** (for reference,
not required to have on hand):
- `docs/superpowers/specs/2026-09-12-native-settings-panel-design.md` — the design spec
- `docs/superpowers/plans/2026-09-12-native-settings-panel.md` — the implementation plan (Tasks 1–9)

---

## 1. Status summary

| Task (from the plan) | Status | Notes |
|---|---|---|
| 1. `ConfigPaths.js` | ✅ Done, verified | No changes needed for public repo |
| 2. `params.schema.json` generation | ✅ Done in private (includes `plasma`) | **Public repo has no `legacy/` to generate from — see §5** |
| 3. `Service.qml` delay override | ✅ Done, qmllint clean | **Live behavior only partially verified — see §4, unresolved bug** |
| 4. `manifest.json` panel kind | ✅ Done, verified | Copy as-is |
| 5. `Settings.qml` root + top section | ✅ Done, qmllint clean, **rendered correctly live** (screenshot-confirmed) | |
| 6. `Settings.qml` per-animation renderer | ✅ Done, qmllint clean | Not interactively slider-tested (only static render confirmed) |
| 7. Retire legacy UI + docs | ✅ Done in private | **N/A for public — already retired during the earlier plasma-removal work** |
| 8. Full verification | ⚠️ Partially done — panel opens/renders correctly; delay-override live behavior found buggy, root cause NOT fully resolved | See §4 |
| 9. Apply to public repo | ❌ Not started (this handoff replaces it — do it directly in public now, not by copying from private) | |

**Bottom line:** the panel's static structure (manifest, schema-driven
rendering, UI layout) is solid and confirmed working. The **delay-override
live-reload behavior has a real, unresolved bug** — build it fresh in the
public repo with the fix attempt described in §4 as a starting hypothesis,
not as confirmed-working code, and verify it properly before trusting it.

---

## 2. Design decisions (already made, don't re-litigate)

From the design spec, confirmed with the user:

1. **Full parity**: one generic, schema-driven renderer covering every
   animation/param — not a cut-down MVP.
2. **Entry point**: `kinds: ["service", "panel"]`. No `bar-widget` kind —
   menu-only access via `omarchy-shell shell summon
   io.github.evol-luci.ascii-screensaver '{}'`. It will **not** appear in
   `barkeep` (which only manages bar widgets) — this was explicitly chosen
   over adding a bar icon.
3. **Screensaver/lock delay**: a **plugin-owned override** stored in
   `screensaver-config.json` (`screensaverDelaySeconds`,
   `lockDelaySeconds`), preferred by `Service.qml` over the shared
   `idleConfig` when present. **Confirmed finding: there is no sanctioned
   write path for a third-party plugin to the shared `shell.json`
   `idle.*` keys** — traced `createScopedPluginShell()` in
   `/usr/share/omarchy/shell/shell.qml`: third-party plugins get
   `idleConfig` read-only; the only settings-write call
   (`_updateSettings`/`updateEntryInline`) is hard-scoped to a plugin's own
   `plugins[]`/bar-layout entry and cannot touch `config.idle`. Do not
   attempt a `shell.json` write — it doesn't exist as an option.
4. **Legacy UI**: fully retired, no embedded live-preview iframe. A
   "Preview Now" button runs the real launcher full-screen instead.
5. **New default animation** (from the earlier plasma-removal work,
   already true in the public repo): `terrarium`, not `plasma`.

---

## 3. Verified working reference patterns (re-use these, don't re-derive)

These were confirmed by reading real, currently-installed, working plugin
QML on this machine — not guessed from documentation alone:

- **Standalone (non-bar-widget) panel contract**, verified against
  `~/.config/omarchy/plugins/davedes.mouse-keybind-settings/KeybindsPanel.qml`
  and the first-party `omarchy.dev-gallery`
  (`/usr/share/omarchy/shell/plugins/dev-gallery/GalleryPanel.qml`,
  `manifest.json`: `kinds: ["panel"]` alone, no bar-widget):
  ```qml
  Item {
    id: root
    property var shell: null       // auto-injected by the shell loader
    property var manifest: null    // auto-injected by the shell loader
    property bool closingFromHost: false
    readonly property bool opened: window.visible

    function open(payloadJson) { closingFromHost = false; window.visible = true }
    function close() { closingFromHost = true; window.visible = false }

    FloatingWindow {
      id: window
      visible: false
      onVisibleChanged: {
        if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
          root.shell.hide((root.manifest && root.manifest.id) || "your.plugin.id")
        }
      }
    }
  }
  ```
  `FloatingWindow` (from `import Quickshell`) is a real desktop window
  (title bar, resizable) — the right fit for a settings dialog. This is
  **not** the same as `PanelWindow`+`WlrLayershell` (used by anchored
  overlay surfaces like OSD) — don't conflate the two.

- **First-party UI kit to build the form from** (`$OMARCHY_PATH/shell/Ui/`,
  `import qs.Ui` + `import qs.Commons`):
  - `PanelSlider` — `value`/`minimum`/`maximum`/`step`/`integer`
    (boolean), signals `moved(value)` / `released(value)`.
  - `Dropdown` — `label`/`value`/`options` (string array or
    `{value,label}` objects), signal `changed(string value)`.
  - `Toggle` — `label`/`description`/`checked`, signal `clicked()`.
  - `PanelSectionHeader`, `PanelSeparator` — plain visual dividers.
  - Theme via `qs.Commons.Style` (`Style.space(n)`, `Style.font.*`) and
    `Color.background`/`Color.foreground`.

- **Third-party plugin settings persistence convention**: seen in
  `davedes.mouse-keybind-settings` — plugins store their own state as
  plain JSON files, read/written directly via `FileView`, with no special
  shell API involved. E.g. `settingsPath: Quickshell.env("HOME") +
  "/.local/state/omarchy/settings/<plugin-id>.json"`. For us, the
  existing `screensaver-config.json` (already the single source of truth
  for all animation params) is the right file to keep using — don't
  invent a second config file.

---

## 4. The unresolved bug — delay override doesn't reliably live-reload

**Symptom:** `Service.qml`'s `screensaverTimeoutSeconds` reads
`ourConfig.screensaverDelaySeconds` from a `FileView` watching
`screensaver-config.json`. The **very first** external edit to that file
after a fresh plugin load/reinstall is picked up correctly. **Every
subsequent edit is silently ignored** — `omarchy-shell idle status`
keeps reporting whatever the first-loaded value was, no matter how many
more times the file is changed (confirmed with three sequential edits: 33
→ 99 → cleared entirely; all three were ignored, status stayed frozen at
the first value).

**What was tried and did NOT fix it:** adding an explicit
`onFileChanged: reload()` handler to both `FileView`s (`ourConfigFile`
and `bundledConfigFile` in `Service.qml`; `userConfigFile` and
`bundledConfigFile` in `Settings.qml`), based on this being the documented
difference between our code and the shell's own known-working pattern:

```qml
// shell.qml's own config FileViews (confirmed working in production):
FileView {
  path: shell.userConfigPath
  watchChanges: true
  onLoaded: shell.applyShellConfig()
  onLoadFailed: function(error) { shell.applyShellConfig() }
  onFileChanged: reload()   // <-- this line is what our code was missing
}
```

This looked like a strong, well-evidenced hypothesis (`onLoaded` fires
once on initial load; `watchChanges: true` alone only arms the
file-system watch; `onFileChanged` is the signal that actually fires on
each subsequent external change, and needs an explicit `.reload()` call
to make the `FileView` re-read and re-fire `onLoaded`). It was added to
both files, `qmllint` passed, `check-upstream-drift`'s threshold was
bumped from 46→48 to match, committed
(`98ca19c fix(panel): add missing onFileChanged: reload() to config FileViews`
in the private repo), and the plugin was fully reinstalled from that
exact commit. **The bug persisted identically after all of that** — three
sequential external file edits, still only the first was ever picked up.

**What this means:** the root cause is still unknown. Do not assume the
`onFileChanged: reload()` addition is a real fix — treat it as an
unverified first attempt. Two concrete next steps for whoever picks this
up in the public repo, in order of how cheap they are to try:

1. **Test with an actually-simpler repro first**, isolated from all the
   rest of `Service.qml`'s complexity: a throwaway single-`FileView` QML
   file (`qmlscene`/`qml6`, or a minimal `quickshell -p` config) that just
   logs `text()` on every `onLoaded`, watching a scratch JSON file, with
   `onFileChanged: reload()`. Edit the scratch file 3+ times externally
   and confirm whether `onLoaded` actually fires each time. If it doesn't
   even in this minimal repro, this is a genuine Quickshell `FileView`
   behavior/version issue (worth checking Quickshell's version — `quickshell
   --version` — and its actual `FileView` C++ source, which the previous
   session was blocked from investigating mid-flow; this remains the most
   promising unexplored lead).
2. **Check whether the *shell's own* rescan/reload cycle is the thing
   that was really making the "first edit" appear to work**, rather than
   the `FileView` watch itself. In every test so far, the successful
   "first edit" happened either right after a fresh `omarchy plugin
   add`/`rescanPlugins`, or right after some other disruptive reload. It's
   possible `onLoaded` is firing due to the *component being freshly
   instantiated* around that reload, coincidentally reading whatever was
   on disk *at that moment*, and the `watchChanges`/`onFileChanged`
   mechanism never actually fires at all in this environment. If so, the
   real fix might need `Quickshell.FileView`'s `printErrors: true`
   temporarily (to surface any watch-setup errors currently suppressed by
   `printErrors: false`), or a completely different mechanism (e.g. a
   `Timer`-based poll of `text()`/an md5 of the file content, as a
   fallback if the native file-watch genuinely isn't working in this
   Quickshell version/environment).

**Test methodology note, so this doesn't waste time again:** test file
edits against `~/.config/ascii-screensaver/screensaver-config.json`
directly (confirmed to be the actual watched path — it pre-existed and
takes precedence per `ConfigPaths.userConfigPath()`), not the plugin's
own bundled copy or a separate dev-repo copy — editing the wrong file
was a real mistake made mid-session and cost real debugging time. After
any config or code change, a full `omarchy plugin remove` +
`omarchy plugin add "file://<repo>" --enable --yes` +
`omarchy-shell shell rescanPlugins` cycle is needed to pick up **code**
changes (committed only — uncommitted working-tree edits are NOT picked
up by `git clone`-based `plugin add`). `omarchy-shell` reports "not
responding" for several seconds during a rescan — this is normal
transient IPC unavailability, not a crash (verify via `quickshell list -p
"$OMARCHY_PATH/shell" --any-display`, which shows the same PID/uptime
continuing, and `coredumpctl list` showing nothing new).

---

## 5. `params.schema.json` for the public repo — different generation approach needed

The private-repo generation script (Task 2 of the plan) extracts the
`DEFINITIONS` object from `legacy/screensaver-config-ui.html`. **The
public repo has no `legacy/` directory at all** — it was already deleted
during the earlier plasma-removal work, before this panel work began. Two
options, in order of preference:

1. **Regenerate the conversion script's source data by hand from
   `screensaver-config.json`'s existing `params` values**, since every
   animation's current param *values* already live there — only the
   *range/type/options metadata* (min/max/step/select-options) is missing
   from that file and would need to be authored fresh per animation. This
   is real, non-trivial authoring work (~29 animations), not a mechanical
   extraction.
2. **Copy the already-generated `params.schema.json` from the private
   repo** (`/home/lucievol/Documents/ascii_screensaver/params.schema.json`,
   committed at `2cb0446 feat(panel): generate params.schema.json from
   legacy DEFINITIONS` — 30 animations, includes `plasma`), then strip the
   `plasma` entry:
   ```bash
   jq 'del(.plasma)' params.schema.json > params.schema.json.tmp
   mv params.schema.json.tmp params.schema.json
   jq -e '. | length == 29' params.schema.json   # expect true
   jq -e 'has("plasma") | not' params.schema.json  # expect true
   ```
   This is exactly what the original plan's Task 9 already specified —
   it remains the right approach, just now happening as the *primary* path
   rather than a "port to public" afterthought. **Recommended**: option 2,
   since the private repo's schema is already generated, verified
   (`qmllint`, `omarchy plugin validate`, and confirmed rendering live —
   see the screenshot description in §6), and this sidesteps re-authoring
   ~29 animations' param metadata by hand.

---

## 6. Live verification already done (private repo) — what's confirmed good

- `omarchy plugin validate` and `qmllint` (both `Service.qml` and
  `Settings.qml`) pass cleanly.
- Summoning the panel (`omarchy-shell shell summon
  io.github.evol-luci.ascii-screensaver '{}'`) opens a real window titled
  "ASCII Screensaver Settings" — confirmed via `hyprctl clients -j` and a
  screenshot. The screenshot showed, correctly: an Enabled toggle, a Mode
  dropdown (`random`), a "Timing" section with two sliders, a "Preview
  Now" button, then per-animation sections each with an Enabled toggle, a
  weight slider (correctly visible only in random mode), and the
  animation's own params as sliders/dropdowns — with the dropdowns
  correctly showing the animation's *actual current configured values*
  (e.g. plasma's `patternKey: lavalamp`, `paletteKey: sunset`,
  `charsetKey: waves`, matching `screensaver-config.json` exactly).
- No crash: `coredumpctl list` showed nothing new after opening/closing
  the panel repeatedly.
- **Not yet tested**: actually dragging a slider / picking a dropdown
  option *in the live GUI* and confirming it persists via `saveConfig()`
  — all persistence testing so far was done by editing the JSON file
  directly to simulate what `saveConfig()` would write, not by
  interacting with the real widgets. This should be tested for real in
  the public-repo build (mouse/keyboard-driven, or via
  `mcp__claude-in-chrome`-style automation is not applicable here since
  it's a native Wayland window, not a browser — manual interaction or
  `hyprctl` + `ydotool`/similar would be needed for automated UI testing).
- One cosmetic gap noticed, not a bug: `PanelSlider` in this kit has no
  built-in numeric readout — the current value isn't shown as text next
  to the slider. Worth a small polish pass (a `Text` label bound to the
  slider's `value`) if there's time; not required for correctness.

---

## 7. Exact file contents (private repo, as of the last commit before this handoff)

Reproduced in full below so they can be copied directly into the public
repo if git access to the private repo isn't available. **`Service.qml`
and `Settings.qml` both carry the unverified `onFileChanged: reload()`
fix from §4 — treat as a starting point, not confirmed-correct.**

### `ConfigPaths.js` (23 lines, unmodified from private repo — safe to copy as-is)

```javascript
// Shared "user config overrides bundled config" path resolution, matching
// the same precedence the bash scripts (bin/ascii-screensaver-launch,
// bin/ascii-screensaver-cmd) already implement:
//   ${XDG_CONFIG_HOME:-$HOME/.config}/ascii-screensaver/screensaver-config.json
// takes precedence over <pluginDir>/screensaver-config.json.

function userConfigPath() {
  var xdgConfigHome = Quickshell.env("XDG_CONFIG_HOME")
  var home = Quickshell.env("HOME")
  var configHome = xdgConfigHome && xdgConfigHome.length > 0 ? xdgConfigHome : (home + "/.config")
  return configHome + "/ascii-screensaver/screensaver-config.json"
}

function bundledConfigPath(pluginDir) {
  return pluginDir + "/screensaver-config.json"
}

if (typeof module !== "undefined") {
  module.exports = {
    userConfigPath: userConfigPath,
    bundledConfigPath: bundledConfigPath
  }
}
```

### `manifest.json` diff to apply (public repo currently has `kinds: ["service"]` only)

```diff
-  "kinds": ["service"],
-  "entryPoints": { "service": "Service.qml" },
+  "kinds": ["service", "panel"],
+  "entryPoints": { "service": "Service.qml", "panel": "Settings.qml" },
```

### `bin/check-upstream-drift` — only the threshold line changed from the public repo's current state

```bash
EXPECTED_CHANGED_LINES=48
```
(Public repo's current value is whatever it was left at after the
Quattro migration work — check before assuming 48 is right; recompute via
`diff -u /usr/share/omarchy/shell/plugins/services/idle/Service.qml
Service.qml | grep -cE '^[+-][^+-]'` after applying the `Service.qml`
change below, exactly as Task 3 Step 5 of the plan describes.)

### `Service.qml` — full file (406 lines; diff from the public repo's current `Service.qml` is: new `ConfigPaths` import, the `screensaverTimeoutSeconds`/`lockTimeoutSeconds` property bodies, the new `ourConfig` property + `parseOurConfig` function, and the two new `FileView`s — everything else, including `launchScreensaver()`'s existing one-line divergence from upstream, is unchanged)

```qml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "IdleModel.js" as IdleModel
import "ConfigPaths.js" as ConfigPaths

Item {
  id: root

  // Injected by omarchy-shell (the first-party service loader).
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stayAwakeStateDir: home + "/.local/state/omarchy/indicators"
  readonly property string stayAwakeStatePath: stayAwakeStateDir + "/stay-awake"
  readonly property int defaultScreensaverSeconds: 150
  readonly property int defaultLockSeconds: 300
  readonly property var idleConfig: shell && shell.shellConfig && shell.shellConfig.idle
    ? shell.shellConfig.idle : (shell && shell.idleConfig ? shell.idleConfig : ({}))
  // Plugin-owned override, set from the native settings panel and stored
  // in our own screensaver-config.json — preferred over the shared
  // idleConfig when present, since third-party plugins have no sanctioned
  // write path to shell.json's idle.* keys (see the design spec, §2).
  readonly property int screensaverTimeoutSeconds: secondsFromConfig(
    ourConfig.screensaverDelaySeconds !== undefined ? ourConfig.screensaverDelaySeconds : idleConfig.screensaver,
    defaultScreensaverSeconds)
  readonly property int lockTimeoutSeconds: secondsFromConfig(
    ourConfig.lockDelaySeconds !== undefined ? ourConfig.lockDelaySeconds : idleConfig.lock,
    defaultLockSeconds)
  readonly property int firstIdleTimeoutSeconds: Math.min(screensaverTimeoutSeconds, lockTimeoutSeconds)
  readonly property int screensaverDelaySeconds: Math.max(0, screensaverTimeoutSeconds - firstIdleTimeoutSeconds)
  readonly property int lockDelaySeconds: Math.max(0, lockTimeoutSeconds - firstIdleTimeoutSeconds)
  readonly property bool idleEnabled: stayAwakeStateLoaded && !stayAwake
  readonly property string screensaverClass: "org.omarchy.screensaver"
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")

  property bool stayAwake: false
  property bool stayAwakeStateLoaded: false
  property bool hasPendingStayAwakePersist: false
  property bool pendingStayAwakePersist: false
  property bool idledThisCycle: false
  property bool screensaverStartedThisCycle: false
  property string lastEvent: "starting"
  property string lastEventAt: ""
  property var screensaverWindows: ({})
  property int screensaverWindowCount: 0
  property var ourConfig: ({})

  function secondsFromConfig(value, fallback) {
    return IdleModel.secondsFromConfig(value, fallback)
  }

  function parseOurConfig(jsonText) {
    try {
      var parsed = JSON.parse(jsonText)
      root.ourConfig = (parsed && typeof parsed === "object") ? parsed : ({})
    } catch (e) {
      root.ourConfig = ({})
    }
  }

  function nowIso() {
    return new Date().toISOString()
  }

  function logEvent(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details)
    root.lastEventAt = nowIso()
    root.lastEvent = event + suffix
    console.log("omarchy idle " + root.lastEventAt + " " + root.lastEvent)
  }

  function runProcess(process, label, command) {
    if (process.running) {
      logEvent("process-skip", label + " already running")
      return false
    }
    logEvent("process-start", label + " " + command)
    process.command = ["bash", "-lc", command]
    process.running = true
    return true
  }

  function launchScreensaver() {
    root.screensaverStartedThisCycle = true
    screensaverLaunchGraceTimer.restart()
    // The one intentional divergence from upstream omarchy.idle: launch our
    // own multi-animation launcher instead of the built-in ttfx screensaver,
    // falling back to it if our launcher is missing or exits non-zero.
    runProcess(screensaverProcess, "screensaver",
      "[[ $(omarchy-shell lock isLocked 2>/dev/null) == \"true\" ]] || \""
      + root.pluginDir + "/bin/ascii-screensaver-launch\" || omarchy-launch-screensaver")
  }

  function lockSystem(reason) {
    logEvent("lock-system", reason || "requested")
    screensaverTimer.stop()
    lockTimer.stop()
    screensaverLaunchGraceTimer.stop()
    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    resetScreensaverWindows()
    runProcess(lockProcess, "lock", "omarchy-system-lock")
  }

  function startIdleCycle() {
    if (root.idledThisCycle) {
      logEvent("idle-cycle-already-running")
      return
    }

    logEvent("idle-cycle-start", "screensaver=" + root.screensaverTimeoutSeconds + " lock=" + root.lockTimeoutSeconds)
    root.idledThisCycle = true
    root.screensaverStartedThisCycle = false
    resetScreensaverWindows()

    if (root.screensaverDelaySeconds === 0) launchScreensaver()
    else screensaverTimer.restart()

    if (root.lockDelaySeconds === 0) lockSystem("lock-timeout-immediate")
    else lockTimer.restart()
  }

  function cancelIdleCycle(reason) {
    logEvent("idle-cycle-cancel", reason || "requested")
    screensaverTimer.stop()
    lockTimer.stop()
    screensaverLaunchGraceTimer.stop()

    if (root.idledThisCycle) runProcess(wakeProcess, "wake", "omarchy-system-wake")

    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    resetScreensaverWindows()
  }

  function resetScreensaverWindows() {
    root.screensaverWindows = ({})
    root.screensaverWindowCount = 0
  }

  function setScreensaverWindow(address, visible) {
    var next = IdleModel.screensaverWindowsAfter(root.screensaverWindows, address, visible)
    root.screensaverWindows = next.windows
    root.screensaverWindowCount = next.count
  }

  function handleScreensaverWindowOpened(address) {
    setScreensaverWindow(address, true)
    screensaverLaunchGraceTimer.stop()
  }

  function handleScreensaverWindowClosed(address) {
    setScreensaverWindow(address, false)

    if (!root.idleEnabled || !root.idledThisCycle || !root.screensaverStartedThisCycle) return
    if (root.screensaverWindowCount > 0) return

    // The user dismissed the screensaver before the lock deadline. Treat that
    // as activity and cancel the pending lock; the lock timer is only allowed
    // to fire while the screensaver remains up.
    root.cancelIdleCycle("screensaver-dismissed")
  }

  function eventParts(event, count) {
    return IdleModel.eventParts(event, count)
  }

  function handleHyprlandEvent(event) {
    var name = String(event && event.name ? event.name : "")
    if (name === "openwindow") {
      var open = eventParts(event, 4)
      if (String(open[2] || "") === root.screensaverClass) root.handleScreensaverWindowOpened(open[0])
    } else if (name === "closewindow") {
      var close = eventParts(event, 1)
      var address = String(close[0] || "")
      if (root.screensaverWindows[address]) root.handleScreensaverWindowClosed(address)
    }
  }

  function handleActiveSignal() {
    if (!root.idledThisCycle) return

    // Starting the screensaver can make the compositor report activity. Keep
    // the lock timer running once the screensaver exists (or during its short
    // launch grace); Hyprland window events cancel the cycle if it exits before
    // the normal lock deadline.
    if (root.screensaverStartedThisCycle && (root.screensaverWindowCount > 0 || screensaverLaunchGraceTimer.running)) {
      logEvent("idle-monitor-active", "screensaver cycle remains armed")
      return
    }

    cancelIdleCycle("activity")
  }

  function handleIdleChanged() {
    logEvent("idle-monitor", idleMonitor.isIdle ? "idle" : "active")
    if (!root.idleEnabled) return

    if (idleMonitor.isIdle) startIdleCycle()
    else handleActiveSignal()
  }

  function statusJson() {
    return JSON.stringify({
      enabled: root.idleEnabled,
      stayAwake: root.stayAwake,
      stayAwakeStateLoaded: root.stayAwakeStateLoaded,
      stayAwakeStatePath: root.stayAwakeStatePath,
      idle: idleMonitor.isIdle,
      inIdleCycle: root.idledThisCycle,
      screensaverStarted: root.screensaverStartedThisCycle,
      screensaver: root.screensaverTimeoutSeconds,
      lock: root.lockTimeoutSeconds,
      screensaverDelay: root.screensaverDelaySeconds,
      lockDelay: root.lockDelaySeconds,
      screensaverWindows: root.screensaverWindowCount,
      timers: {
        screensaver: screensaverTimer.running,
        lock: lockTimer.running,
        screensaverLaunchGrace: screensaverLaunchGraceTimer.running
      },
      processes: {
        screensaver: screensaverProcess.running,
        lock: lockProcess.running,
        wake: wakeProcess.running
      },
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    })
  }

  function persistStayAwake(value) {
    var command = value
      ? "mkdir -p \"$HOME/.local/state/omarchy/indicators\" && touch \"$HOME/.local/state/omarchy/indicators/stay-awake\""
      : "rm -f \"$HOME/.local/state/omarchy/indicators/stay-awake\""

    if (stayAwakeStateWriter.running) {
      root.pendingStayAwakePersist = !!value
      root.hasPendingStayAwakePersist = true
      return
    }

    stayAwakeStateWriter.command = ["bash", "-lc", command]
    stayAwakeStateWriter.running = true
  }

  function refreshStayAwakeState() {
    if (!stayAwakeStateProbe.running) stayAwakeStateProbe.running = true
  }

  function applyStayAwake(value, persist, reason) {
    var enabled = !!value
    var changed = !root.stayAwakeStateLoaded || root.stayAwake !== enabled

    if (persist) persistStayAwake(enabled)

    root.stayAwake = enabled
    root.stayAwakeStateLoaded = true

    if (!changed) return enabled ? "disabled" : "enabled"

    logEvent("stay-awake", (enabled ? "enabled" : "disabled") + (reason ? " " + reason : ""))
    if (enabled) cancelIdleCycle("stay-awake")
    else Qt.callLater(root.handleIdleChanged)

    return enabled ? "disabled" : "enabled"
  }

  function setIdleEnabled(value) {
    return applyStayAwake(!value, true, "ipc")
  }

  IdleMonitor {
    id: idleMonitor
    enabled: root.idleEnabled
    timeout: root.firstIdleTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: root.handleIdleChanged()
  }

  Timer {
    id: screensaverTimer
    interval: root.screensaverDelaySeconds * 1000
    repeat: false
    onTriggered: root.launchScreensaver()
  }

  Timer {
    id: lockTimer
    interval: root.lockDelaySeconds * 1000
    repeat: false
    onTriggered: if (root.idleEnabled && root.idledThisCycle) root.lockSystem("lock-timeout")
  }

  Timer {
    id: screensaverLaunchGraceTimer
    interval: 3000
    repeat: false
    onTriggered: {
      if (root.idleEnabled && root.idledThisCycle && root.screensaverStartedThisCycle && root.screensaverWindowCount === 0 && !idleMonitor.isIdle) {
        root.cancelIdleCycle("screensaver-not-running")
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  Process {
    id: screensaverProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "screensaver exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: lockProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "lock exitCode=" + exitCode + " status=" + exitStatus) }
  }
  Process {
    id: wakeProcess
    onExited: function(exitCode, exitStatus) { root.logEvent("process-exit", "wake exitCode=" + exitCode + " status=" + exitStatus) }
  }

  Process {
    id: stayAwakeStateProbe
    command: ["bash", "-c", "mkdir -p \"$HOME/.local/state/omarchy/indicators\"; if [[ -f $HOME/.local/state/omarchy/indicators/stay-awake ]]; then echo yes; else echo no; fi"]
    stdout: SplitParser {
      onRead: function(line) { root.applyStayAwake(String(line).trim() === "yes", false, "state-file") }
    }
    onExited: function() { stayAwakeStateDirWatcher.reload() }
  }

  Process {
    id: stayAwakeStateWriter
    onExited: function() {
      if (root.hasPendingStayAwakePersist) {
        var pending = root.pendingStayAwakePersist
        root.hasPendingStayAwakePersist = false
        root.persistStayAwake(pending)
        return
      }

      root.refreshStayAwakeState()
    }
  }

  FileView {
    id: stayAwakeStateDirWatcher
    path: root.stayAwakeStateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshStayAwakeState()
  }

  FileView {
    id: ourConfigFile
    path: ConfigPaths.userConfigPath()
    watchChanges: true
    printErrors: false
    onLoaded: root.parseOurConfig(text())
    onLoadFailed: function(error) { bundledConfigFile.reload() }
    onFileChanged: reload()
  }

  FileView {
    id: bundledConfigFile
    path: ConfigPaths.bundledConfigPath(root.pluginDir)
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseOurConfig(text())
    onLoadFailed: function(error) { root.ourConfig = ({}) }
  }

  Component.onCompleted: {
    logEvent("service-ready")
    refreshStayAwakeState()
  }

  IpcHandler {
    target: "idle"

    function status(): string {
      return root.statusJson()
    }

    function debug(): string {
      return root.statusJson()
    }

    function enable(): string {
      return root.setIdleEnabled(true)
    }

    function disable(): string {
      return root.setIdleEnabled(false)
    }

    function toggle(): string {
      return root.setIdleEnabled(!root.idleEnabled)
    }
  }
}
```

### `Settings.qml` — full file (298 lines)

```qml
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
```

---

## 8. Recommended order of work in the public repo

1. Copy `ConfigPaths.js` as-is (§7).
2. Apply the `manifest.json` diff (§7).
3. Copy `params.schema.json` from the private repo with `plasma` stripped
   (§5, option 2) — verify `29` animations, no `plasma` key.
4. Apply the `Service.qml` and `Settings.qml` content (§7) — **but treat
   the `onFileChanged: reload()` lines as an unverified hypothesis**, not
   a done fix. Do the minimal repro from §4 Step 1 *first*, before
   trusting this in the full file.
5. Recompute and set `bin/check-upstream-drift`'s `EXPECTED_CHANGED_LINES`
   against the public repo's actual current `Service.qml` (don't assume
   48 — that number was computed against the private repo's
   already-more-diverged file).
6. Re-run the exact live verification sequence from Task 8 of the plan
   (`docs/superpowers/plans/2026-09-12-native-settings-panel.md`),
   **prioritizing §4's bug investigation** before declaring the
   delay-override feature done.
7. Only once the delay-override bug is genuinely resolved and verified
   with multiple sequential edits (not just one), commit and push to the
   public repo.

Everything else in this document (the design decisions in §2, the
verified reference patterns in §3, the working panel-rendering
confirmation in §6) can be trusted as-is.
