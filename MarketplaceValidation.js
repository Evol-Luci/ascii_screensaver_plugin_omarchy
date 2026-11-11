// Validation for untrusted marketplace data.
//
// index.json comes from a public repo that accepts community submissions, so
// every id, filename and URL in it is attacker-controlled. Before this
// existed, `entry.id` was concatenated straight into the `curl -o`
// destination, so an id of "../../../.." with a download URL ending in
// ".bashrc" wrote over $HOME/.bashrc — outside the animations directory the
// user agreed to install into. Everything that reaches a filesystem path or a
// process argument goes through here first.
//
// Keep this file plain JS with no QML imports: tests/marketplace-validation.test.js
// requires it directly under Node.

// A simple animation id: one path segment, no separators, no dot-dot.
var ID_PATTERN = /^[a-z0-9][a-z0-9._-]{0,63}$/;

// A simple filename: one path segment, must carry an expected extension.
var FILENAME_PATTERN = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$/;

// Matches what the animations repo's validator permits in an entry folder:
// the page, the manifest, and a preview image.
var ALLOWED_EXTENSIONS = ["html", "json", "gif", "png", "jpg", "jpeg", "webp"];

// Entry files are served from the animations repo; nothing else is fetched.
var ALLOWED_HOSTS = [
  "raw.githubusercontent.com",
  "objects.githubusercontent.com",
  "github.com"
];

var MAX_FILES_PER_ENTRY = 8;

// Hyprland key names: letters, digits, and the XF86_* media keys.
var HOTKEY_PATTERN = /^[A-Za-z0-9_]{1,32}$/;

function isValidAnimationId(id) {
  if (typeof id !== "string" || id.length === 0) return false;
  if (id.indexOf("..") !== -1) return false;
  return ID_PATTERN.test(id);
}

function hasAllowedExtension(name) {
  var dot = name.lastIndexOf(".");
  if (dot <= 0 || dot === name.length - 1) return false;
  var ext = name.slice(dot + 1).toLowerCase();
  return ALLOWED_EXTENSIONS.indexOf(ext) !== -1;
}

function isValidFileName(name) {
  if (typeof name !== "string" || name.length === 0) return false;
  if (name.indexOf("..") !== -1) return false;
  if (!FILENAME_PATTERN.test(name)) return false;
  return hasAllowedExtension(name);
}

function fileNameFromUrl(url) {
  if (typeof url !== "string") return "";
  var withoutQuery = url.split("#")[0].split("?")[0];
  var last = withoutQuery.split("/").slice(-1)[0];
  return last || "";
}

