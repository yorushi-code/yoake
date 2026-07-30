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

    function toggle() {
        root.enabled = !root.enabled;
    }

    property Process proc: Process {
        running: root.enabled
        command: ["wlsunset", "-T", String(root.temperature + 1), "-t", String(root.temperature)]
    }

    // wlsunset bakes the temperature in at spawn, so a change while it is
    // running has to go through a restart.
    onTemperatureChanged: if (root.enabled) {
        proc.running = false;
        proc.running = true;
    }
}
