pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared visibility state for panels that niri keybinds need to toggle.
// Exposed over IPC (`qs ipc call toggles <fn>`) since niri binds can only
// spawn shell commands, not call into a running quickshell instance
// directly.
QtObject {
    id: root

    property bool notifCenterOpen: false
    property bool controlCenterOpen: false
    property bool cheatSheetOpen: false
    property bool calendarOpen: false
    property bool wallpaperPickerOpen: false
    property bool vpnPanelOpen: false
    property bool dashboardOpen: false
    // Which dashboard page is showing. Kept here rather than in the panel so a
    // hand-off from a bar widget can pick the page before the panel exists.
    property int dashPage: 0
    property bool launcherOpen: false

    // Panels are dismissed by the same gestures as menus (desktop click,
    // Escape, focus moving to a window), so the desktop catcher needs one
    // question answered rather than a growing list of them.
    readonly property bool anyOpen: root.notifCenterOpen || root.controlCenterOpen
        || root.cheatSheetOpen || root.calendarOpen || root.wallpaperPickerOpen
        || root.vpnPanelOpen || root.launcherOpen

    function closeAll() {
        root.notifCenterOpen = false;
        root.controlCenterOpen = false;
        root.cheatSheetOpen = false;
        root.calendarOpen = false;
        root.wallpaperPickerOpen = false;
        root.vpnPanelOpen = false;
        root.dashboardOpen = false;
        root.launcherOpen = false;
    }

    // Opening one panel closes the others: two frosted sheets overlapping read
    // as a glitch, and the user has no way to tell which one has focus.
    function exclusive(name) {
        const wanted = !root[name + "Open"];
        root.closeAll();
        root[name + "Open"] = wanted;
    }

    property IpcHandler handler: IpcHandler {
        target: "toggles"

        function launcher() { root.exclusive("launcher"); }
        function dashboard() { root.exclusive("dashboard"); }

        function dash(page: string): void {
            const pages = ["overview", "system", "desks"];
            const at = pages.indexOf(page);
            if (at >= 0) root.dashPage = at;
            root.exclusive("dashboard");
        }
        function notifCenter() { root.exclusive("notifCenter"); }
        function controlCenter() { root.exclusive("controlCenter"); }
        function cheatSheet() { root.exclusive("cheatSheet"); }
        function calendar() { root.exclusive("calendar"); }
        function wallpaper() { root.exclusive("wallpaperPicker"); }
        function vpn() { root.exclusive("vpnPanel"); }
        function close() { root.closeAll(); Menus.closeAll(); }
    }
}
