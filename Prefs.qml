pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Small persistent settings, kept out of the config directory.
//
// Anything written next to shell.qml triggers a full quickshell reload — every
// window destroyed and recreated — so a preference toggle would visibly reset
// the whole shell. State belongs in XDG_STATE_HOME anyway: it is neither
// configuration the user edits nor cache that can be thrown away.
//
// Writes are debounced because the callers are sliders and drag handles: a
// widget dragged across the screen would otherwise rewrite the file on every
// frame.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/quickshell"

    property var values: ({})
    property bool loaded: false

    function get(key, fallback) {
        const v = root.values[key];
        return v === undefined ? fallback : v;
    }

    function set(key, value) {
        if (root.values[key] === value) return;
        const next = Object.assign({}, root.values);
        next[key] = value;
        root.values = next;
        writeDelay.restart();
    }

    // Deletes rather than storing null. `get` treats a stored null as a real
    // value, so a key "cleared" by assignment shadows its own fallback for
    // ever, and the file grows a tail of settings nothing reads.
    function remove(key) {
        if (!(key in root.values)) return;
        const next = Object.assign({}, root.values);
        delete next[key];
        root.values = next;
        writeDelay.restart();
    }

    Timer {
        id: writeDelay
        interval: 400
        // setText is the write: FileView has no separate save step unless it is
        // driven by an adapter.
        onTriggered: file.setText(JSON.stringify(root.values, null, 2) + "\n")
    }

    FileView {
        id: file
        path: root.dir + "/prefs.json"
        // Absent on a first run, which is the empty state rather than an error
        // worth logging every start.
        printErrors: false
        // A half-written file parses as nothing and would silently reset every
        // preference the user had set.
        atomicWrites: true
        blockLoading: true

        onLoaded: {
            try {
                root.values = JSON.parse(file.text()) || {};
            } catch (e) {
                root.values = ({});
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
