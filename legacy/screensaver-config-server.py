#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
import threading
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PLUGIN_ROOT = SCRIPT_DIR.parent
BUNDLED_CONFIG_FILE = PLUGIN_ROOT / "screensaver-config.json"
USER_CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "ascii-screensaver"
USER_CONFIG_FILE = USER_CONFIG_DIR / "screensaver-config.json"
UI_FILE = SCRIPT_DIR / "screensaver-config-ui.html"
PROFILE_DIR = Path.home() / ".config" / "ascii-screensaver-config"
ANIMATION_NAMES = {"aurora", "mandelbrot", "pipes", "fluid", "thunderstorm", "bonsai", "moon", "crawl", "blackhole", "nixie", "incense", "planet", "gameoflife", "sandmandala", "campfire", "boids", "windchimes", "vinyl", "waterfall", "jellyfish", "terrarium", "aquarium", "spiderweb", "volcano", "oscilloscope", "pendulum_wave", "glitch_field", "cyber_deck", "attractor"}


class ConfigHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PLUGIN_ROOT), **kwargs)

    def log_message(self, format, *args):
        return

    def do_GET(self):
        if self.path in {"/", "/screensaver-config-ui.html"}:
            self.path = "/legacy/screensaver-config-ui.html"
            return super().do_GET()
        if self.path == "/api/config":
            return self.send_json(read_config())
        return super().do_GET()

    def do_POST(self):
        if self.path != "/api/config":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        length = int(self.headers.get("Content-Length", "0"))
        try:
            raw_body = self.rfile.read(length).decode("utf-8")
            config = validate_config(json.loads(raw_body))
            write_config(config)
        except (json.JSONDecodeError, ValueError) as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.BAD_REQUEST)
            return
        except OSError as exc:
            self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)
            return

        self.send_json({"ok": True, "config": config})

    def send_json(self, payload, status=HTTPStatus.OK):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def read_config():
    config_file_path = USER_CONFIG_FILE if USER_CONFIG_FILE.exists() else BUNDLED_CONFIG_FILE
    if not config_file_path.exists():
        return {"enabled": True, "mode": "random", "selectedAnimation": "terrarium", "animations": []}
    with config_file_path.open(encoding="utf-8") as config_file:
        return json.load(config_file)


def validate_config(config):
    if not isinstance(config, dict):
        raise ValueError("Config must be a JSON object.")

    animations = config.get("animations")
    if not isinstance(animations, list) or not animations:
        raise ValueError("Config must include at least one animation.")

    cleaned = {
        "enabled": bool(config.get("enabled", True)),
        "mode": config.get("mode", "random") if config.get("mode") in {"random", "single"} else "random",
        "selectedAnimation": str(config.get("selectedAnimation", "terrarium")),
        "animations": [],
    }

    seen = set()
    for animation in animations:
        if not isinstance(animation, dict):
            raise ValueError("Each animation must be an object.")

        name = str(animation.get("name", ""))
        if name not in ANIMATION_NAMES:
            raise ValueError(f"Unknown animation: {name}")
        if name in seen:
            raise ValueError(f"Duplicate animation: {name}")
        seen.add(name)

        try:
            weight = int(animation.get("weight", 1))
        except (TypeError, ValueError) as exc:
            raise ValueError(f"Invalid weight for {name}") from exc

        params = animation.get("params", {})
        if not isinstance(params, dict):
            raise ValueError(f"Params for {name} must be an object.")

        cleaned["animations"].append({
            "name": name,
            "enabled": bool(animation.get("enabled", True)),
            "weight": max(0, weight),
            "params": params,
        })

    if cleaned["selectedAnimation"] not in seen:
        cleaned["selectedAnimation"] = cleaned["animations"][0]["name"]

    return cleaned


def write_config(config):
    USER_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp_file = USER_CONFIG_FILE.with_suffix(".json.tmp")
    with tmp_file.open("w", encoding="utf-8") as config_file:
        json.dump(config, config_file, indent=2)
        config_file.write("\n")
    tmp_file.replace(USER_CONFIG_FILE)


def launch_chromium(url):
    PROFILE_DIR.mkdir(parents=True, exist_ok=True)
    candidates = ["chromium", "google-chrome", "google-chrome-stable"]
    browser = next((candidate for candidate in candidates if shutil_which(candidate)), None)
    if browser is None:
        raise RuntimeError("Could not find chromium or google-chrome.")

    return subprocess.Popen([
        browser,
        f"--user-data-dir={PROFILE_DIR}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-extensions",
        "--disable-background-networking",
        "--disable-sync",
        "--disable-translate",
        url,
    ])


def shutil_which(command):
    for path in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(path) / command
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def main():
    if not UI_FILE.exists():
        print(f"Missing UI file: {UI_FILE}", file=sys.stderr)
        return 1

    server = ThreadingHTTPServer(("127.0.0.1", 0), ConfigHandler)
    host, port = server.server_address
    url = f"http://{host}:{port}/"
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    print(f"Opening ASCII screensaver config at {url}")
    browser_process = None

    def stop(_signum=None, _frame=None):
        if browser_process and browser_process.poll() is None:
            browser_process.terminate()
        server.shutdown()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    try:
        browser_process = launch_chromium(url)
        browser_process.wait()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    finally:
        server.shutdown()
        server.server_close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
