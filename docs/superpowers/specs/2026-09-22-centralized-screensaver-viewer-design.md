# Centralized Screensaver Viewer Design

> **Status:** Implemented, with changes (2026-09-25). The viewer's logic is in system/viewer.js, shared by viewer.html and preview.html; the animation runs in a sandbox="allow-scripts" iframe with no network or file access; info-panel text comes from meta_* URL params computed by bin/ascii-screensaver-cmd (not fetched), rendered as plain text; the screensaver param is not passed to animations. See AGENTS.md "The viewer, the live preview…".

## Overview
Currently, individual ASCII screensaver animations are responsible for rendering their own "credits" and info panels, as well as handling the mouse/keyboard dismiss logic. This leads to boilerplate in every animation, inconsistency across new vs. old animations, and an additional burden on marketplace creators.

This design shifts those responsibilities to a centralized `viewer.html` wrapper. Chromium will load this wrapper, which will embed the target animation in an iframe, dynamically render the standard info panel, and handle the dismiss logic centrally.

## Architecture

### 1. The Launcher (`bin/ascii-screensaver-cmd`)
Instead of pointing Chromium directly to `animations/<id>/index.html`, the launcher will point to a new file: `system/viewer.html`.
The launcher will pass all necessary context via URL query parameters:
*   `anim`: The ID of the animation.
*   `path`: The absolute path to the animation's `index.html` (since user animations live in `~/.config/...`).
*   `screensaver=1`, `startAt`, and other existing parameters.

### 2. The Central Viewer (`system/viewer.html`)
The central viewer will be a minimal HTML file serving as the host:
*   **Iframe Host:** It will contain a `<iframe id="anim-frame" style="width:100vw; height:100vh; border:none;"></iframe>` pointing to the provided `path`.
*   **Central Dismiss Overlay:** It will contain a transparent `<div id="dismiss-shield" style="position:fixed; inset:0; z-index:9999;"></div>` that listens for `mousemove`, `mousedown`, and `keydown`. When triggered (with the existing 1.5s grace period), it will call `window.close()` and tear down the DOM.
*   **Info Panel Rendering:** 
    *   It will fetch the bundled `params.schema.json`.
    *   It will attempt to fetch `manifest.json` if it's a user animation.
    *   It will extract the animation's `title`, `hint`, and `author` (falling back gracefully if absent).
    *   It will construct and append the `.credits-popup` UI, fading it in and out at the correct times.

### 3. Cleanup of Existing Animations
All currently bundled animations (e.g., bonsai, moon, crawl) will have their hardcoded `<div class="credits-popup">...</div>` DOM injection and `dismiss` logic script blocks removed. 

### 4. Documentation Updates
`AGENTS.md` will be updated to explicitly state that creators **no longer** need to provide their own screensaver dismiss logic, as it is handled by the central wrapper.

## Implementation Steps
1. Create `system/viewer.html` with the iframe, dismiss shield, and metadata fetching logic.
2. Update `bin/ascii-screensaver-cmd` to route the `HTML_URL` to `system/viewer.html`.
3. Test the wrapper with an existing animation to verify rendering, parameters, and dismiss logic.
4. Batch process all existing `animations/*/index.html` files to remove the legacy screensaver boilerplate.
5. Update `AGENTS.md` to reflect the new architecture.

## Trade-offs and Considerations
*   **Event Bubbling:** By using a transparent `div` shield, the underlying iframe cannot receive mouse events. This is intentional for a screensaver (any interaction should dismiss it) but means animations cannot be interactive while in screensaver mode.
*   **File Access:** `viewer.html` will be loaded via `file://`. It must fetch `params.schema.json` via relative paths or absolute file paths. Chromium kiosk mode with `--allow-file-access-from-files` may be required if cross-directory file fetching (e.g., fetching from the user config directory) triggers CORS policies for local files.
