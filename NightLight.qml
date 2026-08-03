pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colour temperature, on demand.
//
// wlsunset has no fixed-temperature mode: it interpolates between a daytime and
// a nighttime value according to the sun. Setting the two one kelvin apart pins
// the result wherever in the day it happens to be, which is what a manual
// toggle means — the user asked for warm now, not warm at 19:00.
//
// A plain Process rather than ManagedProcess: this one is supposed to exit when
// switched off, and a supervisor would resurrect it.
Singleton {
    id: root

    property bool enabled: false
    property int temperature: 3800

    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6500

    // Kept across restarts, like every other preference in this shell. Without
    // it, warming the screen at midnight lasted until the next time the shell
    // was restarted and then quietly undid itself -- and the one thing a
    // person turns this on for is that it stays on.
    //
    // Read once and written back explicitly rather than bound: a binding to
    // Prefs plus a write-back handler is a loop, since storing the value
    // changes the object the binding reads from. Singleton construction order
    // is undefined, so the file may still be unread when this one is built.
    Component.onCompleted: if (Prefs.loaded) root._adopt()

    property Connections _prefsReady: Connections {
        target: Prefs
        function onLoadedChanged() { if (Prefs.loaded) root._adopt(); }
    }

    function _adopt() {
        root.temperature = Prefs.get("nightLight.temperature", root.temperature);
        root.enabled = Prefs.get("nightLight.enabled", false);
        // Adopting is also the moment to clear whatever the previous shell
        // left running, whether or not the setting came back on.
        root._restart();
    }

    onEnabledChanged: if (Prefs.loaded) Prefs.set("nightLight.enabled", root.enabled)

    function toggle() {
        root.enabled = !root.enabled;
    }

    property Process proc: Process {
        running: root.enabled
        command: ["wlsunset", "-T", String(root.temperature + 1), "-t", String(root.temperature)]
    }

    // wlsunset outlives the shell that started it, so every restart left
    // another one behind and they fought over the same gamma table -- two of
    // them running eight seconds apart was how this was found. The shell is
    // the only thing on this machine that runs wlsunset, so anything already
    // running is ours and is stale by definition.
    //
    // -x matches the binary name exactly. `pkill -f` would match this very
    // command line as readily as its target.
    property Process sweep: Process {
        command: ["pkill", "-x", "wlsunset"]
    }

    function _restart() {
        proc.running = false;
        sweep.running = true;
        if (root.enabled) proc.running = true;
    }

    // wlsunset bakes the temperature in at spawn, so a change while it is
    // running has to go through a restart.
    onTemperatureChanged: {
        if (Prefs.loaded) Prefs.set("nightLight.temperature", root.temperature);
        if (root.enabled) root._restart();
    }
}
