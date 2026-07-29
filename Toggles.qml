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

    property IpcHandler handler: IpcHandler {
        target: "toggles"

        function notifCenter() { root.notifCenterOpen = !root.notifCenterOpen; }
        function controlCenter() { root.controlCenterOpen = !root.controlCenterOpen; }
        function cheatSheet() { root.cheatSheetOpen = !root.cheatSheetOpen; }
        function calendar() { root.calendarOpen = !root.calendarOpen; }
    }
}
