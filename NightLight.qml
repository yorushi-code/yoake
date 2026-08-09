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

    // Where the temperature sits on its own range. Every control that offers it
    // is a slider over 0..1, and each of them was converting by hand — three
    // copies of one arithmetic, which is three chances to get the direction
    // wrong.
    readonly property real fraction: (root.temperature - root.minTemperature)
        / (root.maxTemperature - root.minTemperature)

    // Rounded to a hundred kelvin. wlsunset is respawned to change temperature
    // at all, so a drag that honoured every pixel would be asking the display
    // server for a new gamma ramp several hundred times on the way across.
    function setFraction(f) {
        const span = root.maxTemperature - root.minTemperature;
        const clamped = Math.max(0, Math.min(1, f));
        root.temperature =
            Math.round((root.minTemperature + clamped * span) / 100) * 100;
    }

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

    onEnabledChanged: {
        if (Prefs.loaded) Prefs.set("nightLight.enabled", root.enabled);
        root._restart();
    }

    function toggle() {
        root.enabled = !root.enabled;
    }

    // No `running:` binding on this, deliberately, and the absence is the bug
    // this file used to have: _restart() assigns proc.running, and a JS
    // assignment destroys the binding it lands on. The first restart therefore
    // severed "run while enabled" for the rest of the session, after which the
    // toggle changed a boolean and nothing else — it looked like it worked,
    // because the label followed the flag.
    property Process proc: Process {
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
        relight.restart();
    }

    // The sweep above cannot tell a process we have just started from the stale
    // one it was sent to clear, so the new one waits until the old ones are
    // gone rather than racing them.
    property Timer relight: Timer {
        interval: Theme.animFast
        onTriggered: proc.running = root.enabled
    }

    // wlsunset bakes the temperature in at spawn, so a change while it is
    // running has to go through a restart -- and a slider dragged across a
    // panel would respawn it on every pixel of travel. The restart waits for
    // the hand to stop; the number under it does not.
    property Timer settle: Timer {
        interval: Theme.animNormal
        onTriggered: if (root.enabled) root._restart()
    }

    onTemperatureChanged: {
        if (Prefs.loaded) Prefs.set("nightLight.temperature", root.temperature);
        if (root.enabled) settle.restart();
    }
}
