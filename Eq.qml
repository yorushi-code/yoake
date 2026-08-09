pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Ten bands of gain, and whether the sound goes through them.
//
// The graph itself is a PipeWire filter-chain declared in a config file and
// driven by pw-cli -- see bin/yoake-eq, which exists as a script rather than as
// lines of shell inside this file because an equaliser that can only be
// debugged by reading a shell's log is one nobody will ever fix.
//
// Routing is a choice, never a default. The virtual sink is installed with a
// low session priority so a fresh login never lands in it by accident: a
// machine that silently boots into an effect chain is one whose owner cannot
// tell a broken equaliser from broken hardware.
Singleton {
    id: root

    readonly property var frequencies: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    // Decibels. The ends are where a peaking filter stops being an equaliser
    // and starts being a distortion pedal.
    readonly property real minGain: -12
    readonly property real maxGain: 12

    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string preset: "Flat"

    // Curves, not opinions dressed as numbers: each is a shape across the
    // ladder, and the reason they are here rather than in the panel is that a
    // preset is a property of the equaliser, and the panel is one way to see it.
    readonly property var presets: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
        "Treble":  [0, 0, 0, 0, 0, 1, 2, 4, 5, 6],
        "Vocal":   [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1],
        "Pop":     [-1, 0, 2, 4, 4, 2, 0, -1, -1, -1],
        "Rock":    [5, 4, 2, 0, -1, 0, 2, 3, 4, 4],
        "Jazz":    [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
        "Classic": [4, 3, 2, 0, 0, 0, -1, -2, -2, -3]
    })
    readonly property var presetNames: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]

    // Whether the graph exists at all. A panel drawn over a missing node has to
    // say so; silently doing nothing is the failure people spend an evening on.
    property bool available: false
    readonly property string nodeName: "effect_input.yoake-eq"

    readonly property var node: {
        for (const n of Audio.sinks) {
            if (n && n.name === root.nodeName) return n;
        }
        return null;
    }
    // Routed, not merely present.
    readonly property bool routed: root.node !== null
        && Pipewire.defaultAudioSink === root.node

    signal applied()

    function setBand(index, gain) {
        const next = root.bands.slice();
        next[index] = Math.max(root.minGain, Math.min(root.maxGain, gain));
        root.bands = next;
        root.preset = root._matchPreset(next);
        commit.restart();
    }

    function usePreset(name) {
        const curve = root.presets[name];
        if (!curve) return;
        root.bands = curve.slice();
        root.preset = name;
        root.applied();
        commit.restart();
    }

    function reset() {
        root.usePreset("Flat");
    }

    // Off the curve rather than off a flag: dragging a band until it happens to
    // match Rock exactly *is* Rock, and a label that says "Custom" next to the
    // Rock curve is the shell disagreeing with itself.
    function _matchPreset(curve) {
        for (const name of root.presetNames) {
            const p = root.presets[name];
            let same = true;
            for (let i = 0; i < p.length; i++) {
                if (Math.abs(p[i] - curve[i]) > 0.01) { same = false; break; }
            }
            if (same) return name;
        }
        return "";
    }

    // Route through the chain, or stop. Switching the default sink is the whole
    // mechanism -- PipeWire moves the running streams itself, so there is
    // nothing to reconnect and nothing to restart.
    function setRouted(on) {
        if (!root.node) return;
        if (on) {
            root._previousSink = Pipewire.defaultAudioSink;
            Audio.setDefaultSink(root.node);
        } else {
            const back = root._previousSink && root._previousSink !== root.node
                ? root._previousSink
                : root._firstHardwareSink();
            if (back) Audio.setDefaultSink(back);
        }
    }

    property var _previousSink: null

    function _firstHardwareSink() {
        for (const n of Audio.sinks) {
            if (n && n !== root.node) return n;
        }
        return null;
    }

    // One call for all ten, debounced.
    //
    // A slider drag emits a value a frame; a process per frame is a fork per
    // frame. Sixty milliseconds is under the threshold at which a change stops
    // feeling attached to the hand that made it, and above the rate at which
    // pw-cli can be usefully asked anything.
    property Timer _commit: Timer {
        id: commit
        interval: 60
        onTriggered: apply.running = true
    }

    property Process _apply: Process {
        id: apply
        command: [Quickshell.shellDir + "/bin/yoake-eq", "set"].concat(
            root.bands.map(g => String(g)))
        onExited: (code) => {
            root.available = code === 0;
            if (code === 0) Prefs.set("eq.bands", root.bands);
        }
    }

    property Process _probe: Process {
        id: probe
        running: true
        command: [Quickshell.shellDir + "/bin/yoake-eq", "id"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    onPresetChanged: if (Prefs.loaded) Prefs.set("eq.preset", root.preset)

    Component.onCompleted: {
        const saved = Prefs.get("eq.bands", null);
        if (saved && saved.length === root.frequencies.length) {
            root.bands = saved;
            root.preset = root._matchPreset(saved);
            // Pushed once at startup, because the graph comes up flat and the
            // saved curve is only real once it is in the filter.
            commit.restart();
        }
    }
}
