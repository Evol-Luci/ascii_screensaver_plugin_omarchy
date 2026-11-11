// Maps a Qt key event to the keysym name Hyprland expects in a `bind =` line.
//
// The hotkey control captures keypresses instead of using a TextField: an
// editable QQuickTextInput reads clipboard mime data on every clipboard
// change, and Qt's Wayland data-offer reader has no total byte or time bound,
// so a hostile clipboard client could stall the shell without the user
// pasting. Capturing a key needs no text input at all.
//
// Qt.Key_* values are inlined as numbers so this file stays plain JS and can
// be tested under Node, where the Qt namespace does not exist. The values are
// stable public API from qnamespace.h.

var KEY_0 = 0x30;
var KEY_9 = 0x39;
var KEY_A = 0x41;
var KEY_Z = 0x5a;
var KEY_F1 = 0x01000030;
var KEY_F35 = 0x01000052;

// Keys worth binding that are neither alphanumeric nor function keys. The
// names are X keysym names, which is what Hyprland parses.
// Values verified against /usr/include/qt6/QtCore/qnamespace.h.
var NAMED = {
  0x20: "space",              // Key_Space
  0x01000004: "Return",       // Key_Return
  0x01000005: "Return",       // Key_Enter, on the keypad
  0x01000006: "Insert",
  0x01000007: "Delete",
  0x01000008: "Pause",
  0x01000009: "Print",
  0x01000010: "Home",
  0x01000011: "End",
  0x01000012: "Left",
  0x01000013: "Up",
  0x01000014: "Right",
  0x01000015: "Down",
  0x01000016: "Page_Up",      // Key_PageUp
  0x01000017: "Page_Down",    // Key_PageDown
  0x01000055: "Menu",         // Key_Menu
  0x01000070: "XF86AudioLowerVolume",  // Key_VolumeDown
  0x01000071: "XF86AudioMute",         // Key_VolumeMute
  0x01000072: "XF86AudioRaiseVolume",  // Key_VolumeUp
  0x01000080: "XF86AudioPlay",         // Key_MediaPlay
  0x01000081: "XF86AudioStop",         // Key_MediaStop
  0x01000082: "XF86AudioPrev",         // Key_MediaPrevious
  0x01000083: "XF86AudioNext"          // Key_MediaNext
};

// Modifiers alone are not a binding; the snippet already supplies SUPER.
var MODIFIERS = {
  0x01000020: true,           // Key_Shift
  0x01000021: true,           // Key_Control
  0x01000022: true,           // Key_Meta
  0x01000023: true,           // Key_Alt
  0x01000024: true,           // Key_CapsLock
  0x01000025: true,           // Key_NumLock
  0x01000026: true,           // Key_ScrollLock
  0x01000053: true,           // Key_Super_L
  0x01000054: true            // Key_Super_R
};

// Returns the keysym name, or "" when the key is not bindable. The result is
// always something isValidHotkeyKey() accepts.
function hyprlandKeyName(key, text) {
  if (typeof key !== "number" || !isFinite(key)) return "";
  if (MODIFIERS[key]) return "";

  if (key >= KEY_F1 && key <= KEY_F35) return "F" + (key - KEY_F1 + 1);
  if (key >= KEY_A && key <= KEY_Z) return String.fromCharCode(key);
  if (key >= KEY_0 && key <= KEY_9) return String.fromCharCode(key);

  var named = NAMED[key];
  if (named) return named;

  // Fall back to a single printable character the event reported, which
  // covers letters typed on non-US layouts. Anything else is refused rather
  // than guessed, so no unbounded or odd text can reach the snippet.
  if (typeof text === "string" && text.length === 1) {
    var code = text.charCodeAt(0);
    var isLetter = (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
    var isDigit = code >= 0x30 && code <= 0x39;
    if (isLetter) return text.toUpperCase();
    if (isDigit) return text;
  }
  return "";
}

if (typeof module !== "undefined") {
  module.exports = {
    hyprlandKeyName: hyprlandKeyName
  };
}
