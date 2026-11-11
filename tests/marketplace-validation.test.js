// Tests for MarketplaceValidation.js — run with: node tests/marketplace-validation.test.js
//
// The marketplace index is community-submitted, so every id, filename and URL
// in it is attacker-controlled. These cases pin the two escapes reported in
// marketplace issue #14563 plus the ordinary happy paths.

var V = require("../MarketplaceValidation.js");

var failures = 0;
var checks = 0;

function check(label, actual, expected) {
  checks++;
  var a = JSON.stringify(actual);
  var e = JSON.stringify(expected);
  if (a !== e) {
    failures++;
    console.log("FAIL  " + label + "\n        expected " + e + "\n        actual   " + a);
  }
}

var BASE = "/home/user/.config/omarchy/ascii-screensaver/animations";

// --- animation ids ---------------------------------------------------------
check("plain id", V.isValidAnimationId("bonsai"), true);
check("id with dash/dot/underscore", V.isValidAnimationId("matrix-rain_2.0"), true);
check("64-char id", V.isValidAnimationId("a" + new Array(64).join("b")), true);
check("65-char id", V.isValidAnimationId("a" + new Array(65).join("b")), false);
check("empty id", V.isValidAnimationId(""), false);
check("undefined id", V.isValidAnimationId(undefined), false);
check("traversal id", V.isValidAnimationId("../../../../"), false);
check("traversal id embedded", V.isValidAnimationId("a/../../b"), false);
check("dotdot substring", V.isValidAnimationId("a..b"), false);
check("leading dot", V.isValidAnimationId(".bashrc"), false);
check("slash", V.isValidAnimationId("a/b"), false);
check("backslash", V.isValidAnimationId("a\\b"), false);
check("absolute", V.isValidAnimationId("/etc/passwd"), false);
check("uppercase", V.isValidAnimationId("Bonsai"), false);
check("tilde", V.isValidAnimationId("~"), false);
check("newline", V.isValidAnimationId("ok\nid"), false);
check("nul", V.isValidAnimationId("ok\u0000id"), false);

// --- filenames ------------------------------------------------------------
check("index.html", V.isValidFileName("index.html"), true);
check("manifest.json", V.isValidFileName("manifest.json"), true);
check("preview.gif", V.isValidFileName("preview.gif"), true);
check("preview.PNG case-insensitive ext", V.isValidFileName("preview.PNG"), true);
check("dotfile", V.isValidFileName(".bashrc"), false);
check("no extension", V.isValidFileName("bashrc"), false);
check("disallowed ext", V.isValidFileName("evil.service"), false);
check("shell script", V.isValidFileName("evil.sh"), false);
check("double ext still checked on last", V.isValidFileName("evil.html.sh"), false);
check("traversal filename", V.isValidFileName("../x.html"), false);
check("empty filename", V.isValidFileName(""), false);

// --- source urls ----------------------------------------------------------
var RAW = "https://raw.githubusercontent.com/Evol-Luci/ascii-screensaver-animations/main/bonsai/index.html";
check("raw github https", V.isAllowedSourceUrl(RAW), true);
check("plain http", V.isAllowedSourceUrl(RAW.replace("https:", "http:")), false);
check("file url", V.isAllowedSourceUrl("file:///etc/passwd"), false);
check("unknown host", V.isAllowedSourceUrl("https://evil.example/x/index.html"), false);
check("userinfo smuggling", V.isAllowedSourceUrl("https://raw.githubusercontent.com@evil.example/x/index.html"), false);
check("host prefix trick", V.isAllowedSourceUrl("https://raw.githubusercontent.com.evil.example/x/index.html"), false);
check("whitespace in url", V.isAllowedSourceUrl("https://raw.githubusercontent.com/a b/index.html"), false);
check("empty url", V.isAllowedSourceUrl(""), false);

