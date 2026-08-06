"""
API Client — Posts heartbeats to Nucleus Backend with Offline Buffering
"""

import json
import logging
import urllib.request
import urllib.error
from .config import NUCLEUS_API_URL, PING_INTERVAL, LOG_DIR

log = logging.getLogger("nucleus-daemon")
OFFLINE_QUEUE_FILE = LOG_DIR / "offline_queue.json"


def _load_offline_queue() -> list:
    if OFFLINE_QUEUE_FILE.exists():
        try:
            with open(OFFLINE_QUEUE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def _save_offline_queue(queue: list):
    try:
        # Keep max 500 buffered pings (~4 hours of offline work)
        trimmed = queue[-500:]
        with open(OFFLINE_QUEUE_FILE, "w") as f:
            json.dump(trimmed, f)
    except Exception as e:
        log.warning(f"Failed to save offline queue: {e}")


def _flush_offline_queue():
    queue = _load_offline_queue()
    if not queue:
        return

    log.info(f"🌐 Internet connected! Flushing {len(queue)} offline pings to cloud server...")
    remaining = []
    for item in queue:
        payload = json.dumps(item).encode("utf-8")
        req = urllib.request.Request(
            NUCLEUS_API_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status != 200:
                    remaining.append(item)
        except Exception:
            remaining.append(item)
            break  # Stop flushing if network drops again

    _save_offline_queue(remaining)
    if not remaining:
        log.info("✅ All offline pings flushed to cloud server successfully!")


def send_ping(
    window_title: str,
    app_name: str,
    app_class: str,
    category: str,
    project_hint: str,
    idle_ms: int,
    duration_seconds: int = PING_INTERVAL,
) -> bool:
    """Send heartbeat ping to Nucleus backend API with automatic offline buffering."""
    # Attempt to flush any previously buffered offline pings
    _flush_offline_queue()

    ping_data = {
        "window_title": window_title[:500],
        "app_name": app_name[:255],
        "app_class": app_class[:255],
        "category": category,
        "duration_seconds": duration_seconds,
        "project_hint": project_hint[:255],
        "idle_ms": idle_ms,
    }
    payload = json.dumps(ping_data).encode("utf-8")

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
    except Exception as e:
        log.warning(f"API unreachable ({NUCLEUS_API_URL}). Buffering ping locally... ({e})")
        queue = _load_offline_queue()
        queue.append(ping_data)
        _save_offline_queue(queue)

    return False
