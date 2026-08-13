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

    // ── What gets through ──
    //
    // One switch used to answer two questions at once: "stop interrupting me"
    // and "let the ones that matter through anyway". Do-not-disturb could only
    // say no to everything, so whoever silenced a chatty build also silenced
    // the call they were waiting for, and the only way back was to un-silence
    // everything. Three named states answer one question each.
    //
    // Nothing is discarded in any of them. The history takes every arrival
    // whatever the mode is: this is about interruption, not about throwing
    // messages away.
    //
    //   all         everything pops, and makes its sound
    //   important   only what the sender marked critical pops
    //   silent      nothing pops and nothing sounds
    //
    // Read once and written back explicitly rather than bound: a binding to
    // Prefs plus a write-back handler is a loop, since storing the value
    // changes the object the binding reads from.
    property string filter: "all"

    readonly property var filterModes: ["all", "important", "silent"]
    readonly property var filterNames: ["Все", "Важные", "Беззвучно"]
    readonly property int filterIndex: Math.max(0, root.filterModes.indexOf(root.filter))

    function setFilterIndex(index) {
        if (index >= 0 && index < root.filterModes.length)
            root.filter = root.filterModes[index];
    }

    // The control centre tile and the bell's middle click are both a switch,
    // and neither has room for three states — so this stays a switch *over* the
    // filter rather than becoming a second source of truth beside it. Each
    // handler writes only when the two genuinely disagree, which is what keeps
    // the pair from chasing each other around a loop: picking "important"
    // clears `dnd`, and a cleared `dnd` must not then reset the filter to "all".
    property bool dnd: false

    onDndChanged: {
        if (root.dnd !== (root.filter === "silent"))
            root.filter = root.dnd ? "silent" : "all";
    }

    onFilterChanged: {
        root.dnd = (root.filter === "silent");
        if (Prefs.loaded) Prefs.set("notifs.filter", root.filter);
    }

    // Kept across restarts like every other switch in this shell. A shell
    // restart is invisible from the outside, and silence that ends without
    // anyone asking it to is worse than no silence at all -- the whole point
    // is not being interrupted. A mode left on by accident is visible: the bar
    // carries a struck-through bell for as long as it lasts.
    function _restore() {
        if (!Prefs.loaded) return;
        // The old boolean is still on disk for anyone who had do-not-disturb on
        // when this became three modes, and dropping it would silently turn
        // their silence off on the next start.
        const legacy = Prefs.get("notifs.dnd", false) ? "silent" : "all";
        const stored = Prefs.get("notifs.filter", legacy);
        root.filter = root.filterModes.indexOf(stored) >= 0 ? stored : "all";
    }

    Component.onCompleted: root._restore()

    property Connections _prefsReady: Connections {
        target: Prefs
        function onLoadedChanged() { root._restore(); }
    }

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
    readonly property bool quiet: root.filter === "silent" || root.contextQuiet

    // The one question the toast stack asks. Kept here rather than in
    // NotificationCenter so the bar's card, the history header and the popup
    // rule cannot drift into three different ideas of what a mode means.
    function shouldToast(urgency) {
        if (root.quiet) return false;
        if (root.filter === "important") return urgency === NotificationUrgency.Critical;
        // A window that has taken the whole output is the clearest statement
        // about attention the machine can observe, and a toast lands squarely on
        // top of it — verified on camera, over a live game's scoreboard.
        //
        // Held to the same rule as the user's own "important" filter rather than
        // silenced outright: critical still gets through, everything else waits
        // in the history with the count on the bell. Absolute silence is kept
        // for the microphone, which is the one case the shell can be certain
        // costs more than a missed message.
        if (Context.fullscreen) return urgency === NotificationUrgency.Critical;
        return true;
    }

    // ── Grouping ──
    //
    // Ten messages from one application are one thing that happened ten times,
    // not ten things. Stacked as ten cards they push everything else off the
    // screen and say nothing that a count would not have said better.
    //
    // Keyed on the desktop entry where there is one, because that is the
    // application's identity: a browser reports the same entry from every tab
    // while `appName` follows whichever site sent the message, so keying on the
    // name would split one sender into a dozen groups.
    //
    // Guarded like every other read of a notification: the object dies the
    // moment its sender stops retaining it, and touching a dead one throws.
    function appKey(notification) {
        try {
            if (!notification) return "?";
            const key = notification.desktopEntry || notification.appName || "";
            return key.toLowerCase() || "?";
        } catch (e) {
            return "?";
        }
    }

    function appLabel(notification) {
        try {
            return (notification && notification.appName) ? notification.appName : "Уведомление";
        } catch (e) {
            return "Уведомление";
        }
    }

    // Groups in the order their newest member arrived, and members newest
    // first inside each. Both orders are the same rule: what just happened is
    // read first.
    readonly property var groups: {
        const out = [];
        const seen = ({});
        for (const notification of root.newestFirst) {
            const key = root.appKey(notification);
            if (seen[key] === undefined) {
                seen[key] = out.length;
                out.push({ key: key, appName: root.appLabel(notification), items: [notification] });
            } else {
                out[seen[key]].items.push(notification);
            }
        }
        return out;
    }

    readonly property bool hasCritical: root.tracked.some(n => {
        try {
            return n.urgency === NotificationUrgency.Critical;
        } catch (e) {
            return false;
        }
    })

    signal arrived()
    // NotificationCenter owns the list, so clearing is a request rather than
    // something this singleton can carry out itself.
    signal clearAllRequested()

    function clearAll() {
        root.clearAllRequested();
    }

    // The whole group at once, because the group is what the panel drew. The
    // list is copied first: dismissing mutates the tracked list this was
    // derived from, and iterating it while it changes underneath skips members.
    function dismissGroup(group) {
        if (!group) return;
        for (const notification of group.items.slice()) {
            try {
                notification.dismiss();
            } catch (e) {
                // Already retired by its sender; there is nothing left to close.
            }
        }
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
        function mode(name: string): void {
            if (root.filterModes.indexOf(name) >= 0) root.filter = name;
        }
        function clear(): void { root.clearAll(); }
    }
}
