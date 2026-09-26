# Live Preview Design Spec

> **Status:** Superseded (2026-09-25). The shipped live preview is embedded in the settings panel rather than a pinned, centered window: LivePreview.qml keeps a borderless Chromium window over a slot on each animation page and follows the panel; it runs whenever an animation page is open (no toggle); state goes through a JSONP file in $XDG_RUNTIME_DIR written with FileView (no /tmp, no shell, no --disable-web-security); it opens system/preview.html so its window is never mistaken for a screensaver. See AGENTS.md.

## Overview
This feature upgrades the Omarchy ascii-screensaver settings panel to support a dynamic, hot-reloading "Live Preview" of animations as their parameters are edited. Since the Quickshell QML runtime lacks an embedded web engine, the preview is achieved by spawning a specialized floating Chromium window that continuously polls a local state file for parameter updates.

## 1. Window Management
- **Launcher Modification**: `bin/ascii-screensaver-cmd` will be updated to accept a `PREVIEW=1` environment variable.
- **Chromium Flags**: When `PREVIEW=1` is set, the launcher will:
  - Omit `--start-fullscreen`.
  - Add `--window-size=600,450`.
  - Use a specific class: `--class="ascii-screensaver-preview"`.
  - Add `--disable-web-security` to allow seamless local `file://` fetching without CORS restrictions.
- **Hyprland Rules**: The QML or launch script will apply window rules to ensure the preview floats and stays pinned:
  - `windowrulev2 float,class:^(ascii-screensaver-preview)$`
  - `windowrulev2 pin,class:^(ascii-screensaver-preview)$`
  - `windowrulev2 center,class:^(ascii-screensaver-preview)$`

## 2. Hot-Reload Pipeline (Data Flow)
- **State File**: A temporary JSON file located at `/tmp/ascii-screensaver-preview.json` will serve as the communication bridge.
- **QML Writer**: `AnimationDetail.qml` (and related param editors) will write the current parameter state to this file whenever a parameter is modified. This avoids the need to restart the Chromium process.
- **Viewer Reader**: `system/viewer.html` will detect the `preview_mode=1` URL parameter. If active, it will start a `setInterval` loop (e.g., 300ms) to `fetch('file:///tmp/ascii-screensaver-preview.json')`.
- **Hot Reload**: When `viewer.html` detects a change in the JSON payload, it will dynamically update the `src` attribute of the animation's internal `iframe`, appending the new parameters to the query string. This causes the iframe to reload the animation instantly with the new settings.

## 3. User Interface Integration
- **Toggle Button**: The existing "Preview this animation" button in `AnimationDetail.qml` will be converted to a toggle state (e.g., "Start Live Preview" / "Stop Live Preview").
- **Lifecycle Management**: 
  - Clicking the toggle on spawns the `ascii-screensaver-preview` Chromium instance.
  - Clicking the toggle off, closing the Omarchy panel, or navigating to a different animation tab will explicitly kill the preview instance (`pkill -f` targeting the specific preview class or URL).
  - The QML logic must ensure that orphaned preview windows do not persist in the background.

## Scope & Constraints
- This feature only affects the settings panel preview experience. The actual idle screensaver functionality remains unchanged (fullscreen, no polling).
- The polling mechanism is lightweight and restricted only to the preview window.
- The use of `--disable-web-security` is safe in this context as the Chromium instance is strictly bound to local `file://` URLs for the bundled animations and has network access disabled.
