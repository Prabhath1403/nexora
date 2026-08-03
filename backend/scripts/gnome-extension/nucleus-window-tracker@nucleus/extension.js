/**
 * Nucleus Window Tracker — GNOME Shell Extension
 * 
 * Exposes the currently focused window's title, WM_CLASS, and PID
 * via a DBus interface that the Nucleus Activity Daemon can query.
 * 
 * Also exposes GetBrowserWindows to list all open browser windows
 * so tab titles can be captured even when the browser isn't focused.
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
    <method name="GetBrowserWindows">
      <arg type="s" direction="out" name="result"/>
    </method>
  </interface>
</node>`;

const BROWSER_WM_CLASSES = [
    'brave-browser', 'brave', 'google-chrome', 'chromium',
    'chromium-browser', 'firefox', 'firefox-esr',
    'microsoft-edge', 'opera', 'vivaldi',
];

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

    /**
     * Returns JSON array of all open browser windows with their titles.
     * Used by the daemon to capture open browser tabs even when the
     * browser is not the focused window.
     * 
     * Example output:
     * [
     *   {"title": "GitHub - Brave", "wmClass": "brave-browser", "pid": 1234},
     *   {"title": "YouTube - Brave", "wmClass": "brave-browser", "pid": 1234}
     * ]
     */
    GetBrowserWindows() {
        try {
            const windows = global.get_window_actors();
            const results = [];

            for (const actor of windows) {
                const win = actor.get_meta_window();
                if (!win) continue;

                const wmClass = (win.get_wm_class() || '').toLowerCase();
                const title = win.get_title() || '';
                const pid = win.get_pid() || 0;

                if (!title || !wmClass) continue;

                // Check if this is a browser window
                const isBrowser = BROWSER_WM_CLASSES.some(
                    cls => wmClass === cls || wmClass.includes(cls)
                );

                if (isBrowser) {
                    results.push({
                        title: title,
                        wmClass: win.get_wm_class() || '',
                        pid: pid,
                    });
                }
            }

            return JSON.stringify(results);
        } catch (e) {
            // Silently fail
        }
        return JSON.stringify([]);
    }
}
