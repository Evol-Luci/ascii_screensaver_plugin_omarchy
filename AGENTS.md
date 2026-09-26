# Agent notes for this plugin

This is an Omarchy shell plugin (`io.github.evol-luci.ascii-screensaver`), written
in QML against Quickshell + the Omarchy shell's design system (`qs.Commons`,
`qs.Ui`). The notes below come from hands-on debugging sessions and exist to
save the next agent (any agent — Claude, Gemini, etc.) from re-learning them
the hard way.

## The two copies of this plugin — and why "it's fixed" can still look broken

Your edits in this repo are **not** what the running shell renders. Omarchy
loads the plugin from `~/.config/omarchy/plugins/io.github.evol-luci.ascii-screensaver/`,
which is a separate checkout (its own `.git`, its own possibly-stale commit,
often with uncommitted local edits). After every edit here:

```bash
cp <file> ~/.config/omarchy/plugins/io.github.evol-luci.ascii-screensaver/<file>
```

Before trusting *any* diff between the two, `diff -u` them — don't assume the
installed copy matches this repo just because you haven't touched it this
session. If you're hunting a "why doesn't my fix show up" bug, checking
`diff -u <source> <installed>` is step zero.

## Reloading after a change — the part that costs the most time

Omarchy watches the installed plugin directory and logs
`DEBUG qml: Local plugin changed, reloading: <plugin-id>` when a file changes.
**This hot reload does not recompile a QML type that the engine already
loaded in this process — including one that failed to load.** We verified
this twice, the hard way:

- A `Process { stdin: ... }` property error (see below) stayed logged
  *verbatim, same line numbers* after fixing the file, syncing it, and seeing
  the "Local plugin changed, reloading" log line. It also survived
  `disablePlugin` immediately followed by `enablePlugin` — that toggles the
  plugin's Loader, it does not evict the QML engine's compiled-component
  cache for that URL.
- The only thing that ever made a fixed file's errors actually disappear
  from the log was a full shell restart.

**So: after any edit that could plausibly be a QML error (new/changed
property, new component, changed binding) — not just cosmetic text/color
tweaks — restart the whole shell before believing your fix worked:**

```bash
omarchy restart shell
```

This is disruptive (bounces the bar and every panel for the session, ~3-4s),
so don't do it reflexively for every one-line change — but *do* do it before
declaring a QML-structural bug fixed. Confirm the process actually came back
before moving on:

```bash
pgrep -fa "omarchy-shell$" || journalctl --user --no-pager --since "10 sec ago" | tail -5
```

Useful IPC once the shell is up (`omarchy-shell shell <method> [args...]`):

```bash
omarchy-shell shell listPlugins                                             # confirm the plugin is enabled/known
omarchy-shell shell toggle 'io.github.evol-luci.ascii-screensaver' '{}'     # open/close the panel
omarchy-shell shell toggle 'io.github.evol-luci.ascii-screensaver' '{"select":"marketplace"}'  # open straight to a page (payload matches Panel.qml's open())
omarchy-shell shell disablePlugin 'io.github.evol-luci.ascii-screensaver'   # NOT a cache-clearing reload — just unloads the Loader
omarchy-shell shell enablePlugin 'io.github.evol-luci.ascii-screensaver' '{}'
```

`omarchy-shell shell <method>` with no target other than `shell` is correct —
there is no separate `openPanel`/`showPanel`/etc. IPC target; it's all under
`shell`'s `summon`/`hide`/`toggle`.

## Reading the logs — what's fatal vs. noise

```bash
journalctl --user --no-pager --since "1 min ago" | grep -i "ascii-screensaver\|<YourFile>.qml"
```

Lines that mean a QML type is actually broken (not just a runtime warning):

