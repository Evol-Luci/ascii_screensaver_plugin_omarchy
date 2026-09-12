# Third-Party Notices

This project is licensed under GPL-3.0 (see `LICENSE`).

## Runtime dependencies (external tools)

Not bundled — must be present on the system for this plugin to work:

- [`chromium`](https://www.chromium.org/) — renders each animation in kiosk mode
- [`jq`](https://jqlang.org/) — reads `screensaver-config.json`
- [`socat`](http://www.dest-unreach.org/socat/) — synchronizes multi-monitor launch timing over Hyprland's event socket

## Network access

Every animation under `animations/` loads the "JetBrains Mono" font
from Google Fonts (`fonts.googleapis.com` / `fonts.gstatic.com`) the
first time it runs in the Chromium kiosk window; it is cached by
Chromium afterward and no other network requests are made during
playback. Each animation's on-screen credits overlay also links to the
author's site, `evoldigitalproductions.com`, as static text — not a
network call made by the animation itself.

## Design inspiration

### animations/nixie

Inspired by [joeparadiso/nixie-tube-clock](https://github.com/joeparadiso/nixie-tube-clock).