// --- path normalization and containment -----------------------------------
check("normalize plain", V.normalizePath("/a/b/c"), "/a/b/c");
check("normalize dotdot", V.normalizePath("/a/b/../c"), "/a/c");
check("normalize trailing dotdot", V.normalizePath("/a/b/../../"), "/");
check("normalize double slash", V.normalizePath("/a//b"), "/a/b");
check("normalize single dot", V.normalizePath("/a/./b"), "/a/b");
check("normalize escape past root", V.normalizePath("/a/../../b"), "/b");
check("contained child", V.isContained(BASE, BASE + "/bonsai/index.html"), true);
check("contained self is not child", V.isContained(BASE, BASE), false);
check("escaped sibling", V.isContained(BASE, "/home/user/.bashrc"), false);
check("prefix-only lookalike", V.isContained(BASE, BASE + "-evil/x"), false);

// --- destination building -------------------------------------------------
check("destination happy path",
  V.destinationFor(BASE, "bonsai", "index.html"),
  BASE + "/bonsai/index.html");
check("destination rejects bad id", V.destinationFor(BASE, "../../../..", "index.html"), "");
check("destination rejects bad filename", V.destinationFor(BASE, "bonsai", ".bashrc"), "");

// --- whole-entry validation ----------------------------------------------
var good = {
  id: "bonsai",
  name: "Bonsai",
  files: [RAW, RAW.replace("index.html", "manifest.json"), RAW.replace("index.html", "preview.gif")]
};
var goodResult = V.validateEntry(good, BASE);
check("good entry accepted", goodResult.ok, true);
check("good entry file count", goodResult.files.length, 3);
check("good entry first dest", goodResult.files[0].dest, BASE + "/bonsai/index.html");
check("good entry preview dest", goodResult.files[2].dest, BASE + "/bonsai/preview.gif");

// The exact scenario from the review: id "../../../../" plus a URL whose last
// component is .bashrc previously resolved to $HOME/.bashrc.
var attack = { id: "../../../../", name: "pwn", files: ["https://evil.example/x/.bashrc"] };
check("review attack rejected", V.validateEntry(attack, BASE).ok, false);
check("review attack reason", V.validateEntry(attack, BASE).reason, "invalid animation id");

var attackHostOk = {
  id: "../../../../",
  name: "pwn",
  files: [RAW.replace("bonsai/index.html", ".bashrc")]
};
check("traversal rejected even from allowed host", V.validateEntry(attackHostOk, BASE).ok, false);

check("systemd unit drop rejected",
  V.validateEntry({ id: "../../../../.config/systemd/user", files: [RAW.replace("index.html", "evil.service")] }, BASE).ok,
  false);

// QML hands JS back array-like sequence objects (V4Sequence), not real Arrays,
// once a value has round-tripped through a `property var` and a Repeater's
// modelData. An Array-tag check rejects those, which broke install while the
// identical data passed at index-parse time. Simulate one here.
function sequenceLike(items) {
  var seq = { length: items.length };
  for (var i = 0; i < items.length; i++) seq[i] = items[i];
  return seq; // Object.prototype.toString.call(seq) === "[object Object]"
}
var seqEntry = { id: "bonsai", name: "Bonsai", files: sequenceLike(good.files) };
check("array-like file list accepted", V.validateEntry(seqEntry, BASE).ok, true);
check("array-like file count", V.validateEntry(seqEntry, BASE).files.length, 3);
check("array-like first dest", V.validateEntry(seqEntry, BASE).files[0].dest, BASE + "/bonsai/index.html");
check("array-like index accepted", V.validateIndex(sequenceLike([good]), BASE).entries.length, 1);
check("array-like traversal still rejected",
  V.validateEntry({ id: "../../../../", files: sequenceLike([RAW]) }, BASE).ok, false);
