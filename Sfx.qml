pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sound for things that happened.
//
// The rule, and it is the whole design: **a sound is for something with a
// consequence off the screen.** Headphones connected, network lost, VPN up,
// recording started, an action that failed. Not: a panel opening, a hover, a
// focus change, a workspace switch, a preset button. Everything in the second
// list is already answered by the thing moving on screen, and a shell that
// chirps at all of it is a shell people switch off on the second day -- at
// which point the first list stops being heard too.
//
// Off by default for the same reason. Someone who wants it turns it on and gets
// a small set of sounds that always mean something.
Singleton {
    id: root

    readonly property bool enabled: Prefs.get("sfx.enabled", false)
    readonly property int volume: Prefs.get("sfx.volume", 70)

    // Silence while anything is listening. A click recorded into a screen
    // capture or picked up by a call is a sound the shell had no business
    // making -- and it is very likely why the reference recording has none.
    readonly property bool muted: Recorder.recording || Notifs.contextQuiet

    property Process _player: Process {
        id: player
        running: root.enabled
        command: [Quickshell.shellDir + "/bin/yoake-sfx"]
        stdinEnabled: true
    }

    function play(name) {
        if (!root.enabled || !root.armed || root.muted || !player.running) return;
        player.write(name + "\n");
    }

    // Heard on request, whatever the switch says. Someone deciding whether to
    // turn this on is asking exactly "what will it sound like", and answering
    // that with silence because it is currently off is a settings page arguing
    // with the person reading it.
    function audition(name) {
        if (root.muted) return;
        if (!player.running) player.running = true;
        player.write(name + "\n");
    }

    // ── What is worth a sound ──
    //
    // The policy lives here rather than at the call sites, and that is the
    // design rather than a convenience. Scattered across five singletons it
    // becomes five people's taste, and the rule -- a sound is for something
    // with a consequence off the screen -- is exactly the kind of rule that
    // erodes one well-meaning call at a time.
    //
    // Watched as state transitions, not as clicks: headphones that drop by
    // themselves are the same event as headphones you disconnected, and the one
    // you did not do is the one worth hearing.
    property bool armed: false
    property Timer _arm: Timer {
        // Everything settles into its real value in the first moment of a
        // session. Without this, a login is a chord.
        interval: 4000
        running: true
        onTriggered: root.armed = true
    }

    property Connections _bt: Connections {
        target: Bluetooth
        function onConnectedChanged() {
            if (Bluetooth.connected.length > root._btCount) root.play("device-added");
            else if (Bluetooth.connected.length < root._btCount) root.play("device-removed");
            root._btCount = Bluetooth.connected.length;
        }
    }
    property int _btCount: 0

    property Connections _net: Connections {
        target: Net
        function onActiveSsidChanged() {
            if (Net.activeSsid !== "" && root._lastSsid === "") root.play("network-up");
            else if (Net.activeSsid === "" && root._lastSsid !== "") root.play("network-lost");
            root._lastSsid = Net.activeSsid;
        }
    }
    property string _lastSsid: ""

    property Connections _vpn: Connections {
        target: Mihomo
        function onRunningChanged() {
            root.play(Mihomo.running ? "vpn-up" : "vpn-down");
        }
    }

    property Connections _rec: Connections {
        target: Recorder
        function onRecordingChanged() {
            // The stop is heard; the start is not, because the start is the one
            // that would land in the recording.
            if (!Recorder.recording) root.play("record-stop");
        }
    }

    property Connections _notif: Connections {
        target: Notifs
        function onArrived() {
            root.play("message");
        }
    }

    onVolumeChanged: if (player.running) player.write("volume " + root.volume + "\n")
    Component.onCompleted: if (player.running) player.write("volume " + root.volume + "\n")
}
