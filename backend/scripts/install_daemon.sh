#!/usr/bin/env bash
# ============================================================
# Nucleus Activity Daemon — Installer
# ============================================================
# Sets up the Nucleus Laptop Activity Daemon on Ubuntu (GNOME + Wayland)
#
# What it does:
#   1. Installs system dependencies (xdotool, xprop, dbus)
#   2. Installs the Nucleus GNOME Shell Extension for Wayland window tracking
#   3. Creates a systemd user service for auto-start on login
#   4. Starts the daemon
#
# Usage:
#   chmod +x install_daemon.sh
#   ./install_daemon.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_SCRIPT="$SCRIPT_DIR/nucleus_daemon.py"
EXTENSION_SRC="$SCRIPT_DIR/gnome-extension/nucleus-window-tracker@nucleus"
EXTENSION_DST="$HOME/.local/share/gnome-shell/extensions/nucleus-window-tracker@nucleus"
SERVICE_NAME="nucleus-daemon"
SERVICE_FILE="$HOME/.config/systemd/user/${SERVICE_NAME}.service"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

echo ""
echo "🧬 =========================================="
echo "   Nucleus Activity Daemon — Installer"
echo "   Ubuntu (GNOME 45/46/47 + Wayland)"
echo "🧬 =========================================="
echo ""

# -------------------------------------------------------
# Step 1: Install system dependencies
# -------------------------------------------------------
echo "📦 Step 1: Checking system dependencies..."

MISSING_DEPS=()

command -v xdotool    &>/dev/null || MISSING_DEPS+=("xdotool")
command -v xprop      &>/dev/null || MISSING_DEPS+=("x11-utils")
command -v dbus-send  &>/dev/null || MISSING_DEPS+=("dbus")
command -v gdbus      &>/dev/null || MISSING_DEPS+=("libglib2.0-bin")

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    warn "Installing missing packages: ${MISSING_DEPS[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${MISSING_DEPS[@]}"
    info "System dependencies installed."
else
    info "All system dependencies present."
fi

# -------------------------------------------------------
# Step 2: Install GNOME Shell Extension
# -------------------------------------------------------
echo ""
echo "🔌 Step 2: Installing Nucleus GNOME Shell Extension..."

if [ -d "$EXTENSION_SRC" ]; then
    mkdir -p "$EXTENSION_DST"
    cp -r "$EXTENSION_SRC"/* "$EXTENSION_DST/"
    info "Extension installed to: $EXTENSION_DST"
    
    # Enable the extension
    gnome-extensions enable "nucleus-window-tracker@nucleus" 2>/dev/null || true
    info "Extension enabled. It will activate on next GNOME Shell restart."
    warn "You may need to log out and back in, or press Alt+F2 → 'r' (X11 only) to reload."
else
    warn "GNOME extension source not found at: $EXTENSION_SRC"
    warn "Window tracking will fall back to xdotool (XWayland)."
fi

# -------------------------------------------------------
# Step 3: Create systemd user service
# -------------------------------------------------------
echo ""
echo "⚙️  Step 3: Creating systemd user service..."

mkdir -p "$(dirname "$SERVICE_FILE")"

# Detect Python 3 path
PYTHON3_PATH="$(which python3)"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Nucleus Laptop Activity Daemon
Documentation=https://github.com/Prabhath1403/nucleus
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=${PYTHON3_PATH} ${DAEMON_SCRIPT}
Restart=on-failure
RestartSec=10
Environment=DISPLAY=:0
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment=NUCLEUS_API_URL=http://localhost:8000/api/v1/tracker/ping
Environment=NUCLEUS_PING_INTERVAL=30
Environment=NUCLEUS_IDLE_THRESHOLD_MS=180000
Environment=NUCLEUS_AFK_THRESHOLD_MS=600000

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nucleus-daemon

[Install]
WantedBy=default.target
EOF

info "Service file created: $SERVICE_FILE"

# -------------------------------------------------------
# Step 4: Enable and start the service
# -------------------------------------------------------
echo ""
echo "🚀 Step 4: Starting the daemon..."

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME"

# Check if it started successfully
sleep 2
if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    info "Daemon is running!"
else
    warn "Daemon may not have started. Check logs with:"
    echo "  journalctl --user -u $SERVICE_NAME -f"
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "🧬 =========================================="
echo "   Installation Complete!"
echo "🧬 =========================================="
echo ""
echo "  📊 Dashboard:  The daemon is now tracking your activity."
echo "  📂 Logs:       ~/.local/share/nucleus-daemon/daemon.log"
echo "  🔧 Service:    systemctl --user status $SERVICE_NAME"
echo ""
echo "  Useful commands:"
echo "    nucleus-daemon status   →  systemctl --user status $SERVICE_NAME"
echo "    nucleus-daemon logs     →  journalctl --user -u $SERVICE_NAME -f"
echo "    nucleus-daemon stop     →  systemctl --user stop $SERVICE_NAME"
echo "    nucleus-daemon restart  →  systemctl --user restart $SERVICE_NAME"
echo ""
