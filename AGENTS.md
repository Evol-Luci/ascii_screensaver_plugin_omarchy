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

## The Marketplace's current catalog is 100% built-in overlap

As of writing, every id in the remote marketplace index
(`Evol-Luci/ascii-screensaver-animations`'s `index.json`) matches one of the
30 animations already bundled in `params.schema.json`. There is currently no
genuinely-external marketplace animation to test against. Don't assume "it's
in the Marketplace list" means "it has files under
`ConfigPaths.userAnimationsDir()`" — check `root.userSchema` (real
marketplace-downloaded entries) vs `root.schema` (bundled built-ins).
`Panel.qml`'s `schemaFor()` prefers `root.schema` over `root.userSchema`, so
a marketplace "install" of an id that's also built-in doesn't actually take
effect visually even if it downloads files — which is why `Panel.qml` special
-cases these (see `reinstallBuiltin` / `builtinIds`) instead of doing a real
download for them.

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
