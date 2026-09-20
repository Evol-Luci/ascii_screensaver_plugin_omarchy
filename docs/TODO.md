# ASCII Screensaver — Next Phase TODO

> Captured: 2026-09-20. Planned features for the next major development phase.
> See `docs/specs/` for detailed design specs once brainstorming sessions are completed.

---

## 1. User-Authored Animations + Install/Uninstall System

**Goal:** Let users write their own animations and add or remove any animation — including
built-ins — from the config in a structured, systematic way (not by manually editing JSON).

### Requirements

- Every animation — default and user-installed — must have a **first-class uninstall option**
  exposed in the QML panel. Nothing is baked in with no removal path.
- Define a **standard animation manifest format** so user-authored animations can declare
  their name, description, params schema, preview GIF path, and source (local or marketplace).
- The panel's animation list should be driven by discovered animations on disk + config,
  not a hardcoded list.
- Uninstalling a default animation removes it from the active set; it remains re-installable
  from the animations marketplace (see §2).
- Installing a new animation = dropping its folder + manifest into the animations directory
  and registering it in the config. The panel should offer a guided flow for this.
- Document the animation authoring format in `docs/authoring-animations.md` so users can
  write compatible animations without reading source code.

### Open Design Questions (resolve in brainstorm)
- Where does the user animations folder live? Inside the plugin dir, or `~/.config/omarchy/...`?
- How are params schemas declared for user animations vs. the current `params.schema.json`?
- Does uninstall delete files, or just disable + flag for later garbage collection?
- What does the guided install flow look like in the panel? Drag-and-drop a folder? File picker?

---

## 2. Animations Marketplace

**Goal:** A community-driven marketplace for sharing, discovering, and installing ASCII
animations — modelled on the Omarchy plugin marketplace workflow.

### Architecture

- **New separate repo** (`ascii-screensaver-animations` or similar) housing:
  - All 30 default animations (moved from this plugin's `animations/` directory)
  - A submission template and contributor guide (`CONTRIBUTING.md`, `verify-animation.yml` issue template)
  - A marketplace index (`index.json`) listing available animations with metadata
- The 30 base animations become the **seed content** of the marketplace. This is how users
  re-install a default animation they previously uninstalled.
- Submission workflow mirrors the Omarchy plugin verify/publish GitHub issue template.

### QML Panel Integration

- A new **"Browse Animations"** tab or section in the panel shows marketplace animations with
  preview GIFs, descriptions, author, and an Install button.
- Installed marketplace animations appear in the main animation list with the same
  enable/disable/weight/uninstall controls as built-ins.
- The panel fetches the marketplace index JSON from the animations repo on demand; no daemon.

### Open Design Questions (resolve in brainstorm)
- Single monorepo for all animations vs. each animation in its own repo (like omarchy plugins)?
- How is the marketplace index structured, and how often is it refreshed in the panel?
- Trust/approval model: open submissions or maintainer-reviewed before listing?
- Offline/cached mode when the user has no network?
- Preview GIF hosting: in each animation's folder in the repo, or a separate CDN/release asset?

---

## 3. Config Sanitization ✅

**Status: DONE (2026-09-20)** — `screensaver-config.json` has been reset to neutral defaults:
all 30 animations enabled, all weights set to `1`, all params reset to sensible defaults.
Personal settings (custom weights of 0/9, personal palette choices, personal timing tweaks)
have been removed so new users start from a fully randomized, equal-weight experience.

---

## Related Files

- `docs/specs/` — detailed design specs (created after brainstorming sessions)
- `docs/authoring-animations.md` — animation authoring guide *(to be written)*
- `MIGRATION.md` — existing migration notes from AUR package
