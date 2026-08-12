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

    // ── Sheets ──
    //
    // One flag per chip in the bar, because a sheet belongs to the chip that
    // opened it and only ever one of them is up. Declared here in the
    // foundation so that eleven tracks could be written at the same time
    // without any of them editing this file.
    property bool audioPanelOpen: false
    property bool mediaPanelOpen: false
    property bool netPanelOpen: false
    property bool btPanelOpen: false
    property bool powerPanelOpen: false
    property bool weatherPanelOpen: false

    // Panels are dismissed by the same gestures as menus (desktop click,
    // Escape, focus moving to a window), so the desktop catcher needs one
    // question answered rather than a growing list of them.
    readonly property bool anyOpen: root.notifCenterOpen
        || root.cheatSheetOpen || root.calendarOpen || root.wallpaperPickerOpen
        || root.vpnPanelOpen || root.launcherOpen || root.anySheetOpen

    readonly property bool anySheetOpen: root.audioPanelOpen || root.mediaPanelOpen
        || root.netPanelOpen || root.btPanelOpen || root.powerPanelOpen
        || root.weatherPanelOpen

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
        root.closeSheets();
    }

    // A sheet replaces whichever sheet was up: they all hang off the same strip
    // and two of them open at once would overlap.
    function sheet(name) {
        root.closeSheets();
        if (name === "audio") root.audioPanelOpen = true;
        else if (name === "media") root.mediaPanelOpen = true;
        else if (name === "net") root.netPanelOpen = true;
        else if (name === "bt") root.btPanelOpen = true;
        else if (name === "power") root.powerPanelOpen = true;
        else if (name === "weather") root.weatherPanelOpen = true;
    }

    function toggleSheet(name) {
        const was = root.sheetOpen(name);
        root.closeSheets();
        if (!was) root.sheet(name);
    }

    function sheetOpen(name) {
        if (name === "audio") return root.audioPanelOpen;
        if (name === "media") return root.mediaPanelOpen;
        if (name === "net") return root.netPanelOpen;
        if (name === "bt") return root.btPanelOpen;
        if (name === "power") return root.powerPanelOpen;
        if (name === "weather") return root.weatherPanelOpen;
        return false;
    }

    function closeSheets() {
        root.audioPanelOpen = false;
        root.mediaPanelOpen = false;
        root.netPanelOpen = false;
        root.btPanelOpen = false;
        root.powerPanelOpen = false;
        root.weatherPanelOpen = false;
    }

    // Matches Dashboard's tabs, and has to: the IPC and every hand-off from a
    // bar widget select a page by index into this list.
    readonly property var dashPages: ["overview", "control", "desks"]

    // Asking for a page is not the same gesture as toggling the panel.
    //
    // This toggled unconditionally, so asking for a page that was not the one
    // showing *closed* the dashboard and left the page selected behind it: the
    // load widget opens Обзор, the shell menu's "Управление" then shuts the
    // panel, and getting to the page you asked for takes two goes. `toggleSheet`
    // has worked correctly since the sheets were written — the same name closes,
    // a different name switches — and this is that gesture on a panel whose
    // siblings are pages.
    //
    // An unknown page now does nothing at all rather than toggling the panel on
    // a name the shell does not have. `dashboard()` is the entry point for
    // toggling without choosing.
    function dash(page) {
        const at = root.dashPages.indexOf(page);
        if (at < 0) return;
        const showing = root.dashboardOpen && root.dashPage === at;
        root.dashPage = at;
        if (showing) {
            root.dashboardOpen = false;
        } else if (!root.dashboardOpen) {
            root.exclusive("dashboard");
        }
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
        // The sheets have no keybind of their own -- they belong to the chip
        // that opens them -- but a shell you cannot drive from a script is a
        // shell nobody can test.
        function panel(name: string): void { root.toggleSheet(name); }
        function close() { root.closeAll(); Menus.closeAll(); }
    }
}
