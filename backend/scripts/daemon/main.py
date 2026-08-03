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
from .window_detector import get_focused_window, get_idle_time_ms, get_browser_windows_gnome_ext
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

# Track which browser page titles we've already sent this cycle
# to avoid duplicate pings
_last_browser_titles: set = set()


def run_daemon():
    global _last_browser_titles

    log.info("=" * 60)
    log.info("🧬 Nucleus Laptop Activity Daemon v2.2")
    log.info(f"📡 API: {NUCLEUS_API_URL}")
    log.info(f"⏱️  Interval: {PING_INTERVAL}s | Idle: {IDLE_THRESHOLD_MS/1000:.0f}s | AFK: {AFK_THRESHOLD_MS/1000:.0f}s")
    log.info(f"📂 Logs: {LOG_DIR / 'daemon.log'}")
    log.info("=" * 60)

    session = SessionTracker()
    browser_scan_counter = 0  # Scan browser windows every 3rd cycle (~90s)

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

            # Every 3rd cycle, also scan all open browser windows
            # and send lightweight pings for their tab titles.
            # This captures open browser pages even when the browser
            # is NOT the focused window.
            browser_scan_counter += 1
            if browser_scan_counter >= 3:
                browser_scan_counter = 0
                try:
                    browser_windows = get_browser_windows_gnome_ext()
                    current_titles = set()

                    for bw in browser_windows:
                        bw_title = bw.get("title", "")
                        bw_wm = bw.get("wmClass", "")
                        if not bw_title or bw_title == title:
                            # Skip empty or already-tracked focused window
                            continue

                        current_titles.add(bw_title)

                        # Only send if this is a new title we haven't seen
                        if bw_title not in _last_browser_titles:
                            bw_app = humanize_app_name(bw_wm, bw_title)
                            bw_cat = classify_activity(bw_wm, bw_title, 0)
                            send_ping(
                                window_title=bw_title,
                                app_name=bw_app,
                                app_class=bw_wm,
                                category=bw_cat,
                                project_hint="",
                                idle_ms=0,
                                duration_seconds=5,  # Short ping, just to register the page
                            )
                            log.info(f"🌐 TAB      │ {bw_app:<20} │ {bw_title[:50]}")

                    _last_browser_titles = current_titles
                except Exception as e:
                    log.debug(f"Browser scan skipped: {e}")

        except Exception as e:
            log.error(f"Loop error: {e}")

        time.sleep(PING_INTERVAL)


if __name__ == "__main__":
    run_daemon()
