import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi status.
//
// Signal strength comes from `iw dev <if> link`, NOT `nmcli dev wifi`: nmcli
// asks NetworkManager to rescan the airwaves, and one rescan every 10s stalls
// the connection on a single-radio card — that was the "network keeps
// dropping" bug. `iw link` only reads the current association.
//
// The same reasoning gates the network list in the right-click menu: it is
// requested when the menu opens and never on a timer.
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "network")

    width: netRow.width
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // -1 means no association at all, which is distinct from an associated
    // link reporting 0%. The old code drew a solid accent wifi glyph in both
    // cases, so a disconnected machine looked connected.
    property int signalPercent: -1
    property string ssid: ""

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    Process {
        id: netProc
        command: ["sh", "-c",
            "i=$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}'); " +
            "s=$(iw dev \"$i\" link 2>/dev/null | awk '/signal:/{print $2}'); " +
            "n=$(iw dev \"$i\" link 2>/dev/null | sed -n 's/^\\tSSID: //p'); " +
            "if [ -n \"$s\" ]; then p=$((2*(s+100))); [ $p -gt 100 ] && p=100; [ $p -lt 0 ] && p=0; " +
            "echo \"$p|$n\"; else echo \"-1|\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                root.signalPercent = parseInt(parts[0]);
                root.ssid = parts[1] || "";
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    Row {
        id: netRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Networking.wifiEnabled ? Glyphs.wifiFor(root.signalPercent) : Glyphs.wifiOff
            font.family: "Symbols Nerd Font"
            font.pixelSize: 13
            color: (root.signalPercent >= 0 && Networking.wifiEnabled) ? Theme.accent : Theme.subtext0
            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.signalPercent >= 0 ? Theme.text : Theme.subtext0
            font.pixelSize: 11
            text: !Networking.wifiEnabled ? "выкл"
                : (root.signalPercent >= 0 ? root.signalPercent + "%" : "нет сети")
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            netProc.running = true;
            Menus.toggle(root.menuId);
        }
    }

    // Scanning runs only while the list is on screen. There is no one-shot scan
    // in the API — the old `scan()` call was not a function at all and threw on
    // every open — and leaving the scanner on stalls this single-radio card's
    // association, which was the "network keeps dropping" bug.
    Connections {
        target: Menus
        function onCurrentChanged() {
            if (!root.wifiDevice) return;
            root.wifiDevice.scannerEnabled = Menus.isOpen(root.menuId) && Networking.wifiEnabled;
        }
    }

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        model: {
            if (!Menus.isOpen(root.menuId)) return [];
            const out = [{
                text: Networking.wifiEnabled ? "Выключить Wi-Fi" : "Включить Wi-Fi",
                glyph: Networking.wifiEnabled ? Glyphs.wifiOff : Glyphs.wifi,
                action: () => Networking.wifiEnabled = !Networking.wifiEnabled
            }];
            if (Networking.wifiEnabled && root.wifiDevice) {
                const nets = [...root.wifiDevice.networks.values]
                    .sort((a, b) => b.signalStrength - a.signalStrength)
                    .slice(0, 8);
                if (nets.length > 0) out.push({ separator: true });
                for (const n of nets) {
                    out.push({
                        text: `${n.name}  ${Math.round(n.signalStrength * 100)}%`,
                        checkable: true,
                        checked: n.connected === true,
                        action: () => n.connected ? n.disconnect() : n.connect()
                    });
                }
            }
            out.push({ separator: true });
            out.push({
                text: "Настройки сети",
                glyph: Glyphs.cog,
                action: () => Quickshell.execDetached(["nm-connection-editor"])
            });
            return out;
        }
    }

    Tooltip {
        anchorItem: root
        active: ma.containsMouse && !Menus.isOpen(root.menuId)
        text: root.ssid !== "" ? root.ssid : "Не подключено"
        subtext: "ПКМ — выбор сети"
    }
}
