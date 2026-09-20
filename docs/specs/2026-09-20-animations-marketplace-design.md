# Design Spec: Animations Marketplace & Install/Uninstall System

**Date:** 2026-09-20
**Project:** ascii_screensaver_plugin_omarchy
**Status:** Approved — ready for implementation planning

---

## Overview

Two tightly coupled features delivered together:

1. **Install/Uninstall System** — every animation (built-in or community) is a first-class
   citizen that can be fully removed from the panel and config, or re-installed from the
   marketplace. Users can also author and install their own animations locally.

2. **Animations Marketplace** — a new dedicated tab in the QML panel that browses, installs,
   and uninstalls animations from a community-maintained GitHub monorepo. The 30 existing
   built-in animations seed the marketplace and serve as authoring references.

The install/uninstall system is the foundation; the marketplace tab builds on top of it.

---

## 1. Animation Format

Every animation — built-in, marketplace, or user-authored — is a **self-contained folder**:

```
my-animation/
├── index.html       # The animation (required)
└── manifest.json   # Metadata and params schema (required)
```

### `manifest.json` schema (required fields)

```json
{
  "id": "my-animation",
  "name": "My Animation",
  "description": "A short human-readable description.",
  "author": "Your Name",
  "version": "1.0.0",
  "preview": "preview.gif",
  "params": []
}
```

- `id` must match the folder name exactly.
- `params` mirrors the existing `params.schema.json` structure — an array of param
  descriptors with `key`, `type`, `label`, `defaultValue`, etc.
- `preview` is optional but strongly recommended; relative path to a GIF in the same folder.

The 30 built-in animations will be updated to include `manifest.json` files and serve as
canonical authoring examples. A full authoring guide will be written to
`docs/authoring-animations.md`.

---

## 2. Animation Storage

| Type | Location |
|---|---|
| Built-in animations | `<plugin-dir>/animations/` (read-only, ships with plugin) |
| User-installed / marketplace animations | `~/.config/omarchy/ascii-screensaver/animations/` |
| Marketplace index cache | In-memory only (session-scoped) |

User-installed animations in `~/.config/omarchy/ascii-screensaver/animations/` survive
plugin updates. The plugin merges both directories at runtime when building the animation list.

---

## 3. Install / Uninstall Behaviour

### The distinction between Disable and Uninstall

| Action | Config entry | Visible in panel | In rotation |
|---|---|---|---|
| **Disable** | Stays (`enabled: false`) | ✅ Yes | ❌ No |
| **Uninstall** | Removed entirely | ❌ Hidden | ❌ No |

- **Disable** is for "I don't want this playing right now but I might want it later."
- **Uninstall** is for "I don't want this cluttering my panel at all."
- Uninstall **never deletes files** — the animation folder stays on disk. Only the config
  entry is removed. Re-installing from the marketplace simply re-adds the config entry.
- Built-in animations can be uninstalled just like any other. They live in the plugin dir
  permanently; uninstalling just hides them from the panel and removes them from rotation.

### Install flow (from marketplace)
1. User clicks Install in the Marketplace tab.
2. Panel fetches each file listed in `index.json` for that animation via raw GitHub URLs.
3. Files are written to `~/.config/omarchy/ascii-screensaver/animations/<id>/`.
4. A config entry is added for the animation with default params and `enabled: true`, `weight: 1`.
5. Animation appears immediately in the main animation list.

### Uninstall flow
1. User clicks Uninstall on any animation in the panel (main list or marketplace tab).
2. Config entry is removed entirely from `screensaver-config.json`.
3. Animation disappears from the main animation list immediately.
4. Files remain on disk untouched.
5. Animation reappears in the Marketplace tab as "Not installed" and can be re-installed.

---

## 4. QML Panel Changes

### New: Marketplace Tab

A dedicated **Marketplace** tab is added alongside the existing tabs (General, Animations, etc.).

**Layout:**
- Search/filter bar at the top.
- Grid or list of animation cards, each showing: preview GIF, name, author, description,
  and an Install / Uninstall button based on current state.
- A **Refresh** button (top-right corner) to re-fetch `index.json` on demand.
- On first open per session, `index.json` is fetched automatically from GitHub.
  Subsequent opens within the same session use the in-memory cache.
- If the network fetch fails, an error state is shown with a retry option.

### Changes to existing Animation list

- Each animation entry gains an **Uninstall** option (e.g. a contextual menu or button).
- The list is driven dynamically from the config (no hardcoded animation names in QML).
  Both built-in and user-installed animations appear here as peers.

---

