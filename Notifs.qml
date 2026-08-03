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
    // The tracked list itself, mirrored out of NotificationCenter because it
    // owns the one NotificationServer that can exist. The history panel lives
    // in a different file and cannot see that file's ids — reaching for them
    // is exactly how it ended up rendering nothing at all.
    property var tracked: []

    // Newest first, because that is the only order a list of things that just
    // happened can be read in. The bar was already reversing the index by hand
    // while the panel iterated the raw list, so the two surfaces disagreed
    // about which notification was the latest one.
    readonly property var newestFirst: root.tracked.slice().reverse()
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
