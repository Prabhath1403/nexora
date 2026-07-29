#!/usr/bin/env python3
"""
Nucleus Laptop Activity Daemon
===============================
A lightweight background service that monitors your active desktop window
and automatically logs Work Hours and Learning Hours to your Nucleus Hub.

How it works:
1. Every 30 seconds, fetches active window title via xdotool.
2. Matches window title and application against work/learning keywords:
   - Work: IDEs (VSCode, Antigravity, Cursor, PyCharm), terminal projects (nucleus, cyphercite), GitHub.
   - Learning: Documentation sites (doc.rust-lang.org, developer.apple.com, stackoverflow, arxiv, tech YouTube).
3. Posts ping to Nucleus API: http://localhost:8000/api/v1/tracker/ping
"""

import sys
import time
import subprocess
import json
import urllib.request
import urllib.error

NUCLEUS_API_URL = "http://localhost:8000/api/v1/tracker/ping"
PING_INTERVAL_SECONDS = 30

# Keyword rules for automatic category classification
WORK_KEYWORDS = [
    "antigravity", "vscode", "visual studio code", "cursor", "pycharm",
    "nucleus", "cyphercite", "terminal", "bash", "zsh", "git",
    "flutter", "fastapi", "docker", "postgres", "redis"
]

LEARNING_KEYWORDS = [
    "doc.rust-lang.org", "developer.apple.com", "developer.mozilla.org",
    "stackoverflow", "arxiv", "medium.com", "dev.to", "docs.python.org",
    "flutter.dev", "fastapi.tiangolo.com", "wiki", "lecture", "tutorial", "coursera"
]

def get_active_window_title() -> tuple[str, str]:
    """Retrieve current active window title and app name using xdotool."""
    try:
        window_id = subprocess.check_output(
            ["xdotool", "getactivewindow"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        window_title = subprocess.check_output(
            ["xdotool", "getwindowname", window_id],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()

        return window_title, "Desktop"
    except Exception:
        return "Unknown Activity", "System"

def classify_activity(window_title: str) -> str:
    """Classify window title into work, learning, or idle."""
    title_lower = window_title.lower()

    # Check learning keywords first
    for kw in LEARNING_KEYWORDS:
        if kw in title_lower:
            return "learning"

    # Check work keywords
    for kw in WORK_KEYWORDS:
        if kw in title_lower:
            return "work"

    # Default to work if coding tools/IDEs are in focus, else work
    return "work"

def send_ping(window_title: str, app_name: str, category: str):
    """Send heartbeat ping to Nucleus backend."""
    payload = json.dumps({
        "window_title": window_title[:200],
        "app_name": app_name,
        "category": category,
        "duration_seconds": PING_INTERVAL_SECONDS
    }).encode("utf-8")

    req = urllib.request.Request(
        NUCLEUS_API_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                print(f"[{time.strftime('%H:%M:%S')}] Pushed {category.upper()} ping: '{window_title[:40]}...'")
    except urllib.error.URLError as e:
        print(f"[{time.strftime('%H:%M:%S')}] Nucleus API unreachable ({e.reason})")

def main():
    print("🧬 Starting Nucleus Laptop Activity Daemon...")
    print(f"📡 Target API: {NUCLEUS_API_URL}")
    print(f"⏱️ Heartbeat interval: {PING_INTERVAL_SECONDS}s\n")

    while True:
        window_title, app_name = get_active_window_title()
        category = classify_activity(window_title)
        send_ping(window_title, app_name, category)
        time.sleep(PING_INTERVAL_SECONDS)

if __name__ == "__main__":
    main()
