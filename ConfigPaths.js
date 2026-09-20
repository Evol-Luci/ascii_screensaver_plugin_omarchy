function userConfigPath() {
  var xdgConfigHome = Quickshell.env("XDG_CONFIG_HOME")
  var home = Quickshell.env("HOME")
  var configHome = xdgConfigHome && xdgConfigHome.length > 0 ? xdgConfigHome : (home + "/.config")
  return configHome + "/ascii-screensaver/screensaver-config.json"
}

function bundledConfigPath(pluginDir) {
  return pluginDir + "/screensaver-config.json"
}

function userAnimationsDir() {
  var xdgConfigHome = Quickshell.env("XDG_CONFIG_HOME")
  var home = Quickshell.env("HOME")
  var configHome = xdgConfigHome && xdgConfigHome.length > 0 ? xdgConfigHome : (home + "/.config")
  return configHome + "/omarchy/ascii-screensaver/animations"
}

if (typeof module !== "undefined") {
  module.exports = {
    userConfigPath: userConfigPath,
    bundledConfigPath: bundledConfigPath,
    userAnimationsDir: userAnimationsDir
  }
}
