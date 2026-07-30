"""
Session Tracker
Tracks session changes between apps and projects.
"""

import time

class SessionTracker:
    def __init__(self):
        self.current_app = ""
        self.current_project = ""
        self.current_category = ""
        self.session_start = time.time()
        self.last_ping_time = time.time()

    def update(self, app: str, project: str, category: str) -> bool:
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