check("string file list still rejected", V.validateEntry({ id: "bonsai", files: "index.html" }, BASE).ok, false);
check("object without length still rejected", V.validateEntry({ id: "bonsai", files: { a: RAW } }, BASE).ok, false);
check("negative length rejected", V.validateEntry({ id: "bonsai", files: { length: -1 } }, BASE).ok, false);
check("fractional length rejected", V.validateEntry({ id: "bonsai", files: { length: 1.5, 0: RAW } }, BASE).ok, false);

// A declared length must be bounded BEFORE anything is copied or iterated:
// an array-like claiming a trillion entries previously reached the copy loop
// and hung the shared QML shell on first show of the Marketplace tab, with no
// Install click involved. These assert both the rejection and that it is
// immediate — a regression here would hang this test run, so each is timed.
function timed(label, fn, expected) {
  var started = Date.now();
  var actual = fn();
  var elapsed = Date.now() - started;
  check(label, actual, expected);
  check(label + " is immediate (<100ms)", elapsed < 100, true);
}
timed("huge declared files length rejected",
  function () { return V.validateEntry({ id: "ocean", files: { length: 1000000000000 } }, BASE).ok; }, false);
check("huge declared files reason",
  V.validateEntry({ id: "ocean", files: { length: 1000000000000 } }, BASE).reason, "entry lists too many files");
timed("huge declared catalog length rejected",
  function () { return V.validateIndex({ length: 1000000000000 }, BASE).entries.length; }, 0);
timed("oversized real file array rejected",
  function () {
    var many = []; for (var i = 0; i < V.MAX_FILES_PER_ENTRY + 1; i++) many.push(RAW);
    return V.validateEntry({ id: "bonsai", files: many }, BASE).ok;
  }, false);
check("catalog at the limit still accepted",
  V.validateIndex(sequenceLike([good]), BASE).entries.length, 1);
check("oversized catalog reports a reason",
  V.validateIndex({ length: 1000000000000 }, BASE).rejected.length > 0, true);

check("no files rejected", V.validateEntry({ id: "bonsai", files: [] }, BASE).ok, false);
check("missing files rejected", V.validateEntry({ id: "bonsai" }, BASE).ok, false);
check("non-array files rejected", V.validateEntry({ id: "bonsai", files: "index.html" }, BASE).ok, false);
check("too many files rejected",
  V.validateEntry({ id: "bonsai", files: new Array(40).join(",").split(",").map(function () { return RAW; }) }, BASE).ok,
  false);
check("one bad file rejects whole entry",
  V.validateEntry({ id: "bonsai", files: [RAW, "https://evil.example/x/evil.sh"] }, BASE).ok,
  false);
check("null entry rejected", V.validateEntry(null, BASE).ok, false);
check("empty base dir rejected", V.validateEntry(good, "").ok, false);

// --- index filtering ------------------------------------------------------
var filtered = V.validateIndex([good, attack, null, good], BASE);
check("index keeps only valid entries", filtered.entries.length, 2);
check("index counts rejects", filtered.rejected.length, 2);
check("index keeps entry object identity", filtered.entries[0].entry.id, "bonsai");

// --- hotkey keys ----------------------------------------------------------
check("plain key", V.isValidHotkeyKey("F12"), true);
check("letter key", V.isValidHotkeyKey("S"), true);
check("named key", V.isValidHotkeyKey("Print"), true);
check("key with underscore", V.isValidHotkeyKey("XF86_Audio"), true);
check("command substitution key", V.isValidHotkeyKey("F12$(printf injected)"), false);
check("backtick key", V.isValidHotkeyKey("F12`id`"), false);
check("semicolon key", V.isValidHotkeyKey("F12; rm -rf /"), false);
check("quote key", V.isValidHotkeyKey("F12\""), false);
check("space key", V.isValidHotkeyKey("F 12"), false);
check("empty key", V.isValidHotkeyKey(""), false);
check("overlong key", V.isValidHotkeyKey(new Array(40).join("F")), false);

console.log((failures === 0 ? "PASS" : "FAIL") + " — " + (checks - failures) + "/" + checks + " checks passed");
process.exit(failures === 0 ? 0 : 1);
