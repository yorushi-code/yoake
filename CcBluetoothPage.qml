import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Paired and discovered devices.
//
// Discovery is started only while this page is up. Left running it keeps the
// radio scanning for the rest of the session, which costs power on a laptop and
// buys nothing once the user has walked away from the panel.
Flickable {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: root.adapter !== null && root.adapter.enabled

    readonly property var sorted: {
        if (!root.on) return [];
        return [...Bluetooth.devices.values].sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || "").localeCompare(b.name || "");
        });
    }

    contentHeight: list.implicitHeight
    clip: true

    Component.onCompleted: if (root.on) root.adapter.discovering = true
    Component.onDestruction: if (root.adapter) root.adapter.discovering = false

    Column {
        id: list
        width: parent.width
        spacing: Theme.gapTight

        Text {
            width: parent.width
            visible: !root.on
            text: "Bluetooth выключен"
            color: Theme.subtext0
            font.pixelSize: Theme.fontBody
        }

        Text {
            width: parent.width
            visible: root.on && root.sorted.length === 0
            text: "Поиск устройств…"
            color: Theme.subtext0
            font.pixelSize: Theme.fontBody
        }

        Repeater {
            model: root.sorted

            delegate: CcListRow {
                required property var modelData
                required property int index

                width: list.width
                label: modelData.name || modelData.deviceName || modelData.address
                detail: modelData.connected ? "подключено" : (modelData.paired ? "сопряжено" : "")
                connected: modelData.connected === true
                glyph: Glyphs.bluetooth

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: Direction.stagger(index) }
                        NumberAnimation { duration: Theme.animNormal }
                    }
                }

                onActivated: modelData.connected ? modelData.disconnect() : modelData.connect()
            }
        }
    }
}
