# Third-Party Notices

This project is licensed under GPL-3.0 (see `LICENSE`).

## Runtime dependencies (external tools)

Not bundled — must be present on the system for this plugin to work:

- [`chromium`](https://www.chromium.org/) — renders each animation in a
  fullscreen app window (and the settings panel's live preview)
- [`jq`](https://jqlang.org/) — reads `screensaver-config.json` and animation
  manifests
- [`socat`](http://www.dest-unreach.org/socat/) — synchronizes multi-monitor
  launch timing over Hyprland's event socket

## Network access

Animations run in a sandboxed frame inside a Chromium window that has no
network access and no access to local files: every request goes to a dead
proxy, with one exception — Google Fonts (`fonts.googleapis.com` /
`fonts.gstatic.com`), which most animations use to load the "JetBrains Mono"
font. Chromium caches it after the first run. No other network requests are
made during playback.

The settings panel's **Marketplace** tab fetches the catalog and any animation
you install from GitHub (`raw.githubusercontent.com`), only when you open it or
click Install.

The info panel shown when the screensaver starts displays each animation's
author as plain text (for the bundled animations,
`www.evoldigitalproductions.com`); it is not a link and makes no request.

## Design inspiration

### animations/nixie

Inspired by [joeparadiso/nixie-tube-clock](https://github.com/joeparadiso/nixie-tube-clock).
