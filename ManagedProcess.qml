import QtQuick
import Quickshell.Io

// A Process that comes back after it dies.
//
// Plain `Process { running: true }` starts once and stays dead the moment the
// child exits, which is how the audio spectrum silently disappeared for the
// rest of a session: pipewire-pulse was SIGKILLed, cava (a Pulse client) exited
// with it, and nothing restarted it. The same exposure applies to every
// long-lived helper the shell spawns — the niri event stream in particular,
// since losing it freezes the workspace list forever with no visible error.
//
// Backoff is exponential because a command that fails instantly (missing
// binary, unavailable service) would otherwise spin as fast as the event loop
// allows. The counter resets once a run survives `stableMs`, so an occasional
// mid-session crash still restarts promptly instead of inheriting the delay
// from some failure hours earlier.
Item {
    id: root

    property alias command: proc.command
    property alias stdout: proc.stdout
    property alias stderr: proc.stderr
    property alias running: proc.running
    property alias processId: proc.processId

    property bool autoRestart: true
    // Exposed for diagnostics: a widget can show that its data source is
    // flapping rather than just displaying stale numbers.
    property int restarts: 0

    readonly property int baseDelay: 1000
    readonly property int maxDelay: 30000
    readonly property int stableMs: 60000

    property int _attempt: 0

    signal restarted()

    function start() {
        backoff.stop();
        stable.stop();
        proc.running = true;
    }

    // Deliberately separate from `running = false`: a caller that wants the
    // process gone must not have it resurrected by the exit handler.
    function stopPermanently() {
        root.autoRestart = false;
        backoff.stop();
        stable.stop();
        proc.running = false;
    }

    // Kills the current child and lets the normal restart path bring it back.
    // Used when the process was configured from state that has since changed
    // (cava bakes in the audio source it was told to read at spawn time).
    function restart() {
        if (!proc.running) {
            root.start();
            return;
        }
        root._attempt = 0;
        proc.signal(15); // SIGTERM
    }

    Process {
        id: proc
        running: true

        onRunningChanged: {
            if (running) stable.restart();
            else stable.stop();
        }

        onExited: {
            if (!root.autoRestart) return;
            backoff.interval = Math.min(root.maxDelay, root.baseDelay * Math.pow(2, root._attempt));
            root._attempt++;
            backoff.restart();
        }
    }

    Timer {
        id: backoff
        onTriggered: {
            root.restarts++;
            proc.running = true;
            root.restarted();
        }
    }

    // A run that lasted this long counts as healthy, so the next failure is
    // treated as a fresh incident and retried immediately.
    Timer {
        id: stable
        interval: root.stableMs
        onTriggered: root._attempt = 0
    }
}
