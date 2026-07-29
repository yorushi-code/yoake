pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording via wf-recorder, driven by a niri keybind (Mod+Alt+R ->
// `qs ipc call recorder toggle`) and reflected by an indicator in the bar.
//
// wf-recorder must be stopped with SIGINT, not killed: SIGINT lets it write
// the moov atom so the mp4 is actually playable. So stop() signals the
// process rather than clearing `running`, and state resets in onExited once
// the file is finalized.
Singleton {
    id: root

    property bool recording: false
    // Persists across recordings so the choice is remembered; the bar shows a
    // mic glyph while recording when this is on.
    property bool micEnabled: false
    // Which output to capture. Empty means "let the script pick the only one";
    // the script used to hardcode eDP-1, which captured nothing on any other
    // display.
    property string output: ""
    property int elapsed: 0 // seconds since recording started
    property string lastFile: ""

    readonly property string outputDir: Quickshell.env("HOME") + "/Videos/recordings"

    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60);
        const s = elapsed % 60;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    Process {
        id: proc
        onExited: (code, status) => {
            root.recording = false;
            elapsedTimer.stop();
            root.elapsed = 0;
        }
    }

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }

    function start() {
        if (root.recording) return;
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        root.lastFile = "recording_" + ts + ".mp4";
        // Delegated to screen-record.sh which handles the desktop-audio /
        // desktop+mic mix and cleans up its PipeWire modules on exit. mkdir
        // first; the script process receives SIGINT from stop() and forwards
        // it to wf-recorder.
        proc.command = ["sh", "-c",
            "mkdir -p '" + root.outputDir + "' && exec ~/.local/bin/screen-record.sh '"
            + root.outputDir + "/" + root.lastFile + "' " + (root.micEnabled ? "1" : "0")
            + " " + (root.output || "")];
        proc.running = true;
        root.recording = true;
        root.elapsed = 0;
        elapsedTimer.restart();
    }

    function stop() {
        if (!root.recording) return;
        proc.signal(2); // SIGINT
    }

    function toggle() {
        if (root.recording) stop();
        else start();
    }

    // Mic can be toggled mid-recording; it takes effect on the next start,
    // since the audio mix is wired up when recording begins.
    function toggleMic() {
        root.micEnabled = !root.micEnabled;
    }

    IpcHandler {
        target: "recorder"
        function toggle(): void { root.toggle(); }
        function start(): void { root.start(); }
        function stop(): void { root.stop(); }
        function toggleMic(): void { root.toggleMic(); }
        function openFolder(): void { Quickshell.execDetached(["xdg-open", root.outputDir]); }
    }
}
