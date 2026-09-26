# ASCII Screensaver — Roadmap

> Started 2026-09-20; updated 2026-09-26. §1–§3 are done and kept as a record
> of what was decided; §4 is the next planned feature.

---

## 1. User-Authored Animations + Install/Uninstall ✅

**Status: DONE.** Every animation — built-in or installed — has an **Uninstall**
button on its page. Uninstalling a built-in hides it (`removedBuiltins` in the
config); installing it again from the Marketplace un-hides it. Uninstalling a
Marketplace animation deletes its folder. User animations live in
`~/.config/omarchy/ascii-screensaver/animations/<id>/` (an `index.html`, a
`manifest.json`, a preview); the panel discovers them on disk
(`UserAnimationLoader.qml`) and builds their settings from the manifest's
`params`. The authoring format is documented in the README ("Building Your Own
Animation") and the animations repo's `CONTRIBUTING.md`.

Decisions: user animations live outside the plugin checkout, so plugin updates
never touch them; uninstall deletes files immediately (after the config write
settles — see AGENTS.md "Config self-reload race").

---

## 2. Animations Marketplace ✅

**Status: DONE.** A single monorepo,
[ascii-screensaver-animations](https://github.com/Evol-Luci/ascii-screensaver-animations),
holds every animation (the 30 built-ins mirrored, plus Marketplace-only ones),
each with its preview in its own folder. On merge, a bot regenerates
`index.json` and the README gallery. The panel's **Marketplace** tab fetches
`index.json` on demand and installs with one click.

Trust model: submissions are open, but every PR is gated by CI — the validator
(run from the base branch, so a PR can't edit it) checks the manifest and
`index.html`, and a live render in a headless browser posts a frame next to the
submitted preview — and a maintainer reviews before merging. Independently,
animations run sandboxed with no network (see THIRD_PARTY_NOTICES.md).

Still open: no offline cache — the tab needs a network connection to browse.

---

## 3. Config Sanitization ✅

**Status: DONE (2026-09-20).** The bundled `screensaver-config.json` ships
neutral defaults: all 30 built-ins enabled with default params, the ten
flagships (aquarium, aurora, bonsai, incense, nixie, pendulum_wave, pipes,
sandmandala, terrarium, thunderstorm) at weight 9 and the rest at weight 1, and
no personal timing — so the General page falls back to Omarchy's idle settings
until you set your own.

---

## 4. Now Playing Over the Screensaver

> Captured: 2026-09-26.

**Goal:** When music is playing and the screensaver starts (by default only *video*
holds it off — see `mediaStayAwake`), show what's playing, and let media keys control
it without waking the screen.

### Requirements

- A small **now-playing card** over the running screensaver: track title, artist,
  album art (MPRIS `mpris:artUrl`), a progress bar, and play/pause state. Unobtrusive —
  a corner card in the same style as the viewer's info panel, fading in on track change
  and dimming otherwise.
- **Media keys don't dismiss the screensaver.** Play/Pause, Next, Previous and Stop
  (XF86AudioPlay/Pause/Next/Prev/Stop, and ideally volume keys) pass through to the
  player and just update the card. Any other key or mouse movement still dismisses.
- Works on every monitor the screensaver runs on (or only the focused one — decide).
- A General-page toggle to turn the card off.

### Design notes / open questions

- **Where the card lives.** The screensaver is a fullscreen Chromium window, so either:
  (a) a Quickshell layer-shell panel (`WlrLayershell`, overlay layer) from the plugin,
  drawn above Chromium — native QML, reads `Quickshell.Services.Mpris` directly; or
  (b) inside `system/viewer.js`, fed track info by the plugin. (a) is likely simpler and
  keeps the viewer sandbox untouched; check Hyprland stacks an overlay layer above a
  fullscreen window.
- **Media keys.** Today `viewer.js` dismisses on any `keydown`. Omarchy's media keys are
  Hyprland binds, so Hyprland may consume them before Chromium sees them — verify. If
  they do reach the page, `viewer.js` should ignore `MediaPlayPause`, `MediaTrackNext`,
  `MediaTrackPrevious`, `MediaStop` (and `AudioVolume*`) in its dismiss handler. The
  Service's idle logic must also not treat them as "activity" that cancels the cycle.
- MPRIS already exposes everything needed (`trackTitle`, `trackArtist`, `trackAlbum`,
  `trackArtUrl`, `position`, `length`, `playbackState`) — see `Service.qml`'s media code.

---

## Related Files

- `README.md` — user guide, including "Building Your Own Animation"
- [animations repo `CONTRIBUTING.md`](https://github.com/Evol-Luci/ascii-screensaver-animations/blob/main/CONTRIBUTING.md) — full authoring and submission rules
- `AGENTS.md` — architecture notes and debugging lessons for anyone working on the code
- `docs/specs/`, `docs/plans/`, `docs/superpowers/` — the original design specs and implementation plans (historical; each notes its status at the top)
- `MIGRATION.md` — moving from the old AUR package / `install.sh`