- `WARN scene: <file>.qml[N:M]: Cannot assign to non-existent property "X"`
- `WARN scene: <file>.qml[N:-1]: TypeError: Cannot read property 'Y' of undefined`
- `WARN scene: Panel.qml[...]: Type <X> unavailable` — this means some
  *other* component (X) failed to compile, and it cascades: the type that
  references it fails too. Don't just look at the file the top-level error
  names; trace which nested type actually failed.

Lines you can ignore (pre-existing / unrelated to this plugin):

- `Handler was registered but will not be used because another handler is
  registered for target ...` (other plugins' IpcHandler collisions)
- `Cannot open: file://.../lock-explorer-boot-previews/*.png` (unrelated
  plugin, missing preview assets)
- `module "GradualBlurObserver" is not installed` (unrelated plugin)

## No mouse/keyboard input injection available in this environment

`xdotool mousemove` is a silent no-op against this compositor (verified: cursor
position via `hyprctl cursorpos` doesn't move) — it's an X11 tool and this is
a native-Wayland session. `ydotool`/`wlrctl`/`dotool` are not installed. So an
agent cannot click through the UI to verify a fix. What actually works:

1. Restart the shell, open the panel via IPC (`shell toggle`), and grep the
   journal for QML errors — this catches every *structural* bug (bad
   property, bad type, bad binding).
2. For behavioral logic (e.g. "does uninstall actually remove the right
   thing"), pull the plain-JS logic out of the `.qml` file's `function`
   blocks and run it in a small standalone Node script against mock state.
   It's the same JavaScript; QML doesn't change JS semantics, only where the
   properties live. This caught real bugs without ever touching the UI.
3. `grim -o <output-name> <path.png>` + `hyprctl clients` (for window
   geometry) lets you *screenshot* the panel to confirm styling/rendering —
   just don't expect to interact with what you see.
4. When none of the above is conclusive, say so and ask the human to click
   through — don't claim a click-driven behavior is verified when it wasn't.

## Design-system gotchas (this is what actually broke the marketplace UI)

`qs.Commons`/`qs.Ui` resolve to `/usr/share/omarchy/shell/Commons/` and
`/usr/share/omarchy/shell/Ui/` — **read those files instead of guessing
property names**. Two guesses turned out wrong and shipped broken UI for a
while before anyone noticed (QML silently no-ops or defaults instead of
erroring loudly for these two failure shapes):

- **There is no `Color.surface`.** `Color` (`Commons/Color.qml`) only has
  `foreground`, `background`, `accent`, `urgent`, `muted`, plus semantic
  groups (`Color.bar`, `Color.menu`, `Color.popups`, `Color.tooltip`,
  `Color.lock`, `Color.polkit`, `Color.imagePicker`). Assigning
  `color: Color.surface` doesn't error — it silently assigns `undefined` to
  a `QColor` property, which Qt renders as **opaque white**. If a
  panel/card is mysteriously plain white against this app's dark theme,
  this is almost certainly why. The established pattern for a translucent
  "card"/surface look elsewhere in this codebase (see `GeneralDetail.qml`)
  is:
  ```qml
  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
  ```
- **There is no `Style.radius` object.** `Style.radius.md` / `.sm` throw a
  `TypeError: Cannot read property 'md' of undefined` at runtime (visible in
  the journal, not the UI). The real token is a flat int:
  `Style.cornerRadius`. Border width is `Style.normalBorderWidth`. Spacing
  is `Style.spacing.xxs/xs/sm/md/lg/xl`. Sizes go through `Style.space(px)`.
  Typography is `Style.font.family/caption/bodySmall/body/subtitle/title/
  heading/display/displayLarge`.

## Quickshell `Process` (`Quickshell.Io`) gotchas

- **There is no `stdin` property.** Only `stdinEnabled` (bool) and a
  `write(data: string)` method exist. Assigning `stdin: someString` doesn't
  error loudly either — in our case it made the *entire enclosing QML file*
  fail to load (`Type MarketplaceTab unavailable`), which cascaded up and
  broke the whole settings panel from opening at all. If you need to pipe
  data into a process, prefer avoiding stdin entirely: write to disk via
  `Quickshell.Io.FileView`'s `setText()`/`setData()` instead of shelling out
  to `cat`. It's simpler and sidesteps shell-escaping downloaded content
  entirely.
- **`command: [...]` is an argv list, not a shell string** — prefer it over
  `["bash", "-c", "... " + interpolatedUntrustedValue + " ..."]`. The latter
  is a shell-injection risk the moment `interpolatedUntrustedValue` comes
  from a network response (e.g. a marketplace index.json this plugin
  doesn't control). `["mkdir", "-p", dirPath]` / `["rm", "-rf", dirPath]`
  run directly with no shell parsing, so untrusted path segments can't break
  out of the argument they're in — but still validate the segment itself
  (e.g. reject `/` or `..`) before it becomes part of a path you delete.

## GIF/image previews

Plain QtQuick `Image` never animates GIFs — it only ever shows frame 0. Use
`AnimatedImage` (still from base `QtQuick`, no extra import) with
`playing: true`. The GIF Qt image plugin (`libqgif.so`) is present at
`/usr/lib/qt6/plugins/imageformats/`, so this works out of the box here. For
a genuinely single-frame image, `AnimatedImage.frameCount` is `1`; there's
nothing to "animate" but it still displays fine as a still.

## The Marketplace's catalog is a mix of built-in-mirrored and genuinely new entries

The remote marketplace index (`Evol-Luci/ascii-screensaver-animations`'s
`index.json`) originally launched as a 100%-overlap seed catalog — every id
matched one of the 30 animations already bundled in `params.schema.json`.
That's no longer true: genuinely new, marketplace-only animations (e.g.
`dna`, `fireworks`, `galaxy`, `matrix`, `ocean`) have since been submitted
and merged. Don't assume "it's in the Marketplace list" means "it has files
under `ConfigPaths.userAnimationsDir()`" — check `root.userSchema` (real
marketplace-downloaded entries) vs `root.schema` (bundled built-ins).
`Panel.qml`'s `schemaFor()` prefers `root.schema` over `root.userSchema`, so
a marketplace "install" of an id that's also built-in doesn't actually take
effect visually even if it downloads files — which is why `Panel.qml` special
-cases these (see `reinstallBuiltin` / `builtinIds`) instead of doing a real
download for them.

`Panel.qml`'s welcome pane shows `<N> animations installed, <N> enabled` and
a `<N> from the Marketplace, <N> built-in` breakdown
(`root.marketplaceInstalledCount = Object.keys(root.userSchema).length`).
Check this whenever debugging "why didn't my installed animation stick
around" — it tells you immediately whether an id ended up in `userSchema` at
all, without needing to inspect `screensaver-config.json` by hand. When
these two counts didn't match what was actually on disk, it turned out to be
two separate concurrency bugs (below) — **not** a hardcoded animation-count
cap. There is no cap anywhere in this codebase; if the numbers look
suspiciously close to 30, check `params.schema.json`'s key count before
assuming a limit exists.

## Shared mutable state across async operations is the #1 recurring bug class here

Two separate, structurally identical bugs both produced the same user-visible
symptom — "I installed 5 marketplace animations, only 1 (or a random subset)
showed up, even after closing and reopening the panel" — and both had the
same shape: **a single set of properties on a component's root reused as
"the current operation's state," with no guard against a second call
starting before the first one's async work (network request / process /
file read) has finished.** Each new call silently clobbers the previous
call's in-flight state. Neither failure logged an error — this class of bug
is invisible in the journal; you have to trace the data flow by hand or add
temporary `console.warn` tracing (see below).

1. **`MarketplaceTab.qml`'s install pipeline** used single shared
   `_installTarget` / `_installQueue` / `_installQueueIndex` properties.
   Clicking "Install" on animation B while A's download was still in flight
   overwrote A's queue/target with B's. Whichever install's file-queue
   happened to empty out *last* won — `_onInstallComplete()` read the
   now-current (possibly totally different) `_installTarget`, so multiple
   installs could collapse into a single registered animation. Fixed by
   giving each `installAnimation()` call its own job object
   (`{entry, files, fileIndex}`) pushed onto a `_installJobs` queue,
   processed one at a time (`_installBusy` gate) — no call ever shares
   mutable state with another. If you add another async multi-step
   operation here (batch uninstall, batch reinstall, etc.), reach for this
   same per-job-queue shape from the start rather than a handful of shared
   root properties.

2. **`UserAnimationLoader.qml`'s `scan()`** had the same shape:
   `pendingNames` / `loadIndex` / `currentName` shared across the whole
   directory traversal, and `scan()` never reset `pendingNames`/`loadIndex`
   at the start of a new run. `scan()` runs far more often than it looks
   like it should: `Panel.qml`'s `commit()` writes the config file, which
   (via `watchChanges: true` + `onFileChanged: reload()`) triggers its own
   reload, which calls `parsePersistedConfig()`, which calls `scan()` again
   — so installing N animations in a row could kick off N overlapping scans
   of the same directory, each corrupting the others' traversal position.
   It even showed up on a **single clean shell restart** with no rapid
   clicking involved, because both of `Panel.qml`'s config `FileView`s
   (`userConfigFile` and `bundledConfigFile`) auto-load at startup and each
   independently calls `parsePersistedConfig()` → `scan()`. Fixed with an
   explicit `_scanning` re-entrancy guard: a `scan()` call that arrives
   while one is already running just sets `_rescanRequested = true` and
   returns; the in-flight scan checks that flag when it finishes and
   re-runs itself once, instead of the two interleaving.

If you're chasing a bug where "N async operations were started but fewer
than N distinct results ever land," suspect this pattern first: grep for
properties declared once and reassigned from multiple call sites of an
`async`-flavored function, with no per-call/per-job isolation.

## `Quickshell.Io.FileView` reused across different `path` values is unreliable

`UserAnimationLoader.qml` used to reuse one `FileView` instance across a
whole directory scan — set `path` to the next manifest, call `.reload()`,
handle `onLoaded`/`onLoadFailed`, repeat. **In testing here, this reliably
completed the *first* file and then silently never fired `onLoaded` or
`onLoadFailed` again for any subsequent path** — no error, no warning, the
scan just stopped dead after one entry. This is *not* the same bug as the
re-entrancy issue above (it reproduced even with the re-entrancy guard in
place and only one scan ever running). Root cause not fully root-caused
inside Quickshell itself — the fix was to stop relying on FileView for this
and switch to a `Process` running `cat <path>` with a `stdout: StdioCollector`
child, reading `manifestCollector.text` in `onExited`. `Process` reuse
across many sequential invocations (`command` reassigned, `running` toggled
back to `true`) has been reliable everywhere else in this plugin (downloads,
`mkdir`, `rm`) — prefer it over reusing a `FileView` for "read N different
files one after another" patterns. A `FileView` declared once with a
`path` that's set **once** and left alone (like `Panel.qml`'s
`schemaFile`/`userConfigFile`) is fine; it's specifically *reassigning
`path` to switch to a different file on an existing instance* that broke
here.

