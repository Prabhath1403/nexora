#!/usr/bin/env python3
"""
Nucleus Laptop Activity Daemon v2
==================================
A production-quality background service that monitors active desktop windows
and automatically logs Work Hours and Learning Hours to the Nucleus Hub.

Works on Ubuntu 24.04 (GNOME 46 + Wayland) using:
  - Primary:  Nucleus GNOME Shell Extension via DBus (org.nucleus.WindowTracker)
  - Fallback: xdotool via XWayland (for Electron apps)
  - Idle:     org.gnome.Mutter.IdleMonitor.GetIdletime via DBus

Architecture:
  1. Every 30 seconds, detect the focused window (title + WM_CLASS + PID)
  2. Classify activity into work / learning / browsing / idle / afk
  3. Extract project context from window title (e.g., "filename — ProjectFolder")
  4. Track session switches (app changed → close old session, start new)
  5. Post heartbeat pings to Nucleus API
"""

import sys
import os
import time
import subprocess
import json
import urllib.request
import urllib.error
import signal
import logging
from pathlib import Path
from datetime import datetime

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

NUCLEUS_API_URL = os.environ.get(
    "NUCLEUS_API_URL", "http://localhost:8000/api/v1/tracker/ping"
)
PING_INTERVAL = int(os.environ.get("NUCLEUS_PING_INTERVAL", "30"))
IDLE_THRESHOLD_MS = int(os.environ.get("NUCLEUS_IDLE_THRESHOLD_MS", "180000"))       # 3 min
AFK_THRESHOLD_MS = int(os.environ.get("NUCLEUS_AFK_THRESHOLD_MS", "600000"))         # 10 min

LOG_DIR = Path.home() / ".local" / "share" / "nucleus-daemon"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "daemon.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("nucleus-daemon")

# ---------------------------------------------------------------------------
# Classification Rules
# ---------------------------------------------------------------------------

# WM_CLASS → category mapping (case-insensitive matching)
WORK_APPS = {
    # IDEs & Editors
    "code", "code - oss", "vscodium",
    "antigravity", "antigravity-ide",
    "cursor",
    "jetbrains-idea", "jetbrains-pycharm", "jetbrains-webstorm",
    "jetbrains-clion", "jetbrains-goland", "jetbrains-rider",
    "pycharm", "idea", "webstorm",
    "sublime_text", "subl",
    "emacs", "vim", "neovim", "nvim",
    "android-studio",
    "zed",
    # Terminals
    "gnome-terminal", "gnome-terminal-server",
    "kitty", "alacritty", "terminator", "tilix",
    "wezterm", "foot", "xterm", "konsole",
    "tmux",
    # Dev Tools
    "docker", "docker-desktop",
    "postman", "insomnia",
    "dbeaver", "pgadmin", "datagrip",
    "github desktop", "gitkraken",
    "figma", "figma-linux",
    # Office/Productivity (work-adjacent)
    "slack", "discord", "microsoft teams",
    "obsidian", "notion",
    "thunderbird",
}

LEARNING_APPS = {
    "evince",      # PDF reader (documentation)
    "okular",      # KDE PDF reader
    "zathura",     # Lightweight PDF reader
}

IDLE_APPS = {
    "vlc", "mpv", "totem", "celluloid",       # Video players
    "spotify", "rhythmbox", "audacity",        # Music
    "nautilus", "thunar", "nemo", "dolphin",   # File managers
    "eog", "gthumb", "shotwell",              # Image viewers
    "cheese",                                  # Webcam
    "org.gnome.Calculator",
    "gnome-calculator",
}

# URL/title keywords for browser classification
LEARNING_KEYWORDS = [
    "stackoverflow", "stack overflow",
    "developer.mozilla.org", "mdn web docs",
    "docs.python.org", "doc.rust-lang.org",
    "flutter.dev", "dart.dev", "api.flutter.dev",
    "fastapi.tiangolo.com",
    "developer.apple.com", "developer.android.com",
    "arxiv.org", "arxiv",
    "coursera", "udemy", "edx", "pluralsight",
    "medium.com", "dev.to", "hashnode",
    "wikipedia", "wiki",
    "lecture", "tutorial", "documentation",
    "learn", "course",
    "w3schools", "geeksforgeeks",
    "realpython", "freecodecamp",
]

WORK_KEYWORDS = [
    "github.com", "gitlab.com", "bitbucket.org",
    "pull request", "merge request",
    "issue", "issues",
    "jira", "confluence", "trello",
    "linear", "asana", "clickup",
    "vercel", "netlify", "heroku",
    "aws console", "google cloud", "azure portal",
    "firebase",
    "localhost:", "127.0.0.1:",
]

