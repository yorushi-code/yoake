import QtQuick
import Quickshell
import Quickshell.Networking

// Networks in range.
//
// The scanner runs only while this page is up. Left on it re-scans the airwaves
// for the rest of the session, and on this single-radio card that stalls the
// association it is already holding — which was the "network keeps dropping"
// bug. There is no one-shot scan in the API; scannerEnabled is the whole
// control.
Flickable {
    id: root

    readonly property var device: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    readonly property var sorted: {
        if (!root.device || !Networking.wifiEnabled) return [];
        return [...root.device.networks.values]
            .sort((a, b) => b.signalStrength - a.signalStrength);
    }

    contentHeight: list.implicitHeight
    clip: true

    Component.onCompleted: if (root.device && Networking.wifiEnabled) root.device.scannerEnabled = true
    Component.onDestruction: if (root.device) root.device.scannerEnabled = false

    Column {
        id: list
        width: parent.width
        spacing: 5

        Text {
            width: parent.width
            visible: !Networking.wifiEnabled
            text: "Wi-Fi выключен"
            color: Theme.subtext0
            font.pixelSize: 12
        }

        Text {
            width: parent.width
            visible: Networking.wifiEnabled && root.sorted.length === 0
            text: "Сети не найдены"
            color: Theme.subtext0
            font.pixelSize: 12
        }

        Repeater {
            model: root.sorted

            delegate: CcListRow {
                required property var modelData
                required property int index

                width: list.width
                label: modelData.name
                // signalStrength is 0..1, not a percentage: without the
                // scale every network read as 0% and every glyph as no
                // signal.
                detail: Math.round(modelData.signalStrength * 100) + "%"
                connected: modelData.connected === true
                glyph: Glyphs.wifiFor(modelData.signalStrength * 100)

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: Theme.stagger(index) }
                        NumberAnimation { duration: Theme.animNormal }
                    }
                }

                onActivated: modelData.connected ? modelData.disconnect() : modelData.connect()
            }
        }
    }
}
