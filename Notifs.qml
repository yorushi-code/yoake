pragma Singleton
import Quickshell
import Quickshell.Io

// Bridges notification events from NotificationCenter (which owns the single
// NotificationServer) to anything else that wants to react — the bar's bell,
// mainly. A second NotificationServer can't be created (only one can hold the
// D-Bus name), so state is mirrored here instead.
//
// `count` used to be assigned only when a notification arrived and never
// recalculated, so it drifted upward as notifications were dismissed. It is now
// pushed by NotificationCenter on every change to the tracked list.
Singleton {
    id: root

    property int count: 0
    // Suppresses toasts while still recording everything in the history, so
    // nothing is lost — this is "don't interrupt me", not "discard".
    property bool dnd: false

    signal arrived()
    // NotificationCenter owns the list, so clearing is a request rather than
    // something this singleton can carry out itself.
    signal clearAllRequested()

    function clearAll() {
        root.clearAllRequested();
    }

    IpcHandler {
        target: "notifs"
        function dndToggle(): void { root.dnd = !root.dnd; }
        function clear(): void { root.clearAll(); }
    }
}
