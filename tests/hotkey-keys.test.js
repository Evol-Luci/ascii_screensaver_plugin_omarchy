// Tests for HotkeyKeys.js — run with: node tests/hotkey-keys.test.js
//
// Key codes are Qt.Key_* values, verified against qnamespace.h. Every name
// this returns must also satisfy MarketplaceValidation.isValidHotkeyKey, since
// the result is interpolated into the Hyprland bind snippet.

var K = require("../HotkeyKeys.js");
var V = require("../MarketplaceValidation.js");

var failures = 0, checks = 0;
function check(label, actual, expected) {
  checks++;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    failures++;
    console.log("FAIL  " + label + "\n        expected " + JSON.stringify(expected) + "\n        actual   " + JSON.stringify(actual));
  }
}

check("F1", K.hyprlandKeyName(0x01000030, ""), "F1");
check("F12", K.hyprlandKeyName(0x0100003b, ""), "F12");
check("F35 (top of range)", K.hyprlandKeyName(0x01000052, ""), "F35");
check("letter A", K.hyprlandKeyName(0x41, "a"), "A");
check("letter Z", K.hyprlandKeyName(0x5a, "z"), "Z");
check("digit 0", K.hyprlandKeyName(0x30, "0"), "0");
check("digit 9", K.hyprlandKeyName(0x39, "9"), "9");
check("space", K.hyprlandKeyName(0x20, " "), "space");
check("Return", K.hyprlandKeyName(0x01000004, ""), "Return");
check("keypad Enter maps to Return", K.hyprlandKeyName(0x01000005, ""), "Return");
check("Page_Up", K.hyprlandKeyName(0x01000016, ""), "Page_Up");
check("Menu", K.hyprlandKeyName(0x01000055, ""), "Menu");
check("VolumeUp", K.hyprlandKeyName(0x01000072, ""), "XF86AudioRaiseVolume");
check("MediaPlay", K.hyprlandKeyName(0x01000080, ""), "XF86AudioPlay");

// Modifiers alone are not bindable — SUPER is already in the snippet.
check("Shift alone", K.hyprlandKeyName(0x01000020, ""), "");
check("Control alone", K.hyprlandKeyName(0x01000021, ""), "");
check("Super_L alone", K.hyprlandKeyName(0x01000053, ""), "");
check("Super_R alone", K.hyprlandKeyName(0x01000054, ""), "");

// Non-US layouts report the letter in event.text even when the key code is not
// in the Latin range.
check("layout fallback letter", K.hyprlandKeyName(0x01ffffff, "q"), "Q");
check("layout fallback digit", K.hyprlandKeyName(0x01ffffff, "7"), "7");

// Anything else is refused rather than guessed, so nothing odd or unbounded
// can reach the snippet.
check("punctuation refused", K.hyprlandKeyName(0x01ffffff, ";"), "");
check("multi-char text refused", K.hyprlandKeyName(0x01ffffff, "abc"), "");
check("long text refused", K.hyprlandKeyName(0x01ffffff, new Array(5000).join("a")), "");
check("command substitution text refused", K.hyprlandKeyName(0x01ffffff, "$(id)"), "");
check("non-number key refused", K.hyprlandKeyName("F12", "F12"), "");
check("undefined key refused", K.hyprlandKeyName(undefined, undefined), "");
check("NaN key refused", K.hyprlandKeyName(NaN, ""), "");

// Every name produced must pass the hotkey validator.
var codes = [0x01000030, 0x0100003b, 0x01000052, 0x41, 0x5a, 0x30, 0x39, 0x20,
             0x01000004, 0x01000005, 0x01000016, 0x01000055, 0x01000072, 0x01000080];
var bad = codes.map(function (c) { return K.hyprlandKeyName(c, ""); })
               .filter(function (n) { return n !== "" && !V.isValidHotkeyKey(n); });
check("every produced name passes isValidHotkeyKey", bad, []);

console.log((failures === 0 ? "PASS" : "FAIL") + " — " + (checks - failures) + "/" + checks + " checks passed");
process.exit(failures === 0 ? 0 : 1);