function isAllowedSourceUrl(url) {
  if (typeof url !== "string" || url.length === 0) return false;
  if (/[\s\u0000-\u001f\u007f]/.test(url)) return false;
  var match = url.match(/^https:\/\/([^\/?#]+)\//);
  if (!match) return false;
  var authority = match[1];
  // Reject userinfo and ports outright rather than parsing them: the only
  // hosts we accept are plain names on the default port.
  if (!/^[A-Za-z0-9.-]+$/.test(authority)) return false;
  return ALLOWED_HOSTS.indexOf(authority.toLowerCase()) !== -1;
}

// Resolves "." and ".." without touching the filesystem. QML's JS engine has
// no path module, and we must not consult the real filesystem to decide
// whether a path is in bounds.
function normalizePath(path) {
  if (typeof path !== "string") return "";
  var absolute = path.charAt(0) === "/";
  var parts = path.split("/");
  var out = [];
  for (var i = 0; i < parts.length; i++) {
    var part = parts[i];
    if (part === "" || part === ".") continue;
    if (part === "..") {
      if (out.length > 0) out.pop();
      continue;
    }
    out.push(part);
  }
  var joined = out.join("/");
  return absolute ? "/" + joined : joined;
}

// True only when candidate sits strictly inside baseDir. The trailing
// separator matters: without it, "<base>-evil/x" passes a plain prefix test.
function isContained(baseDir, candidate) {
  if (typeof baseDir !== "string" || baseDir.length === 0) return false;
  var base = normalizePath(baseDir);
  var target = normalizePath(candidate);
  if (base === "" || target === "") return false;
  var prefix = base === "/" ? "/" : base + "/";
  return target.length > prefix.length && target.indexOf(prefix) === 0;
}

// Returns the destination path, or "" when the id/filename pair is not safe.
function destinationFor(baseDir, id, filename) {
  if (typeof baseDir !== "string" || baseDir.length === 0) return "";
  if (!isValidAnimationId(id)) return "";
  if (!isValidFileName(filename)) return "";
  var dest = normalizePath(baseDir + "/" + id + "/" + filename);
  if (!isContained(baseDir, dest)) return "";
  return dest;
}

function reject(reason) {
  return { ok: false, reason: reason, id: "", files: [] };
}

// Validates a whole index entry up front, so a partially-downloaded install
// can never be the thing that discovers a bad field.
function validateEntry(entry, baseDir) {
  if (!entry || typeof entry !== "object") return reject("entry is not an object");
  if (typeof baseDir !== "string" || baseDir.length === 0) return reject("missing animations directory");
  if (!isValidAnimationId(entry.id)) return reject("invalid animation id");

  var files = entry.files;
  if (!files || Object.prototype.toString.call(files) !== "[object Array]") {
    return reject("entry has no file list");
  }
  if (files.length === 0) return reject("entry has no file list");
  if (files.length > MAX_FILES_PER_ENTRY) return reject("entry lists too many files");

  var resolved = [];
  var seen = {};
  for (var i = 0; i < files.length; i++) {
    var url = files[i];
    if (!isAllowedSourceUrl(url)) return reject("file source is not an allowed https url");
    var filename = fileNameFromUrl(url);
    if (!isValidFileName(filename)) return reject("file name is not an allowed simple name");
    if (seen[filename]) return reject("entry lists the same file name twice");
    seen[filename] = true;
    var dest = destinationFor(baseDir, entry.id, filename);
    if (dest === "") return reject("file destination escapes the animations directory");
    resolved.push({ url: url, filename: filename, dest: dest });
  }

  return { ok: true, reason: "", id: entry.id, files: resolved };
}

// Filters a parsed index down to entries that are safe to show and install.
// A rejected entry is dropped rather than repaired: we cannot know which part
// of it was intended.
function validateIndex(animations, baseDir) {
  var entries = [];
  var rejected = [];
  var list = (animations && Object.prototype.toString.call(animations) === "[object Array]") ? animations : [];
  for (var i = 0; i < list.length; i++) {
    var result = validateEntry(list[i], baseDir);
    if (result.ok) {
      entries.push({ entry: list[i], files: result.files });
    } else {
      rejected.push({
        id: (list[i] && typeof list[i].id === "string") ? list[i].id : "(unnamed)",
        reason: result.reason
      });
    }
  }
  return { entries: entries, rejected: rejected };
}

// The hotkey field is typed by the user, but it used to be interpolated into
// a `bash -c` string, where JSON quoting still leaves $(...) and backticks
// live. The snippet is now passed to wl-copy as an argv element, so this is
// defence in depth rather than the only barrier.
function isValidHotkeyKey(key) {
  if (typeof key !== "string") return false;
  return HOTKEY_PATTERN.test(key);
}

if (typeof module !== "undefined") {
  module.exports = {
    isValidAnimationId: isValidAnimationId,
    isValidFileName: isValidFileName,
    fileNameFromUrl: fileNameFromUrl,
    isAllowedSourceUrl: isAllowedSourceUrl,
    normalizePath: normalizePath,
    isContained: isContained,
    destinationFor: destinationFor,
    validateEntry: validateEntry,
    validateIndex: validateIndex,
    isValidHotkeyKey: isValidHotkeyKey,
    MAX_FILES_PER_ENTRY: MAX_FILES_PER_ENTRY
  };
}
