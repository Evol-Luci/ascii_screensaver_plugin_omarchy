// Shared "user config overrides bundled config" path resolution, matching
// the same precedence the bash scripts (bin/ascii-screensaver-launch,
// bin/ascii-screensaver-cmd) already implement:
//   ${XDG_CONFIG_HOME:-$HOME/.config}/ascii-screensaver/screensaver-config.json
// takes precedence over <pluginDir>/screensaver-config.json.

function userConfigPath() {
  var xdgConfigHome = Quickshell.env("XDG_CONFIG_HOME")
  var home = Quickshell.env("HOME")
  var configHome = xdgConfigHome && xdgConfigHome.length > 0 ? xdgConfigHome : (home + "/.config")
  return configHome + "/ascii-screensaver/screensaver-config.json"
}

function bundledConfigPath(pluginDir) {
  return pluginDir + "/screensaver-config.json"
}

if (typeof module !== "undefined") {
  module.exports = {
    userConfigPath: userConfigPath,
    bundledConfigPath: bundledConfigPath
  }
}
