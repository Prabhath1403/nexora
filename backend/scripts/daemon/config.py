"""
Daemon Configuration & Classification Rules
"""

import os
from pathlib import Path

# API & Timers
NUCLEUS_API_URL = os.environ.get("NUCLEUS_API_URL", "http://129.159.237.247/api/v1/tracker/ping")
PING_INTERVAL = int(os.environ.get("NUCLEUS_PING_INTERVAL", "30"))
IDLE_THRESHOLD_MS = int(os.environ.get("NUCLEUS_IDLE_THRESHOLD_MS", "180000"))   # 3 min
AFK_THRESHOLD_MS = int(os.environ.get("NUCLEUS_AFK_THRESHOLD_MS", "600000"))     # 10 min

# Logging Directory
LOG_DIR = Path.home() / ".local" / "share" / "nucleus-daemon"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Work Applications (Top priority matches first)
WORK_APPS = {
    # IDEs & Editors
    "antigravity", "antigravity-ide",
    "code", "code - oss", "vscodium",
    "cursor",
    "jetbrains-idea", "jetbrains-pycharm", "jetbrains-webstorm",
    "jetbrains-clion", "jetbrains-goland", "jetbrains-rider",
    "pycharm", "idea", "webstorm",
    "sublime_text", "subl",
    "emacs", "vim", "neovim", "nvim",
    "android-studio",
    "zed",
    # Terminals (Ubuntu GNOME Wayland uses org.gnome.Terminal)
    "gnome-terminal", "gnome-terminal-server", "gnome-terminal.real",
    "org.gnome.terminal", "org.gnome.terminal.desktop", "terminal",
    "kitty", "alacritty", "terminator", "tilix",
    "wezterm", "foot", "xterm", "konsole",
    "tmux", "bash", "zsh",
    # Dev Tools
    "docker", "docker-desktop",
    "postman", "insomnia",
    "dbeaver", "pgadmin", "datagrip",
    "github desktop", "gitkraken",
    "figma", "figma-linux",
    "slack", "discord", "microsoft teams",
    "obsidian", "notion",
    "thunderbird",
}

LEARNING_APPS = {
    "evince", "okular", "zathura",
}

MEDIA_APPS = {
    "spotify", "rhythmbox", "audacity",
}

IDLE_APPS = {
    "vlc", "mpv", "totem", "celluloid",
    "nautilus", "thunar", "nemo", "dolphin",
    "eog", "gthumb", "shotwell",
    "cheese", "gnome-calculator",
}

LEARNING_KEYWORDS = [
    "claude", "claude.ai", "chatgpt", "chat.openai.com",
    "gemini", "gemini.google.com", "perplexity", "anthropic",
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
    "claude", "claude.ai", "chatgpt", "chat.openai.com",
    "gemini", "gemini.google.com", "perplexity", "anthropic",
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

PROJECT_KEYWORDS = [
    "nucleus", "nexora", "cyphercite", "facial-ai",
    "fraud-controller", "fruad-controller",
    "claude", "ai-assistant",
]
