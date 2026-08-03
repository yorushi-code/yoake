pragma Singleton
import QtQuick
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
    //
    // Kept across restarts like every other switch in this shell. A shell
    // restart is invisible from the outside, and silence that ends without
    // anyone asking it to is worse than no silence at all -- the whole point
    // is not being interrupted. A DND left on by accident is visible: the bar
    // carries a struck-through bell for as long as it lasts.
    //
    // Read once and written back explicitly rather than bound: a binding to
    // Prefs plus a write-back handler is a loop, since storing the value
    // changes the object the binding reads from.
    property bool dnd: false

    Component.onCompleted: if (Prefs.loaded) root.dnd = Prefs.get("notifs.dnd", false)

    property Connections _prefsReady: Connections {
        target: Prefs
        function onLoadedChanged() {
            if (Prefs.loaded) root.dnd = Prefs.get("notifs.dnd", false);
        }
    }

    onDndChanged: if (Prefs.loaded) Prefs.set("notifs.dnd", root.dnd)

    // Quiet the shell decides on by itself, kept separate from the switch the
    // user threw. Interrupting someone while a microphone is open is the
    // costliest thing this shell can do -- a toast slides over the window they
    // are sharing -- and it is also the one case the machine can be sure of,
    // because a capture stream is a fact rather than a guess about intent.
    //
    // Nothing is discarded and nothing is silent about being silent: the
    // history takes everything, the bar wears the struck-through bell, and its
    // card says which of the two kinds of quiet is in force.
    readonly property bool contextQuiet: Context.mode === "meeting"
    readonly property bool quiet: root.dnd || root.contextQuiet

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
