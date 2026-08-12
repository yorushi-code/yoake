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

        // implicitWidth off the row's *implicit* width, and the row anchored
    // rather than centred: reading .width here while the row centres itself
    // in that same width is a cycle, and Qt resolves it in no fixed order.
    // Whenever the content changed width -- VPN going from "вкл" to a speed,
    // volume from 50% to 100% -- the row sat off-centre inside the old width
    // for a frame, which is the clipped percentage at the island's edge.
    implicitWidth: netRow.implicitWidth
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // -1 means no association at all, which is distinct from an associated
    // link reporting 0%. The old code drew a solid accent wifi glyph in both
    // cases, so a disconnected machine looked connected.
    property int signalPercent: -1
    property string ssid: ""
    property int freqMhz: 0
    property real bitrate: 0
    property string address: ""

    // 2.4 and 5 are the only two this radio has, and which one you are on is
    // the difference between "slow" and "far from the router".
    readonly property string band: root.freqMhz >= 4900 ? "5 ГГц"
        : (root.freqMhz > 0 ? "2,4 ГГц" : "")

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
            "l=$(iw dev \"$i\" link 2>/dev/null); " +
            "s=$(echo \"$l\" | awk '/signal:/{print $2}'); " +
            "n=$(echo \"$l\" | sed -n 's/^\\tSSID: //p'); " +
            "f=$(echo \"$l\" | awk '/freq:/{print $2}'); " +
            "r=$(echo \"$l\" | awk '/tx bitrate:/{print $3}'); " +
            "a=$(ip -4 -br addr show \"$i\" 2>/dev/null | awk '{print $3}' | cut -d/ -f1); " +
            "if [ -n \"$s\" ]; then p=$((2*(s+100))); [ $p -gt 100 ] && p=100; [ $p -lt 0 ] && p=0; " +
            "echo \"$p|$n|$f|$r|$a\"; else echo \"-1||||\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                root.signalPercent = parseInt(parts[0]);
                root.ssid = parts[1] || "";
                root.freqMhz = parseInt(parts[2]) || 0;
                root.bitrate = parseFloat(parts[3]) || 0;
                root.address = parts[4] || "";
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
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight

        // The name of the network, not the fact that one exists.
        //
        // This was a glyph and a percentage, which tells you the radio is on
        // and nothing else. The one thing anyone actually wants from a bar is
        // *which* network they are on, and that question was unanswerable
        // without opening something.
        //
        // The signal ring is gone with it: `network_wifi_N_bar` already has the
        // level in the drawing, and two readings of one value is how the bar
        // ended up loudest in its least interesting state.
        Chip {
            id: netChip
            anchors.verticalCenter: parent.verticalCenter
            tone: "net"
            glyph: Networking.wifiEnabled ? Glyphs.wifiFor(root.signalPercent) : Glyphs.wifiOff
            label: !Networking.wifiEnabled ? "выкл"
                : (root.ssid !== "" ? root.ssid : "нет сети")
            // An SSID can be forty characters. The strip gets a ceiling and the
            // name gets elided; the panel has room for the whole of it.
            labelCap: 118
            live: Networking.wifiEnabled && root.signalPercent >= 0
            onClicked: {
                netProc.running = true;
                Toggles.toggleSheet("net");
            }
            onRightClicked: {
                netProc.running = true;
                Menus.toggle(root.menuId);
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
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

    // A tooltip named the network and stopped there, so pointing at the Wi-Fi
    // icon looked like nothing had happened at all. The card says what the link
    // actually is -- band, rate, address -- and can switch the radio off, which
    // is the one thing people reach for without wanting the whole list.
    Popover {
        anchorItem: root
        hovered: ma.containsMouse && !Menus.isOpen(root.menuId)
        minWidth: Theme.popoverWidth

        Column {
            spacing: Theme.gapWide

            Row {
                spacing: Theme.gapWide

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Networking.wifiEnabled ? Glyphs.wifiFor(root.signalPercent)
                                                 : Glyphs.wifiOff
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIcon
                    color: (root.signalPercent >= 0 && Networking.wifiEnabled)
                        ? Theme.accent : Theme.subtext0
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.gapPair

                    Text {
                        text: !Networking.wifiEnabled ? "Wi-Fi выключен"
                            : (root.ssid !== "" ? root.ssid : "Не подключено")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                    }

                    Text {
                        width: 176
                        text: {
                            if (!Networking.wifiEnabled || root.signalPercent < 0) return "";
                            const bits = [root.signalPercent + "%"];
                            if (root.band !== "") bits.push(root.band);
                            if (root.bitrate > 0) bits.push(Math.round(root.bitrate) + " Мбит/с");
                            return bits.join("  ·  ");
                        }
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.features: ({ "tnum": 1 })
                        elide: Text.ElideRight
                    }
                }
            }

            // Signal as a bar as well as a number: 62% means nothing until you
            // have seen what 80% looks like in the same place.
            Rectangle {
                width: 218
                height: 4
                radius: 2
                visible: Networking.wifiEnabled && root.signalPercent >= 0
                color: Qt.alpha(Theme.text, Theme.fillHover)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.signalPercent / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.signalPercent < 30 ? Theme.yellow : Theme.accent
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animSlow
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasized
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                }
            }

            Rectangle {
                width: 218
                height: 1
                color: Qt.alpha(Theme.text, Theme.fillHover)
            }

            Text {
                visible: root.address !== ""
                text: root.address
                color: Theme.subtext0
                font.family: Theme.fontMonoFamily
                font.pixelSize: Theme.fontLabel
            }

            // The hit area is a sibling of the row, not a child: a MouseArea
            // inside a Row is laid out as another column of it.
            Item {
                width: 218
                height: 22

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: Networking.wifiEnabled ? Glyphs.wifiOff : Glyphs.wifi
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIconMicro
                        color: Theme.subtext1
                    }

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: Networking.wifiEnabled ? "Выключить Wi-Fi" : "Включить Wi-Fi"
                        color: radioHit.containsMouse ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }
                }

                MouseArea {
                    id: radioHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
            }

            Text {
                text: "ПКМ — выбор сети"
                color: Qt.alpha(Theme.subtext0, Theme.inkStrong)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
            }
        }
    }
}
