pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which keyboard layout is live.
//
// The bar never showed it, on a machine that types two alphabets. The launcher
// already carries a whole ЙЦУКЕН-to-QWERTY table because typing into it with
// the wrong layout was common enough to be worth undoing automatically -- which
// is the shell working around a fact it declined to display.
Singleton {
    id: root

    property var names: []
    property int current: 0

    readonly property string label: root.current < root.names.length
        ? root.short(root.names[root.current]) : ""

    // "English (US)" is not a thing that fits in a bar chip. The first two
    // letters of the language are what every other shell shows and what
    // everyone already reads.
    function short(name) {
        if (!name) return "";
        const first = String(name).trim().split(/[\s(]/)[0];
        return first.substring(0, 2).toUpperCase();
    }

    function next() {
        switcher.running = true;
    }

    function refresh() {
        reader.running = true;
    }

    property Process _reader: Process {
        id: reader
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.names = data.names || [];
                    root.current = data.current_idx || 0;
                } catch (e) {
                    // niri not up yet, or a version without the command. The
                    // chip simply shows nothing rather than the shell logging
                    // on a timer.
                }
            }
        }
    }

    property Process _switcher: Process {
        id: switcher
        command: ["niri", "msg", "action", "switch-layout", "next"]
        onExited: root.refresh()
    }

    // niri emits a layout change on its event stream, which Niri.qml already
    // watches; until that carries it, a slow poll is enough for something that
    // changes a few times an hour.
    property Timer _poll: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
