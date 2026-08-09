pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What is paired, what is connected, and what is in the room.
//
// The shell had no bluetooth at all -- not a chip, not a list, not a way to
// reconnect the headphones that dropped. On a laptop that is the plainest gap
// there was: the sound goes somewhere, and the shell had no opinion about where.
//
// Everything here is read through bluetoothctl, and only while a panel is
// watching. `hold()`/`release()` is not politeness: `bluetoothctl info` is one
// process per device, so an unheld poll of six paired devices is seven forks
// every few seconds for a list nobody is looking at.
Singleton {
    id: root

    property string adapter: ""
    property bool powered: false
    property bool scanning: false

    // [{ mac, name, connected, paired, trusted, icon, battery }]
    property var devices: []

    readonly property var connected: root.devices.filter(d => d.connected)
    readonly property var paired: root.devices.filter(d => d.paired && !d.connected)
    readonly property var nearby: root.devices.filter(d => !d.paired)

    readonly property var primary: root.connected.length > 0 ? root.connected[0] : null

    property int watchers: 0

    function hold() {
        root.watchers += 1;
        root.refresh();
    }

    function release() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    function refresh() {
        if (!poll.running) poll.running = true;
    }

    // Every function below changes something a person is listening through, so
    // all of them are reached from a click and none from a binding or a timer.
    function setPowered(on) {
        act.command = ["bluetoothctl", "power", on ? "on" : "off"];
        act.running = true;
    }

    function connect(mac) {
        act.command = ["bluetoothctl", "connect", mac];
        act.running = true;
    }

    function disconnect(mac) {
        act.command = ["bluetoothctl", "disconnect", mac];
        act.running = true;
    }

    function pair(mac) {
        act.command = ["bluetoothctl", "pair", mac];
        act.running = true;
    }

    function forget(mac) {
        act.command = ["bluetoothctl", "remove", mac];
        act.running = true;
    }

    // Bounded, and blocking on purpose. `scan on` left running holds the radio
    // and degrades an already-connected headset; a timed scan ends by itself
    // even if the panel is closed while it runs.
    function scan() {
        if (root.scanning) return;
        root.scanning = true;
        scanner.running = true;
    }

    // The icon bluez reports is a category, not a picture, so it maps onto the
    // shell's own vocabulary rather than being drawn from.
    function glyphFor(device) {
        const kind = device && device.icon ? device.icon : "";
        if (kind === "audio-headset" || kind === "audio-headphones") return Glyphs.headphones;
        if (kind === "audio-card" || kind === "audio-speakers") return Glyphs.speaker;
        if (kind === "input-keyboard") return Glyphs.keyboard;
        if (kind === "input-mouse" || kind === "input-tablet") return Glyphs.apps;
        if (kind === "phone") return Glyphs.monitor;
        return Glyphs.bluetooth;
    }

    // One process for the adapter, the list and every device's detail. Six
    // processes on a tick is most of what "do not poll in the background" was
    // written about, and `info` is per device by construction.
    readonly property string _script:
        "bluetoothctl show | sed -n 's/^\\s*Name: /#name /p; s/^\\s*Powered: /#power /p';"
        + "bluetoothctl devices | while read -r _ mac name; do"
        + " echo \"#dev $mac $name\";"
        + " bluetoothctl info \"$mac\" | sed -n"
        + " 's/^\\s*Connected: /#c /p; s/^\\s*Paired: /#p /p; s/^\\s*Icon: /#i /p;"
        + " s/^\\s*Battery Percentage: /#b /p';"
        + "done; exit 0"

    property Process _poll: Process {
        id: poll
        command: ["sh", "-c", root._script]
        stdout: StdioCollector {
            onStreamFinished: root._absorb(text)
        }
    }

    property Process _act: Process {
        id: act
        command: ["true"]
        onExited: root.refresh()
    }

    property Process _scanner: Process {
        id: scanner
        command: ["bluetoothctl", "--timeout", "10", "scan", "on"]
        onExited: {
            root.scanning = false;
            root.refresh();
        }
    }

    // A tick, but only while something is watching. Bluetooth state changes
    // arrive on D-Bus and this does not listen to it; four seconds is the
    // difference between a list that feels live and one that is a snapshot.
    property Timer _tick: Timer {
        interval: 4000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    function _absorb(text) {
        const out = [];
        let current = null;
        for (const line of String(text).split("\n")) {
            if (line.startsWith("#name ")) {
                root.adapter = line.substring(6).trim();
            } else if (line.startsWith("#power ")) {
                root.powered = line.substring(7).trim() === "yes";
            } else if (line.startsWith("#dev ")) {
                const rest = line.substring(5).trim();
                const at = rest.indexOf(" ");
                current = {
                    mac: at > 0 ? rest.substring(0, at) : rest,
                    name: at > 0 ? rest.substring(at + 1) : rest,
                    connected: false,
                    paired: false,
                    icon: "",
                    // -1 rather than 0: a headset at nought per cent and one
                    // that does not report a battery are different facts.
                    battery: -1
                };
                out.push(current);
            } else if (current && line.startsWith("#c ")) {
                current.connected = line.substring(3).trim() === "yes";
            } else if (current && line.startsWith("#p ")) {
                current.paired = line.substring(3).trim() === "yes";
            } else if (current && line.startsWith("#i ")) {
                current.icon = line.substring(3).trim();
            } else if (current && line.startsWith("#b ")) {
                // bluez prints "72 (0x48)"; the decimal is the useful half.
                const n = parseInt(line.substring(3).trim());
                if (!isNaN(n)) current.battery = n;
            }
        }
        root.devices = out;
    }
}
