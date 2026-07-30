"""
Main Daemon Entrypoint & Event Loop
"""

import sys
import time
import signal
import logging
from pathlib import Path

from .config import (
    NUCLEUS_API_URL, PING_INTERVAL,
    IDLE_THRESHOLD_MS, AFK_THRESHOLD_MS, LOG_DIR
)
from .window_detector import get_focused_window, get_idle_time_ms
from .classifier import classify_activity, extract_project_hint, humanize_app_name
from .session_tracker import SessionTracker
from .api_client import send_ping

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


def run_daemon():
    log.info("=" * 60)
    log.info("🧬 Nucleus Laptop Activity Daemon v2.1")
    log.info(f"📡 API: {NUCLEUS_API_URL}")
    log.info(f"⏱️  Interval: {PING_INTERVAL}s | Idle: {IDLE_THRESHOLD_MS/1000:.0f}s | AFK: {AFK_THRESHOLD_MS/1000:.0f}s")
    log.info(f"📂 Logs: {LOG_DIR / 'daemon.log'}")
    log.info("=" * 60)

    session = SessionTracker()

    def handle_signal(sig, frame):
        log.info("🛑 Daemon stopped.")
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    while True:
        try:
            idle_ms = get_idle_time_ms()
            window = get_focused_window()
            title = window.get("title", "")
            wm_class = window.get("wmClass", "")

            category = classify_activity(wm_class, title, idle_ms)
            project_hint = extract_project_hint(wm_class, title)
            app_name = humanize_app_name(wm_class, title)

            session.update(app_name, project_hint, category)

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


if __name__ == "__main__":
    run_daemon()