## 5. Animations Monorepo (`ascii-screensaver-animations`)

A new public GitHub repo under the same owner, separate from the plugin repo.

### Structure

```
ascii-screensaver-animations/
├── index.json              # Marketplace index (all published animations)
├── CONTRIBUTING.md         # How to submit an animation
├── .github/
│   ├── workflows/
│   │   └── validate-pr.yml # CI gate (see §6)
│   └── PULL_REQUEST_TEMPLATE.md
└── animations/
    ├── bonsai/
    │   ├── index.html
    │   ├── manifest.json
    │   └── preview.gif
    ├── moon/
    │   └── ...
    └── ... (all 30 built-ins + community additions)
```

### `index.json` structure

```json
{
  "version": 1,
  "updated": "2026-09-20",
  "animations": [
    {
      "id": "bonsai",
      "name": "Bonsai",
      "description": "Procedural bonsai tree...",
      "author": "Luci Evol",
      "version": "1.0.0",
      "preview": "https://raw.githubusercontent.com/.../bonsai/preview.gif",
      "files": [
        "https://raw.githubusercontent.com/.../bonsai/index.html",
        "https://raw.githubusercontent.com/.../bonsai/manifest.json",
        "https://raw.githubusercontent.com/.../bonsai/preview.gif"
      ]
    }
  ]
}
```

### Migration of built-ins

The 30 animations currently in `animations/` in the plugin repo are moved to the new
animations monorepo. The plugin repo references them as marketplace content rather than
bundling them directly — OR — the plugin continues to ship them locally for offline
zero-config use and the monorepo is the canonical source for updates and re-installs.

> **Decision needed during implementation planning:** Ship built-ins locally (offline-friendly)
> AND list them in marketplace, or marketplace-only with a first-run bulk install?
> Recommendation: keep shipping locally for now (no internet required on first install),
> list them in marketplace so uninstalled ones can be recovered.

---

## 6. CI Submission Gate

GitHub Actions workflow (`validate-pr.yml`) runs on every PR to the animations monorepo.
PRs that fail any check are **automatically closed with a comment** explaining which check
failed and how to fix it. PRs that pass all checks enter the maintainer review queue.

### Automated checks

| Check | Rule |
|---|---|
| Manifest exists | `animations/<id>/manifest.json` must be present |
| Manifest is valid JSON | Parseable, no syntax errors |
| Required manifest fields | `id`, `name`, `description`, `author`, `version` all present and non-empty |
| Folder/ID match | Folder name must equal `manifest.json` `id` field exactly |
| `index.html` exists | `animations/<id>/index.html` must be present |
| Self-contained — no external scripts | No `<script src="http...">` tags loading external resources |
| Self-contained — no external fetch | No `fetch(` or `XMLHttpRequest` calls to external domains |
| No `eval()` / `new Function()` | Basic code injection guard |
| File size limit | Total animation folder size ≤ 2 MB |
| `index.json` updated | PR must include an updated `index.json` with the new animation entry |

### Manual review (maintainer)
PRs passing CI are reviewed for: animation quality, description accuracy, preview GIF
present and representative, params schema correctness. Merge = listed in marketplace.

---

## 7. Authoring Guide

`docs/authoring-animations.md` will cover:
- Folder structure and required files
- Full `manifest.json` field reference with examples
- How to declare custom params (types, labels, defaults, ranges)
- How to read params from the host via the existing JS bridge
- How to submit to the marketplace (PR workflow + CI requirements)
- The 30 built-ins as reference implementations

---

## Resolved Decisions

1. **Built-ins shipping strategy:** Ship locally in the plugin (offline-friendly, zero-config
   first install) AND list in the marketplace so uninstalled animations can be recovered.
   The plugin dir copy is the offline fallback; the marketplace is the canonical source for
   updates and re-installs.

2. **Params JS bridge:** Reuse the existing runtime params mechanism. Research the current
   implementation during planning and document it in `docs/authoring-animations.md` rather
   than designing a new interface.

3. **`index.json` update automation:** A GitHub Actions bot auto-updates `index.json` on
   merge. Contributors do not manually edit `index.json` — the CI workflow handles it.
   The CI gate (§6) will require the PR to touch only the animation folder; `index.json`
   is written by the bot post-merge.

4. **Preview image for user-authored local animations:** A preview image is required but
   flexible — either a GIF or a still image (PNG/JPG) is acceptable. The `manifest.json`
   `preview` field must point to one or the other. A generic placeholder is shown in the
   panel if the file is missing, but submission to the marketplace will fail CI without it.
