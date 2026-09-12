# Migrating from the AUR package / manual install

Omarchy Quattro removed `hypridle` — idle detection now lives inside
`omarchy-shell` itself. The old `ascii-screensaver-git` AUR package and
`install.sh` flow (which wired a `hypridle.conf` listener) no longer work
and are removed as of this version. This project is now distributed as an
**Omarchy plugin**.

## If you installed via the AUR package

1. Remove the package:
   ```bash
   yay -R ascii-screensaver-git   # or your AUR helper of choice
   ```
2. Remove the dead `hypridle.conf` listener block it added, if still
   present in `~/.config/hypr/hypridle.conf`:
   ```
   listener {
       timeout = 120
       on-timeout = pidof hyprlock || .../ascii-screensaver-launch
   }
   ```
   (Omarchy Quattro no longer reads `hypridle.conf` for idle at all — this
   block is inert either way, but worth cleaning up.)
3. Install the plugin:
   ```bash
   omarchy plugin add https://github.com/Evol-Luci/ascii-screensaver.git --enable
   ```

## If you cloned the repo and ran `install.sh` manually

1. Undo whatever `install.sh` symlinked onto your `PATH` (check
   `~/.local/bin/ascii-screensaver-*`) and remove them, along with the
   `~/.local/share/ascii-screensaver/` directory they point into.
2. Remove the stale app-menu entry it installed:
   `~/.local/share/applications/ascii-screensaver-config.desktop`.
3. Remove any `hypridle.conf` listener you added by hand (see above).
4. Install the plugin the same way:
   ```bash
   omarchy plugin add https://github.com/Evol-Luci/ascii-screensaver.git --enable
   ```

## What changes for you

- The screensaver is now triggered by a cloned `omarchy.idle` service
  instead of `hypridle` — timeouts are configured the same way, in
  `~/.config/omarchy/shell.json`'s `idle.screensaver` / `idle.lock` keys.
- Per-animation parameters still live at
  `~/.config/ascii-screensaver/screensaver-config.json`, unchanged.
- Configuration now happens through a native settings panel instead of
  the old HTML UI, launched via:
  ```bash
  omarchy-shell shell summon io.github.evol-luci.ascii-screensaver '{}'
  ```
  See the README's "Configuring animations" section for adding this as
  an Omarchy menu shortcut.
