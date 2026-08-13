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

    // Everything the compositor's attention signal should take with it —
    // which is everything.
    //
    // The dashboard and the launcher used to be exempt, on the grounds that
    // niri reports a window focus change when they open and closing on that
    // signal would dismiss them the moment they were used. Measured on the
    // event stream: opening the dashboard emits `Window focus changed: None`,
    // and `Niri._applyWindowFocusChanged` has ignored a null focus for exactly
    // this reason since it was written. The exemption was guarding against
    // something that was already guarded.
    //
    // What it did instead was leave them up after the user had gone somewhere
    // else: click into a window with the dashboard open and it stayed, which is
    // the "shell looks stuck" case this signal exists to prevent. Reported from
    // use, and this is the fix.
    function closeTransient() {
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

    // ── The dashboard peek, and why there isn't one ──
    //
    // Pointing at the bar's centre for 420ms used to open the dashboard. It was
    // built twice: once taking the keyboard exclusively, which stole keystrokes
    // from whatever was being typed into, and once taking no keyboard at all,
    // which fixed the theft and made it the only surface in the shell that could
    // not be closed with Escape.
    //
    // Those two are the same knob. A surface answers Escape only while it holds
    // the keyboard, so a panel that must never take the keyboard can never be
    // dismissed by one — there was no third setting, and the second version
    // shipped with "it leaves when the pointer does" standing in for a dismissal
    // the user could actually perform.
    //
    // Reported as exactly that, twice, in the same words as the panels that
    // would not leave. What ends the argument is that the gesture was redundant:
    // the clock in the centre of the bar opens the dashboard on a click and
    // always did. One panel had two ways in, and the second one opened without
    // being asked and would not close when told.
    //
    // Removed rather than fixed. The seventy lines of pointer bookkeeping that
    // used to live here — two hover flags across two windows, a settle timer and
    // a commit — existed only to give a gesture nobody performed a way out.

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
