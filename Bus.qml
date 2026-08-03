pragma Singleton
import QtQuick
import Quickshell

// Things that happen, as opposed to things that are.
//
// The shell already shares everything that *is* through singletons, and a
// property binding is the right tool for that: the spectrum, the battery level,
// the focused window. What bindings cannot express is a moment -- the track
// changed, the build finished, the load spiked -- because a moment has no value
// to hold afterwards. Those went unnamed, or were smuggled in as a property
// that briefly flips and flips back, which every reader then has to decode.
//
// One signal with a name, so anything may listen without anything having to
// know who is listening. A component that reacts to `CpuSpike` does not import
// SysInfo and does not know it exists.
Singleton {
    id: root

    signal happened(string name, var payload)

    // The last few, so a surface built after the fact can still say what just
    // went on rather than opening blank. Short on purpose: this is a bus, not
    // a log, and anything that needs history should keep its own.
    property var recent: []
    readonly property int recentLimit: 12

    function emit(name, payload) {
        const item = { name: name, payload: payload || ({}), at: Date.now() };
        const out = root.recent.slice();
        out.push(item);
        while (out.length > root.recentLimit) out.shift();
        root.recent = out;
        root.happened(name, item.payload);
    }

    function lastOf(name) {
        for (let i = root.recent.length - 1; i >= 0; i--) {
            if (root.recent[i].name === name) return root.recent[i];
        }
        return null;
    }
}