## Debugging technique: temporary `console.warn` tracing beats guessing

When a multi-step async chain silently produces fewer results than
expected and the journal has zero errors or warnings, don't keep
re-reading the code hoping to spot it — add `console.warn("TAG", ...)`
at every step of the chain (function entry, each async callback, each
branch of a conditional), sync, `omarchy restart shell`, reproduce, then
`journalctl --user --since "10 sec ago" | grep TAG`. This is what
surfaced the FileView bug above: the trace showed the chain calling
`loadNext()` correctly, `manifestView.path`/`.reload()` being set correctly
for the second entry, and then... nothing — no `onLoaded`, no
`onLoadFailed`, ever, for that second call. That silence, not a stack trace,
was the actual signal. Remove the tracing once you've found the bug — it's
not meant to stay in the file.

## Config self-reload race

`Panel.qml`'s `userConfigFile` has `watchChanges: true` and
`onFileChanged: reload()`. That means **every `commit()` (which writes the
config) triggers its own file-changed event**, which reloads and re-parses
the config, which re-runs `UserAnimationLoader.scan()` — a full re-scan of
the user animations directory. If you need to delete files as part of an
"uninstall"-type operation, do the deletion (and wait for it to actually
finish, e.g. a `Process.onExited` handler) **before** calling `commit()` —
otherwise the self-triggered rescan can find the not-yet-deleted directory
and silently re-add the very thing you're removing.

