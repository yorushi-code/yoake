pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

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

    // Lives here rather than in NotificationCenter because the toast stack and
    // the history panel are separate windows in separate files and must agree
    // on what an urgency looks like.
    function accentFor(urgency) {
        if (urgency === NotificationUrgency.Critical) return Theme.red;
        if (urgency === NotificationUrgency.Low) return Theme.subtext0;
        return Theme.accent;
    }

    IpcHandler {
        target: "notifs"
        function dndToggle(): void { root.dnd = !root.dnd; }
        function clear(): void { root.clearAll(); }
    }
}
