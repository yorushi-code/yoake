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
        if (!root.enabled || root.muted || !player.running) return;
        player.write(name + "\n");
    }

    onVolumeChanged: if (player.running) player.write("volume " + root.volume + "\n")
    Component.onCompleted: if (player.running) player.write("volume " + root.volume + "\n")
}
