"""
Activity Classifier & Project Context Extractor
"""

from typing import Tuple
from .config import (
    WORK_APPS, LEARNING_APPS, IDLE_APPS,
    LEARNING_KEYWORDS, WORK_KEYWORDS, PROJECT_KEYWORDS,
    AFK_THRESHOLD_MS, IDLE_THRESHOLD_MS
)

def classify_activity(wm_class: str, title: str, idle_ms: int) -> str:
    """
    Classify the current activity into a category.
    Priority: afk > idle > learning > work > browsing > idle
    """
    if idle_ms >= AFK_THRESHOLD_MS:
        return "afk"
    if idle_ms >= IDLE_THRESHOLD_MS:
        return "idle"

    wm_lower = wm_class.lower().strip()
    title_lower = title.lower()

    # Check idle app
    if wm_lower in IDLE_APPS or any(app in wm_lower for app in IDLE_APPS):
        return "idle"

    # Check work app
    if wm_lower in WORK_APPS or any(app in wm_lower for app in WORK_APPS):
        if any(term in wm_lower for term in ("terminal", "kitty", "alacritty", "tilix", "wezterm", "foot", "konsole")):
            for kw in LEARNING_KEYWORDS:
                if kw in title_lower:
                    return "learning"
        return "work"

    # Check learning app
    if wm_lower in LEARNING_APPS or any(app in wm_lower for app in LEARNING_APPS):
        return "learning"

    # Browser classification
    if any(b in wm_lower for b in ("chrome", "chromium", "firefox", "brave", "edge", "opera", "vivaldi")):
        for kw in LEARNING_KEYWORDS:
            if kw in title_lower:
                return "learning"
        for kw in WORK_KEYWORDS:
            if kw in title_lower:
                return "work"
        return "browsing"

    for kw in WORK_KEYWORDS:
        if kw in title_lower:
            return "work"
    for kw in LEARNING_KEYWORDS:
        if kw in title_lower:
            return "learning"

    return "idle"


def extract_project_hint(wm_class: str, title: str) -> str:
    """Extract project folder name from window title or path."""
    title_lower = title.lower()

    for project in PROJECT_KEYWORDS:
        if project in title_lower:
            return project

    wm_lower = wm_class.lower()

    if any(ide in wm_lower for ide in ("code", "antigravity", "cursor", "pycharm", "idea", "sublime")):
        if " — " in title:
            parts = title.split(" — ")
            if len(parts) >= 2:
                folder = parts[-2].strip() if len(parts) > 2 else parts[-1].strip()
                for suffix in ("Visual Studio Code", "VS Code", "Antigravity", "Cursor", "PyCharm"):
                    folder = folder.replace(suffix, "").strip(" —-")
                if folder and len(folder) < 60:
                    return folder.lower().replace(" ", "-")

        if " - " in title:
            parts = title.split(" - ")
            ide_names = ("visual studio code", "vs code", "antigravity ide", "antigravity",
                         "cursor", "pycharm", "intellij idea", "sublime text")
            # Find the first part that looks like a project name (not an IDE or file name)
            for part in parts:
                cleaned = part.strip()
                if not cleaned:
                    continue
                if cleaned.lower() in ide_names:
                    continue
                # Skip if it looks like a file name (has extension)
                if "." in cleaned and len(cleaned.split(".")[-1]) <= 4:
                    continue
                # This is likely the project name
                if len(cleaned) < 60:
                    return cleaned.lower().replace(" ", "-")
            # Fallback: use first part
            if len(parts) >= 2:
                folder = parts[0].strip()
                for suffix in ("Visual Studio Code", "VS Code", "Antigravity IDE", "Antigravity", "Cursor", "PyCharm"):
                    folder = folder.replace(suffix, "").strip(" -")
                if folder and len(folder) < 60:
                    return folder.lower().replace(" ", "-")

    if any(term in wm_lower for term in ("terminal", "kitty", "alacritty", "tilix")):
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

    if "github" in title_lower and "·" in title:
        parts = title.split("·")
        for part in parts:
            part = part.strip()
            if "/" in part and len(part.split("/")) == 2:
                repo = part.split("/")[-1].strip()
                if repo and " " not in repo:
                    return repo.lower()

    return ""


def humanize_app_name(wm_class: str, title: str) -> str:
    """Convert WM_CLASS or title to a clean human-readable app name."""
    wm_lower = wm_class.lower().strip()

    # STRICT MATCH FOR ANTIGRAVITY
    if "antigravity" in wm_lower or "antigravity" in title.lower():
        return "Antigravity"

    name_map = {
        "code": "VSCode",
        "code - oss": "VSCode OSS",
        "vscodium": "VSCodium",
        "cursor": "Cursor",
        "jetbrains-pycharm": "PyCharm",
        "jetbrains-idea": "IntelliJ IDEA",
        "sublime_text": "Sublime Text",
        "android-studio": "Android Studio",
        "gnome-terminal": "Terminal",
        "gnome-terminal-server": "Terminal",
        "kitty": "Kitty",
        "alacritty": "Alacritty",
        "google-chrome": "Chrome",
        "chromium": "Chromium",
        "firefox": "Firefox",
        "brave": "Brave",
        "brave-browser": "Brave",
        "docker-desktop": "Docker",
        "docker": "Docker",
        "slack": "Slack",
        "discord": "Discord",
        "obsidian": "Obsidian",
        "vlc": "VLC",
        "nautilus": "Files",
    }

    if wm_lower in name_map:
        return name_map[wm_lower]

    for key, name in name_map.items():
        if key in wm_lower:
            return name

    if wm_class:
        return wm_class

    return "Unknown"