# Project name keywords to extract from window titles
PROJECT_KEYWORDS = [
    "nucleus", "nexora", "cyphercite", "facial-ai",
    "fraud-controller", "fruad-controller",
]

# ---------------------------------------------------------------------------
# Window Detection (Wayland + XWayland hybrid)
# ---------------------------------------------------------------------------

def get_focused_window_gnome_ext() -> dict | None:
    """Query the Nucleus GNOME Shell Extension via DBus for focused window info."""
    try:
        result = subprocess.check_output(
            [
                "gdbus", "call", "--session",
                "--dest", "org.nucleus.WindowTracker",
                "--object-path", "/org/nucleus/WindowTracker",
                "--method", "org.nucleus.WindowTracker.GetFocusedWindow",
            ],
            stderr=subprocess.DEVNULL,
            timeout=3,
        ).decode("utf-8").strip()

        # gdbus returns: ('{"title":"...","wmClass":"...","pid":123}',)
        # Extract the JSON string from the tuple notation
        if result.startswith("('") and result.endswith("',)"):
            json_str = result[2:-3]
        elif result.startswith('("') and result.endswith('",)'):
            json_str = result[2:-3]
        else:
            json_str = result.strip("() ',")

        data = json.loads(json_str)
        if data.get("title") or data.get("wmClass"):
            return data
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
        pass
    return None


def get_focused_window_xdotool() -> dict | None:
    """Fallback: use xdotool via XWayland for Electron/X11 apps."""
    try:
        wid = subprocess.check_output(
            ["xdotool", "getactivewindow"],
            stderr=subprocess.DEVNULL,
            timeout=3,
        ).decode("utf-8").strip()

        title = subprocess.check_output(
            ["xdotool", "getwindowname", wid],
            stderr=subprocess.DEVNULL,
            timeout=3,
        ).decode("utf-8").strip()

        # Get WM_CLASS via xprop
        wm_class = ""
        try:
            xprop_out = subprocess.check_output(
                ["xprop", "-id", wid, "WM_CLASS"],
                stderr=subprocess.DEVNULL,
                timeout=3,
            ).decode("utf-8").strip()
            # Format: WM_CLASS(STRING) = "instance", "class"
            if "=" in xprop_out:
                parts = xprop_out.split("=", 1)[1].strip()
                classes = [c.strip().strip('"') for c in parts.split(",")]
                wm_class = classes[-1] if classes else ""
        except (subprocess.SubprocessError, OSError):
            pass

        # Get PID
        pid = 0
        try:
            pid = int(subprocess.check_output(
                ["xdotool", "getwindowpid", wid],
                stderr=subprocess.DEVNULL,
                timeout=3,
            ).decode("utf-8").strip())
        except (subprocess.SubprocessError, ValueError, OSError):
            pass

        if title:
            return {"title": title, "wmClass": wm_class, "pid": pid}
    except (subprocess.SubprocessError, OSError):
        pass
    return None


def get_focused_window_process_fallback() -> dict | None:
    """Fallback: Scan /proc for active dev tools (Antigravity, VSCode, Terminal, Docker, Chrome, Brave, etc.) sorted by active CPU/time."""
    try:
        import glob
        import os

        app_specs = [
            ("antigravity", "Antigravity", "work"),
            ("code", "VSCode", "work"),
            ("cursor", "Cursor", "work"),
            ("pycharm", "PyCharm", "work"),
            ("android-studio", "Android Studio", "work"),
            ("docker", "Docker", "work"),
            ("gnome-terminal", "Terminal", "work"),
            ("kitty", "Kitty", "work"),
            ("alacritty", "Alacritty", "work"),
            ("chrome", "Chrome", "browsing"),
            ("firefox", "Firefox", "browsing"),
            ("brave", "Brave", "browsing"),
        ]

        candidates = []
        for p_path in glob.glob("/proc/[0-9]*/cmdline"):
            try:
                with open(p_path, "rb") as f:
                    cmd = f.read().decode("utf-8", errors="ignore").replace("\x00", " ").strip()
                    cmd_lower = cmd.lower()

                if not cmd or "nucleus_daemon" in cmd_lower or ("python" in cmd_lower and "daemon" in cmd_lower):
                    continue

                for key, name, cat in app_specs:
                    if key in cmd_lower:
                        pid = int(p_path.split("/")[2])
                        stat_file = f"/proc/{pid}/stat"
                        mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                        candidates.append((mtime, name, cmd, pid))
                        break
            except Exception:
                pass

        if candidates:
            # Sort candidates by mtime (most recently active process wins!)
            candidates.sort(key=lambda x: x[0], reverse=True)
            best_mtime, best_name, best_cmd, best_pid = candidates[0]
            
            # Format title nicely
            if "nucleus" in best_cmd.lower():
                title = "Nucleus Project — Terminal/IDE"
            else:
                title = f"{best_name} — Active Work Session"
                
            return {"title": title, "wmClass": best_name, "pid": best_pid}
    except Exception:
        pass
    return None