## Anatomy of a marketplace animation
When creating or validating animations for the marketplace, two easily missed requirements exist:
1. **Valid Preview Images**: The `preview.gif` (or `.png`/`.jpg`) referenced in `manifest.json` MUST be a structurally valid binary image. Using a text file with dummy data (e.g., `echo "GIF89a" > preview.gif`) will silently break the Omarchy QML renderer and stop the marketplace UI from displaying properly.
2. **Screensaver Dismiss Logic**: You do **NOT** need to implement dismiss logic. The Omarchy screensaver plugin wraps all animations in a unified system viewer that captures mouse/keyboard activity and automatically tears down the process.

## The viewer, the live preview, and why Chromium's --class doesn't matter

- **Chromium on Wayland ignores `--class`.** A window's app_id is
  `"chrome-_" + <page path with "/" → "_"> + "-Default"`. So the
  screensaver is `…_system_viewer.html-Default` and the settings panel's
  live preview is `…_system_preview.html-Default` — two HTML entry points
  (sharing `system/viewer.js`) exist only so they get different app_ids.
  `Service.qml` and `bin/ascii-screensaver-launch` match the exact viewer
  app_id; never match on a substring that would also catch the preview.
- **The viewer owns the info panel and dismissal**, never the animation. It
  strips `screensaver`, `meta_*`, `anim`, `path`, `state` before passing the
  URL params to the animation, so leftover legacy boilerplate in an
  animation is inert. Info-panel text comes from `meta_*` params computed by
  `bin/ascii-screensaver-cmd` (manifest.json, else params.schema.json) and
  is rendered with `textContent` — it is marketplace-supplied text.
