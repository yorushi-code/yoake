pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether the session is allowed to give up on you.
//
// The flag itself lives in the runtime directory and is owned by
// bin/yoake-idle.sh, which is what actually acts on it -- this only reflects
// and flips it. Keeping the state in the script rather than here means the
// keybind and the tile cannot disagree, and the chain still obeys it when the
// shell is restarted underneath.
Singleton {
    id: root

    readonly property string script:
        Quickshell.env("HOME") + "/.config/quickshell/bin/yoake-idle.sh"

    property bool keepAwake: false

    Process { id: setter }

    Process {
        id: reader
        command: [root.script, "awake-state"]
        stdout: StdioCollector {
            onStreamFinished: root.keepAwake = text.trim() === "on"
        }
    }

    // Polled rather than watched: the keybind can flip it without the shell
    // being involved at all, and a file watch on a path that may not exist yet
    // is more machinery than a question asked every few seconds.
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }

    function toggle() {
        setter.command = [root.script, root.keepAwake ? "awake-off" : "awake-on"];
        setter.running = true;
        // Assumed immediately so the tile answers the click, and corrected by
        // the next poll if the script disagreed.
        root.keepAwake = !root.keepAwake;
    }

    IpcHandler {
        target: "idle"
        function toggle(): void { root.toggle(); }
        function on(): void { if (!root.keepAwake) root.toggle(); }
        function off(): void { if (root.keepAwake) root.toggle(); }
        function state(): string { return root.keepAwake ? "on" : "off"; }
    }
}