def get_focused_window() -> dict:
    """Get focused window info using the best available method."""
    # Try GNOME extension first (native Wayland)
    result = get_focused_window_gnome_ext()
    if result:
        return result

    # Fallback to xdotool (XWayland)
    result = get_focused_window_xdotool()
    if result:
        return result

    # Fallback to process scanner (/proc)
    result = get_focused_window_process_fallback()
    if result:
        return result

    # No window detected
    return {"title": "", "wmClass": "", "pid": 0}


def get_idle_time_ms() -> int:
    """Get user idle time in milliseconds via GNOME Mutter IdleMonitor."""
    try:
        result = subprocess.check_output(
            [
                "dbus-send", "--print-reply",
                "--dest=org.gnome.Mutter.IdleMonitor",
                "/org/gnome/Mutter/IdleMonitor/Core",
                "org.gnome.Mutter.IdleMonitor.GetIdletime",
            ],
            stderr=subprocess.DEVNULL,
            timeout=3,
        ).decode("utf-8")

        # Parse: "   uint64 12345\n"
        for line in result.strip().split("\n"):
            line = line.strip()
            if line.startswith("uint64"):
                return int(line.split()[-1])
    except (subprocess.SubprocessError, ValueError, OSError):
        pass
    return 0

# ---------------------------------------------------------------------------
# Classification Engine
# ---------------------------------------------------------------------------

def classify_activity(wm_class: str, title: str, idle_ms: int) -> str:
    """
    Classify the current activity into a category.
    Priority: afk > idle > learning > work > browsing > idle
    """
    # Check idle / AFK first
    if idle_ms >= AFK_THRESHOLD_MS:
        return "afk"
    if idle_ms >= IDLE_THRESHOLD_MS:
        return "idle"

    wm_lower = wm_class.lower().strip()
    title_lower = title.lower()

    # Check if it's a known idle app
    if wm_lower in IDLE_APPS or any(app in wm_lower for app in IDLE_APPS):
        return "idle"

    # Check if it's a known work app
    if wm_lower in WORK_APPS or any(app in wm_lower for app in WORK_APPS):
        # Special case: terminal — classify based on title content
        if any(term in wm_lower for term in ("terminal", "kitty", "alacritty", "tilix", "wezterm", "foot", "konsole")):
            # If terminal title has learning keywords, classify as learning
            for kw in LEARNING_KEYWORDS:
                if kw in title_lower:
                    return "learning"
        return "work"

    # Check if it's a known learning app
    if wm_lower in LEARNING_APPS or any(app in wm_lower for app in LEARNING_APPS):
        return "learning"

    # Browser classification — depends on the page title/URL
    if any(browser in wm_lower for browser in ("chrome", "chromium", "firefox", "brave", "edge", "opera", "vivaldi", "epiphany", "webkit")):
        # Check learning keywords in title
        for kw in LEARNING_KEYWORDS:
            if kw in title_lower:
                return "learning"
        # Check work keywords in title
        for kw in WORK_KEYWORDS:
            if kw in title_lower:
                return "work"
        # Default browser activity is browsing
        return "browsing"

    # Unknown app — default to work if any title suggests it
    for kw in WORK_KEYWORDS:
        if kw in title_lower:
            return "work"
    for kw in LEARNING_KEYWORDS:
        if kw in title_lower:
            return "learning"

    # Truly unknown
    return "idle"


