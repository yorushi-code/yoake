pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Live audio spectrum, shared by every widget that wants to react to sound.
// cava is driven headless (raw ascii on stdout) — its own autosensing handles
// gain, which is why the bars stay useful across wildly different source
// volumes without any normalisation here.
Singleton {
    id: root

    readonly property int barCount: 28
    // Values are 0..1, one per frequency band, lowest frequency first.
    property var values: new Array(barCount).fill(0)
    // Slowly-decaying maxima, so a transient peak leaves a mark that falls back
    // instead of vanishing on the next frame (see the decay timer).
    property var peaks: new Array(barCount).fill(0)
    property bool active: false

    readonly property string _runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    // Config is written and cava exec'd in one shell invocation so the file is
    // guaranteed to exist before cava reads it — writing it from QML instead
    // races against process startup. The source is resolved at runtime from
    // the default sink rather than hardcoded: `source = auto` picks the
    // default *input* (the microphone), which reads silence, and a literal
    // device name would break on any audio hardware change.
    ManagedProcess {
        id: cavaProc
        command: ["sh", "-c", `cat > ${root._runtimeDir}/qs-cava.conf <<CAVAEOF
[general]
mode = normal
framerate = 60
bars = ${root.barCount}
autosens = 1
[input]
method = pulse
source = $(pactl get-default-sink).monitor
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
channels = mono
CAVAEOF
exec cava -p ${root._runtimeDir}/qs-cava.conf`]

        // Whatever killed cava (most often pipewire-pulse restarting under it)
        // also left the last frame on screen; clearing on restart avoids the
        // bars sitting frozen at their final values during the backoff.
        onRestarted: {
            root.values = new Array(root.barCount).fill(0);
            root.peaks = new Array(root.barCount).fill(0);
            root.active = false;
        }

        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                const parts = line.split(";");
                const out = [];
                const pk = root.peaks;
                for (let i = 0; i < root.barCount; i++) {
                    const v = parseInt(parts[i]);
                    const level = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100));
                    out.push(level);
                    if (level > pk[i]) pk[i] = level;
                }
                root.values = out;
                root.peaks = pk;
                root.active = out.some(v => v > 0.01);
            }
        }
    }

    // The monitor source is baked into the config at spawn time, so switching
    // output (plugging in headphones) leaves cava reading a sink nothing plays
    // to — the spectrum goes flat with the process still alive and no error.
    property var _sinkWatcher: Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (Pipewire.defaultAudioSink) cavaProc.restart();
        }
    }

    // Peaks fall on their own clock rather than per audio frame: tying the
    // decay to incoming frames means they never move once cava stops sending.
    Timer {
        interval: 60
        running: true
        repeat: true
        onTriggered: {
            const pk = root.peaks;
            const vals = root.values;
            let changed = false;
            for (let i = 0; i < root.barCount; i++) {
                if (pk[i] > vals[i]) {
                    pk[i] = Math.max(vals[i], pk[i] - 0.012);
                    changed = true;
                }
            }
            if (changed) root.peaks = pk.slice();
        }
    }
}