- **Marketplace animations are untrusted code.** They run in a
  `sandbox="allow-scripts"` iframe, Chromium gets no
  `--allow-file-access-from-files`, and all traffic goes to a dead proxy
  except Google Fonts. Don't add `--allow-file-access-from-files` back or
  `fetch()` local files from the viewer; pass data via URL params or JSONP
  `<script src>` (which works file→file without that flag). Don't use
  `--host-resolver-rules`: Chromium shows an "unsupported flag" bar for it.
- **Live preview** (`LivePreview.qml`): `bin/ascii-screensaver-preview`
  registers a runtime `hl.window_rule` then `exec`s Chromium; the panel polls
  `hyprctl clients -j` and moves the window over `previewSlot` (resize
  *before* move — Hyprland resizes around the centre). Settings reach the
  page via `$XDG_RUNTIME_DIR/ascii-screensaver/preview-state.js` (JSONP,
  written with FileView). It runs whenever an animation page is open —
  there is no on/off switch — so `omarchy-shell shell toggle
  'io.github.evol-luci.ascii-screensaver' '{"select":"bonsai"}'` is enough to
  bring it up for testing. The panel is recreated on every open.
- **Edits must replace, not mutate, config objects.** `Panel.commit()`
  deep-copies `persistedConfig`: a binding that gets back the same JS object
  doesn't update, which once made slider knobs snap back on release.
- **`pkill -f <pattern>` from an agent's shell can kill the shell itself**
  when the pattern appears in the command line; use a bracket trick
  (`pkill -f "[p]review\.html"`) or close windows via `hyprctl` instead.
