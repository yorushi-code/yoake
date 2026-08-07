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

    function set(fraction) {
        const clamped = Math.max(0.01, Math.min(1, fraction));
        // Applied locally first so a drag tracks the pointer rather than
        // waiting on a process round-trip per frame.
        root.value = clamped;
        setProc.command = ["brightnessctl", "set", Math.round(clamped * 100) + "%"];
        setProc.running = true;
        root.refreshed();
    }

    Component.onCompleted: root.refresh()
}
