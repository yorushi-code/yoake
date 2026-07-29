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

    // Whether anything is actually playing. Read directly from each frame this
    // chattered at the frame rate around silence, and it drives two nested
    // width Behaviors (the mini spectrum's, then the whole centre island's at
    // 420ms), so the bar spent its idle time continuously re-laying itself
    // out. Rising edge is immediate — the spectrum must not lag the music —
    // and only the falling edge waits.
    property bool active: false
    readonly property real _onThreshold: 0.04

    // Fraction of the remaining distance a falling bar covers per frame.
    // Tuned against the 70ms OutQuad Behavior this replaced.
    readonly property real releaseRate: 0.45

    // Mean of the three lowest bands, for anything that wants to pulse to the
    // beat. Computed here so the widgets using it neither re-derive it nor
    // need their own smoothing Behaviors — one blurred shadow re-rendering
    // every frame because two 90ms animations kept restarting was as
    // expensive as the whole spectrum it was reacting to.
    property real bass: 0

    Timer {
        id: quietDelay
        interval: 700
        onTriggered: {
            root.active = false;
            // The spectrum fades out with `active`, so there is nothing left
            // for the peaks to decay in front of — and this lets the decay
            // timer stop instead of ticking through silence forever.
            root.peaks = new Array(root.barCount).fill(0);
        }
    }

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
# 30 rather than 60: every frame allocates a new values array and invalidates
# the bindings of 28 desktop bars plus 14 in the bar. The per-bar height
# Behaviors interpolate between frames anyway, so the spectrum looks identical
# and costs half as much.
framerate = 30
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
            quietDelay.stop();
            root.active = false;
        }

        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                const parts = line.split(";");
                const out = [];
                const pk = root.peaks;
                const prev = root.values;
                for (let i = 0; i < root.barCount; i++) {
                    const v = parseInt(parts[i]);
                    const raw = isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100));
                    // Smoothed here, once, rather than by a `Behavior on
                    // height` per bar. Those never finished: a 70ms animation
                    // restarted every frame is 42 animations being torn down
                    // and rebuilt per frame across the two spectrums, which
                    // was most of the shell's idle CPU. Attack is instant so a
                    // beat lands on the frame it happens; only the fall is
                    // damped, which is the part the eye reads as smooth.
                    out.push(raw > prev[i] ? raw : prev[i] + (raw - prev[i]) * root.releaseRate);
                    if (raw > pk[i]) pk[i] = raw;
                }
                root.values = out;
                root.peaks = pk;
                root.bass = (out[0] + out[1] + out[2]) / 3;

                if (out.some(v => v > root._onThreshold)) {
                    quietDelay.stop();
                    root.active = true;
                } else if (root.active && !quietDelay.running) {
                    quietDelay.restart();
                }
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
        running: root.active
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
