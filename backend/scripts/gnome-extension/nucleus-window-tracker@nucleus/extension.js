/**
 * Nucleus Window Tracker — GNOME Shell Extension
 * 
 * Exposes the currently focused window's title, WM_CLASS, and PID
 * via a DBus interface that the Nucleus Activity Daemon can query.
 * 
 * Works on GNOME 45/46/47 with Wayland.
 */

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const DBUS_IFACE = `
<node>
  <interface name="org.nucleus.WindowTracker">
    <method name="GetFocusedWindow">
      <arg type="s" direction="out" name="result"/>
    </method>
  </interface>
</node>`;

export default class NucleusWindowTracker extends Extension {
    _dbus = null;
    _ownerId = 0;

    enable() {
        this._dbus = Gio.DBusExportedObject.wrapJSObject(DBUS_IFACE, this);
        this._dbus.export(Gio.DBus.session, '/org/nucleus/WindowTracker');

        this._ownerId = Gio.bus_own_name(
            Gio.BusType.SESSION,
            'org.nucleus.WindowTracker',
            Gio.BusNameOwnerFlags.NONE,
            null, null, null
        );
    }

    disable() {
        if (this._dbus) {
            this._dbus.unexport();
            this._dbus = null;
        }
        if (this._ownerId) {
            Gio.bus_unown_name(this._ownerId);
            this._ownerId = 0;
        }
    }

    /**
     * Returns JSON with focused window info:
     * { "title": "...", "wmClass": "...", "pid": 12345 }
     * or { "title": "", "wmClass": "", "pid": 0 } if no focus.
     */
    GetFocusedWindow() {
        try {
            const focusWindow = global.display.focus_window;
            if (focusWindow) {
                return JSON.stringify({
                    title: focusWindow.get_title() || '',
                    wmClass: focusWindow.get_wm_class() || '',
                    pid: focusWindow.get_pid() || 0,
                });
            }
        } catch (e) {
            // Silently fail — return empty
        }
        return JSON.stringify({ title: '', wmClass: '', pid: 0 });
    }
}
