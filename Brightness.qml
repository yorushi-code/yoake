pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level, owned in one place.
//
// Both the OSD and the control centre used to shell out to brightnessctl
// themselves, and neither told the other anything. The control centre read the
// value once when it opened, so pressing the brightness keys with the panel
// already up left its slider showing a stale number until it was reopened.
Singleton {
    id: root

    // 0..1
    property real value: 0
    // The kernel's name for the backlight — `amdgpu_bl1` here. Shown rather
    // than hidden: a panel that lists real things names them, and it is the
    // only thing that would tell an internal panel apart from a second one.
    property string device: ""
    // False until a reading lands. A machine with no backlight at all reports
    // nothing, and a slider offered for hardware that is not there is worse
    // than an absent one.
    property bool available: false

    // A fresh reading landed, whoever caused it. Anything showing the level
    // follows this.
    signal refreshed()
    // Somebody moved the level from outside any visible control, which is the
    // only case that earns an OSD. These were one signal, so reading the
    // backlight because a panel opened popped the OSD over the panel that had
    // just asked -- and dragging the control centre's own slider announced a
    // number the slider was already showing.
    signal announced()

    // Whether the reading now in flight should announce itself. The keys change
    // the backlight in another process and then ask the shell to catch up, so
    // "somebody moved it" is not something the reading can tell on its own --
    // only the caller knows.
    property bool _announce: false

    // brightnessctl -m prints: class,name,current,percent%,max
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length < 4) return;
                const pct = parseInt(parts[3]);
                if (isNaN(pct)) return;
                root.device = parts[0];
                root.available = true;
                root.value = pct / 100;
                root.refreshed();
                if (root._announce) {
                    root._announce = false;
                    root.announced();
                }
            }
        }
    }

    Process { id: setProc }

    function refresh(announce) {
        root._announce = announce === true;
        getProc.running = true;
    }

    // Where the hardware is being asked to go. Held separately from `value` so
    // the coalescing timer below always writes the newest number rather than
    // whichever one it happened to be started by.
    property real _pending: 0

    function set(fraction) {
        const clamped = Math.max(0.01, Math.min(1, fraction));
        // Applied locally first so a drag tracks the pointer rather than
        // waiting on a process round-trip per frame.
        root.value = clamped;
        root._pending = clamped;
        commit.restart();
        root.refreshed();
    }

    // A slider dragged across a panel calls set() on every pointer move, and
    // the direct spelling forked brightnessctl for each of them -- sixty
    // processes a second to reach one final value, all but the last of which
    // are immediately overwritten. Coalescing costs one response-length delay
    // on a single click, which is under the threshold where a backlight change
    // reads as lagging behind the hand.
    Timer {
        id: commit
        interval: Theme.animFast
        onTriggered: {
            setProc.command = ["brightnessctl", "-q", "set",
                               Math.round(root._pending * 100) + "%"];
            setProc.running = true;
        }
    }

    Component.onCompleted: root.refresh()
}