def extract_project_hint(wm_class: str, title: str) -> str:
    """
    Extract project name from the window title.
    
    Common patterns:
    - VSCode/Antigravity: "filename.py — ProjectFolder"  or  "filename.py - ProjectFolder — Visual Studio Code"
    - Terminal: "user@host: ~/projects/nucleus"
    - Browser: "Pull Request #42 · Prabhath1403/nucleus — GitHub"
    """
    title_lower = title.lower()

    # Check for known project keywords
    for project in PROJECT_KEYWORDS:
        if project in title_lower:
            return project

    wm_lower = wm_class.lower()

    # IDE pattern: "file — FolderName" or "file - FolderName — IDE Name"
    if any(ide in wm_lower for ide in ("code", "antigravity", "cursor", "pycharm", "idea", "sublime")):
        # Try "— FolderName" pattern (em-dash)
        if " — " in title:
            parts = title.split(" — ")
            if len(parts) >= 2:
                # The folder name is usually the second-to-last segment
                folder = parts[-2].strip() if len(parts) > 2 else parts[-1].strip()
                # Remove common IDE suffixes
                for suffix in ("Visual Studio Code", "VS Code", "Antigravity", "Cursor", "PyCharm"):
                    folder = folder.replace(suffix, "").strip(" —-")
                if folder and len(folder) < 60:
                    return folder.lower().replace(" ", "-")

        # Try "- FolderName" pattern (hyphen)
        if " - " in title:
            parts = title.split(" - ")
            if len(parts) >= 2:
                folder = parts[-2].strip() if len(parts) > 2 else parts[-1].strip()
                for suffix in ("Visual Studio Code", "VS Code", "Antigravity", "Cursor", "PyCharm"):
                    folder = folder.replace(suffix, "").strip(" -")
                if folder and len(folder) < 60:
                    return folder.lower().replace(" ", "-")

    # Terminal pattern: "user@host: ~/projects/projectname"
    if any(term in wm_lower for term in ("terminal", "kitty", "alacritty", "tilix", "wezterm")):
        if "~/projects/" in title:
            parts = title.split("~/projects/")
            if len(parts) > 1:
                project = parts[1].split("/")[0].split(" ")[0].strip()
                if project:
                    return project.lower()
        if "/projects/" in title:
            parts = title.split("/projects/")
            if len(parts) > 1:
                project = parts[1].split("/")[0].split(" ")[0].strip()
                if project:
                    return project.lower()

    # GitHub browser pattern: "... · User/RepoName"
    if "github" in title_lower and "·" in title:
        parts = title.split("·")
        for part in parts:
            part = part.strip()
            if "/" in part and len(part.split("/")) == 2:
                repo = part.split("/")[-1].strip()
                if repo and " " not in repo:
                    return repo.lower()

    return ""

# ---------------------------------------------------------------------------
# Session Tracker
# ---------------------------------------------------------------------------

class SessionTracker:
    """Tracks app/project sessions and detects switches."""

    def __init__(self):
        self.current_app = ""
        self.current_project = ""
        self.current_category = ""
        self.session_start = time.time()
        self.last_ping_time = time.time()

    def update(self, app: str, project: str, category: str) -> bool:
        """Update current session. Returns True if session changed."""
        changed = (app != self.current_app or project != self.current_project)
        if changed:
            self.current_app = app
            self.current_project = project
            self.session_start = time.time()
        self.current_category = category
        self.last_ping_time = time.time()
        return changed

    @property
    def session_duration_seconds(self) -> int:
        return int(time.time() - self.session_start)

# ---------------------------------------------------------------------------
# API Communication
# ---------------------------------------------------------------------------

