"""
Window & Active Process Detector
Supports Wayland (GNOME Shell Extension), XWayland (xdotool), and Process Scanner (/proc)
"""

import os
import glob
import json
import subprocess
from typing import Optional, Dict, Any

def get_focused_window_gnome_ext() -> Optional[Dict[str, Any]]:
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

        if result.startswith("('") and result.endswith("',)"):
            json_str = result[2:-3]
        elif result.startswith('("') and result.endswith('",)'):
            json_str = result[2:-3]
        else:
            json_str = result.strip("() ',")

        data = json.loads(json_str)
        if data.get("title") or data.get("wmClass"):
            return data
    except Exception:
        pass
    return None


def get_focused_window_xdotool() -> Optional[Dict[str, Any]]:
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

        wm_class = ""
        try:
            xprop_out = subprocess.check_output(
                ["xprop", "-id", wid, "WM_CLASS"],
                stderr=subprocess.DEVNULL,
                timeout=3,
            ).decode("utf-8").strip()
            if "=" in xprop_out:
                parts = xprop_out.split("=", 1)[1].strip()
                classes = [c.strip().strip('"') for c in parts.split(",")]
                wm_class = classes[-1] if classes else ""
        except Exception:
            pass

        pid = 0
        try:
            pid = int(subprocess.check_output(
                ["xdotool", "getwindowpid", wid],
                stderr=subprocess.DEVNULL,
                timeout=3,
            ).decode("utf-8").strip())
        except Exception:
            pass

        if title:
            return {"title": title, "wmClass": wm_class, "pid": pid}
    except Exception:
        pass
    return None


def get_focused_window_process_fallback() -> Optional[Dict[str, Any]]:
    """
    Process Scanner Fallback:
    Scans /proc for active dev tools with strict precedence rules:
    - Antigravity MUST be checked before VSCode (Antigravity is built on VSCode binaries).
    - Terminal checks gnome-terminal-server, bash, zsh, kitty, alacritty and reads cwd.
    """
    try:
        # Priority app specs: (search_token, human_name, category)
        app_specs = [
            ("antigravity", "Antigravity", "work"),
            ("android-studio", "Android Studio", "work"),
            ("cursor", "Cursor", "work"),
            ("pycharm", "PyCharm", "work"),
            ("code", "VSCode", "work"),  # Checked AFTER antigravity!
            ("gnome-terminal", "Terminal", "work"),
            ("kitty", "Kitty", "work"),
            ("alacritty", "Alacritty", "work"),
            ("docker", "Docker", "work"),
            ("brave-browser", "Brave", "browsing"),
            ("brave", "Brave", "browsing"),
            ("google-chrome", "Chrome", "browsing"),
            ("chrome", "Chrome", "browsing"),
            ("firefox", "Firefox", "browsing"),
        ]

        candidates = []
        for p_path in glob.glob("/proc/[0-9]*/cmdline"):
            try:
                with open(p_path, "rb") as f:
                    cmd = f.read().decode("utf-8", errors="ignore").replace("\x00", " ").strip()
                    cmd_lower = cmd.lower()

                if not cmd or "nucleus_daemon" in cmd_lower or ("python" in cmd_lower and "daemon" in cmd_lower):
                    continue

                # Skip Electron/Chromium helper subprocesses — they share binaries
                # across Docker Desktop, VSCode, Chrome, Brave etc. and cause mismatches
                if "/proc/self/exe" in cmd or any(f"--type={t}" in cmd_lower for t in
                        ("utility", "renderer", "gpu-process", "zygote", "crashpad-handler", "broker")):
                    continue

                pid = int(p_path.split("/")[2])

                # EXPLICIT ANTIGRAVITY FIX: If antigravity is in path, FORCE app to Antigravity!
                if "antigravity" in cmd_lower or "/opt/antigravity-ide" in cmd_lower:
                    stat_file = f"/proc/{pid}/stat"
                    mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                    title = "Antigravity — Active Work Session"
                    candidates.append((mtime, "Antigravity", title, pid))
                    continue

                # EXPLICIT ANDROID STUDIO FIX: Only match actual IDE studio.sh / studio64, not ADB / Gradle
                if ("studio.sh" in cmd_lower or "studio64" in cmd_lower or "bin/studio" in cmd_lower) and not "platform-tools" in cmd_lower:
                    stat_file = f"/proc/{pid}/stat"
                    mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                    candidates.append((mtime, "Android Studio", "Android Studio — IDE Session", pid))
                    continue

                # EXPLICIT DOCKER FIX: Match Docker Desktop, docker compose, or container engine
                if any(d in cmd_lower for d in ["docker-desktop", "docker compose", "docker-compose", "dockerd"]):
                    stat_file = f"/proc/{pid}/stat"
                    mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                    candidates.append((mtime, "Docker", "Docker Container Engine — Development", pid))
                    continue

                # EXPLICIT BRAVE BROWSER FIX: Match Brave browser before Chrome
                if any(b in cmd_lower for b in ["brave-browser", "brave.com", "/brave"]):
                    stat_file = f"/proc/{pid}/stat"
                    mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                    candidates.append((mtime, "Brave", "Brave — Web Browsing & Research", pid))
                    continue

                # EXPLICIT TERMINAL FIX: Check for gnome-terminal-server, bash, or zsh
                if any(t in cmd_lower for t in ["gnome-terminal", "terminal-server", "kitty", "alacritty"]):
                    stat_file = f"/proc/{pid}/stat"
                    mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                    
                    cwd_title = "Terminal Session"
                    try:
                        cwd_link = os.readlink(f"/proc/{pid}/cwd")
                        folder_name = os.path.basename(cwd_link)
                        if folder_name and folder_name != os.path.expanduser("~"):
                            cwd_title = f"Terminal — {folder_name}"
                    except Exception:
                        pass
                        
                    candidates.append((mtime, "Terminal", cwd_title, pid))
                    continue

                # Check general app specs
                for key, name, cat in app_specs:
                    if key in cmd_lower:
                        stat_file = f"/proc/{pid}/stat"
                        mtime = os.path.getmtime(stat_file) if os.path.exists(stat_file) else 0.0
                        title = f"{name} — Active Work Session"
                        candidates.append((mtime, name, title, pid))
                        break
            except Exception:
                pass

        if candidates:
            # Sort candidates by mtime (most recently active process wins)
            candidates.sort(key=lambda x: x[0], reverse=True)
            best_mtime, best_name, best_title, best_pid = candidates[0]
            return {"title": best_title, "wmClass": best_name, "pid": best_pid}
    except Exception:
        pass
    return None


def get_focused_window() -> Dict[str, Any]:
    """Get focused window info using the best available method."""
    # Try GNOME extension first (native Wayland)
    result = get_focused_window_gnome_ext()
    if result and (result.get("title") or result.get("wmClass")):
        return result

    # Try xdotool (XWayland)
    result = get_focused_window_xdotool()
    if result and result.get("title"):
        return result

    # Fallback to process scanner (/proc)
    result = get_focused_window_process_fallback()
    if result:
        return result

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

        for line in result.strip().split("\n"):
            line = line.strip()
            if line.startswith("uint64"):
                return int(line.split()[-1])
    except Exception:
        pass
    return 0
