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
    // Emitted whenever a fresh reading lands, whoever caused the change.
    signal refreshed()

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
            }
        }
    }

    Process { id: setProc }

    function refresh() {
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