def send_ping(
    window_title: str,
    app_name: str,
    app_class: str,
    category: str,
    project_hint: str,
    idle_ms: int,
    duration_seconds: int = PING_INTERVAL,
):
    """Send heartbeat ping to Nucleus backend."""
    payload = json.dumps({
        "window_title": window_title[:500],
        "app_name": app_name[:255],
        "app_class": app_class[:255],
        "category": category,
        "duration_seconds": duration_seconds,
        "project_hint": project_hint[:255],
        "idle_ms": idle_ms,
    }).encode("utf-8")

    req = urllib.request.Request(
        NUCLEUS_API_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                icon = {"work": "🔨", "learning": "📚", "browsing": "🌐", "idle": "💤", "afk": "🚶"}.get(category, "❓")
                app_display = app_name or app_class or "Unknown"
                log.info(f"{icon} {category.upper():8s} │ {app_display:20s} │ {project_hint or '-':15s} │ {window_title[:50]}")
    except urllib.error.URLError as e:
        log.warning(f"API unreachable: {e.reason}")
    except Exception as e:
        log.warning(f"Ping error: {e}")

# ---------------------------------------------------------------------------
# Main Loop
# ---------------------------------------------------------------------------

def main():
    log.info("=" * 60)
    log.info("🧬 Nucleus Laptop Activity Daemon v2")
    log.info(f"📡 API: {NUCLEUS_API_URL}")
    log.info(f"⏱️  Interval: {PING_INTERVAL}s | Idle: {IDLE_THRESHOLD_MS/1000:.0f}s | AFK: {AFK_THRESHOLD_MS/1000:.0f}s")
    log.info(f"📂 Logs: {LOG_DIR / 'daemon.log'}")
    log.info("=" * 60)

    # Detect available window detection method
    gnome_ext_available = get_focused_window_gnome_ext() is not None
    xdotool_available = subprocess.run(
        ["which", "xdotool"], capture_output=True
    ).returncode == 0

    if gnome_ext_available:
        log.info("✅ Window detection: Nucleus GNOME Extension (native Wayland)")
    elif xdotool_available:
        log.info("⚠️  Window detection: xdotool via XWayland (fallback)")
    else:
        log.warning("❌ No window detection available! Install the GNOME extension or xdotool.")
        log.info("   Run: nucleus/backend/scripts/install_daemon.sh")

    session = SessionTracker()

    # Graceful shutdown
    def handle_signal(sig, frame):
        log.info("🛑 Daemon stopped.")
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    while True:
        try:
            # 1. Get idle time
            idle_ms = get_idle_time_ms()

            # 2. Get focused window info
            window = get_focused_window()
            title = window.get("title", "")
            wm_class = window.get("wmClass", "")
            pid = window.get("pid", 0)

            # 3. Classify activity
            category = classify_activity(wm_class, title, idle_ms)

            # 4. Extract project hint
            project_hint = extract_project_hint(wm_class, title)

            # 5. Determine app name (human-readable)
            app_name = _humanize_app_name(wm_class, title)

            # 6. Update session tracker
            session.update(app_name, project_hint, category)

            # 7. Send ping to backend
            send_ping(
                window_title=title,
                app_name=app_name,
                app_class=wm_class,
                category=category,
                project_hint=project_hint,
                idle_ms=idle_ms,
            )

        except Exception as e:
            log.error(f"Loop error: {e}")

        time.sleep(PING_INTERVAL)


def _humanize_app_name(wm_class: str, title: str) -> str:
    """Convert WM_CLASS to a human-readable app name."""
    wm_lower = wm_class.lower().strip()

    name_map = {
        "code": "VSCode",
        "code - oss": "VSCode OSS",
        "vscodium": "VSCodium",
        "antigravity": "Antigravity",
        "antigravity-ide": "Antigravity",
        "cursor": "Cursor",
        "jetbrains-pycharm": "PyCharm",
        "jetbrains-idea": "IntelliJ IDEA",
        "jetbrains-webstorm": "WebStorm",
        "jetbrains-clion": "CLion",
        "pycharm": "PyCharm",
        "idea": "IntelliJ IDEA",
        "sublime_text": "Sublime Text",
        "android-studio": "Android Studio",
        "zed": "Zed",
        "gnome-terminal": "Terminal",
        "gnome-terminal-server": "Terminal",
        "kitty": "Kitty",
        "alacritty": "Alacritty",
        "terminator": "Terminator",
        "tilix": "Tilix",
        "wezterm": "WezTerm",
        "konsole": "Konsole",
        "google-chrome": "Chrome",
        "chromium": "Chromium",
        "firefox": "Firefox",
        "brave-browser": "Brave",
        "microsoft-edge": "Edge",
        "opera": "Opera",
        "vivaldi": "Vivaldi",
        "slack": "Slack",
        "discord": "Discord",
        "obsidian": "Obsidian",
        "notion": "Notion",
        "figma": "Figma",
        "figma-linux": "Figma",
        "postman": "Postman",
        "insomnia": "Insomnia",
        "dbeaver": "DBeaver",
        "spotify": "Spotify",
        "vlc": "VLC",
        "nautilus": "Files",
        "evince": "Document Viewer",
        "thunderbird": "Thunderbird",
        "docker-desktop": "Docker Desktop",
        "gitkraken": "GitKraken",
    }

    # Exact match
    if wm_lower in name_map:
        return name_map[wm_lower]

    # Partial match
    for key, name in name_map.items():
        if key in wm_lower:
            return name

    # Use WM_CLASS as-is if available
    if wm_class:
        return wm_class

    # Extract from title as last resort
    if title:
        return title.split(" — ")[-1].split(" - ")[-1].strip()[:30]

    return "Unknown"


if __name__ == "__main__":
    main()
