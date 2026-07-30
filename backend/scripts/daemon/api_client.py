"""
API Client — Posts heartbeats to Nucleus Backend
"""

import json
import logging
import urllib.request
import urllib.error
from .config import NUCLEUS_API_URL, PING_INTERVAL

log = logging.getLogger("nucleus-daemon")

def send_ping(
    window_title: str,
    app_name: str,
    app_class: str,
    category: str,
    project_hint: str,
    idle_ms: int,
    duration_seconds: int = PING_INTERVAL,
) -> bool:
    """Send heartbeat ping to Nucleus backend API."""
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
                return True
    except urllib.error.URLError as e:
        log.warning(f"API unreachable ({NUCLEUS_API_URL}): {e.reason}")
    except Exception as e:
        log.warning(f"Ping error: {e}")
    return False
