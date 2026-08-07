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
    readonly property bool anyOpen: root.notifCenterOpen
        || root.cheatSheetOpen || root.calendarOpen || root.wallpaperPickerOpen
        || root.vpnPanelOpen || root.launcherOpen

    // Panels that take keyboard focus for themselves. niri reports a window
    // focus change when they open, and closing on that signal means a panel
    // dismisses itself the moment it is used. They close on Escape or on a
    // click outside, which they already handle.
    readonly property bool holdsFocus: root.dashboardOpen || root.launcherOpen

    // Everything the compositor's attention signal should take with it.
    function closeTransient() {
        if (root.holdsFocus) return;
        root.closeAll();
    }

    function closeAll() {
        root.notifCenterOpen = false;
        root.cheatSheetOpen = false;
        root.calendarOpen = false;
        root.wallpaperPickerOpen = false;
        root.vpnPanelOpen = false;
        root.dashboardOpen = false;
        root.launcherOpen = false;
    }

    readonly property var dashPages: ["overview", "media", "system", "control", "desks"]

    function dash(page) {
        const at = root.dashPages.indexOf(page);
        if (at >= 0) root.dashPage = at;
        root.exclusive("dashboard");
    }

    // Opening one panel closes the others: two frosted sheets overlapping read
    // as a glitch, and the user has no way to tell which one has focus.
    function exclusive(name) {
        const wanted = !root[name + "Open"];
        root.closeAll();
        root[name + "Open"] = wanted;
    }

    // ── The dashboard peek ──
    //
    // Pointing at the bar's centre island for 420ms opened the full sheet and
    // took the keyboard exclusively with it. So brushing past the clock on the
    // way to the tray stole the keyboard from whatever was being typed into,
    // and left a sheet that then had to be dismissed by hand — a gesture
    // nobody performed on purpose, with two consequences that both had to be
    // undone.
    //
    // A peek is the same sheet without either commitment. It asks for the
    // keyboard on demand rather than exclusively, so it takes nothing until it
    // is clicked, and it leaves when the pointer does.
    property bool dashboardPeek: false

    // Where the pointer is, as far as the peek is concerned. Two flags because
    // there are two surfaces in two windows: the island that opens it and the
    // sheet it opens, and neither can see the other's hover.
    //
    // One pointer, so one flag each rather than a count. On two monitors two
    // bars write the same flag and the enter and leave are not ordered across
    // windows, so crossing from one bar to the other can close a peek a beat
    // early. That is the whole cost, and a reference count would leak the
    // first time a surface unmapped while hovered.
    property bool dashPointerOnBar: false
    property bool dashPointerOnSheet: false

    function dashPeek() {
        if (root.dashboardOpen) return;
        root.dashboardPeek = true;
        root.exclusive("dashboard");
    }

    // Any deliberate input promotes it: you meant it after all, and from here
    // it behaves like a dashboard somebody asked for.
    function dashCommit() {
        root.dashboardPeek = false;
    }

    onDashboardOpenChanged: {
        if (root.dashboardOpen) return;
        root.dashboardPeek = false;
        // The sheet's window is about to unmap, and a hover flag left standing
        // on a surface that no longer exists would keep the *next* peek from
        // ever closing itself.
        root.dashPointerOnSheet = false;
    }

    onDashPointerOnBarChanged: root._peekTick()
    onDashPointerOnSheetChanged: root._peekTick()

    function _peekTick() {
        if (root.dashPointerOnBar || root.dashPointerOnSheet) {
            peekOut.stop();
        } else if (root.dashboardPeek) {
            peekOut.restart();
        }
    }

    property Timer _peekOut: Timer {
        id: peekOut
        // Long enough to cross the gap between the island and the sheet, which
        // is only the bar's own margin, and short enough that a sheet nobody is
        // pointing at does not sit there.
        interval: Theme.animNormal
        onTriggered: {
            if (root.dashboardPeek && !root.dashPointerOnBar
                    && !root.dashPointerOnSheet) {
                root.dashboardOpen = false;
            }
        }
    }

    property IpcHandler handler: IpcHandler {
        target: "toggles"

        function launcher() { root.exclusive("launcher"); }
        function dashboard() { root.exclusive("dashboard"); }

        function dash(page: string): void { root.dash(page); }
        function notifCenter() { root.exclusive("notifCenter"); }
        // The controls are a dashboard page now, so the old binding lands
        // there rather than on a second sheet beside it.
        function controlCenter() { root.dash("control"); }
        function cheatSheet() { root.exclusive("cheatSheet"); }
        function calendar() { root.exclusive("calendar"); }
        function wallpaper() { root.exclusive("wallpaperPicker"); }
        function vpn() { root.exclusive("vpnPanel"); }
        function close() { root.closeAll(); Menus.closeAll(); }
    }
}
