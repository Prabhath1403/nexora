#!/usr/bin/env python3
"""
Nucleus Laptop Activity Daemon — Entrypoint Wrapper
====================================================
Modular architecture stored in backend/scripts/daemon/
"""

import sys
import os

# Ensure daemon package directory is in Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from daemon.main import run_daemon

if __name__ == "__main__":
    run_daemon()
