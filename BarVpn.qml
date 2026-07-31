import QtQuick

// Tunnel state in the bar: on/off, the active node's latency, and live
// throughput while traffic is moving.
//
// Speed is only shown when there is any, so the widget stays a glyph on an idle
// machine instead of a permanent "0 Б/с" that says nothing.
Item {
    id: root

    property var barWindow: null

        // implicitWidth off the row's *implicit* width, and the row anchored
    // rather than centred: reading .width here while the row centres itself
    // in that same width is a cycle, and Qt resolves it in no fixed order.
    // Whenever the content changed width -- VPN going from "вкл" to a speed,
    // volume from 50%% to 100%% -- the row sat off-centre inside the old width
    // for a frame, which is the clipped percentage at the island's edge.
    implicitWidth: vpnRow.implicitWidth
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property bool up: Mihomo.running && Mihomo.controllerUp
    readonly property real total: Mihomo.upSpeed + Mihomo.downSpeed
    // A few hundred bytes a second is keepalive traffic, not activity worth
    // widening the island for.
    readonly property bool busy: root.up && root.total > 2048

    readonly property color stateColor: {
        if (Mihomo.busy) return Theme.yellow;
        if (!root.up) return Theme.subtext0;
        if (Mihomo.currentDelay === null) return Theme.red;
        return Theme.accent;
    }

    Row {
        id: vpnRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        BarIcon {
            id: vpnIcon
            anchors.verticalCenter: parent.verticalCenter
            glyph: Glyphs.vpn
            color: root.stateColor
            hovered: ma.containsMouse

            // Pulses only while the tunnel is coming up — the one moment the
            // shell has nothing else to say for several seconds.
            SequentialAnimation on opacity {
                running: Mihomo.busy
                loops: Animation.Infinite
                onStopped: vpnIcon.opacity = 1
                NumberAnimation { to: 0.35; duration: 520; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (Mihomo.busy) return "…";
                if (!root.up) return "выкл";
                if (root.busy) return Mihomo.formatSpeed(root.total);
                if (Mihomo.currentDelay !== undefined && Mihomo.currentDelay !== null) {
                    return Mihomo.currentDelay + " мс";
                }
                return "вкл";
            }
            color: root.up ? Theme.text : Theme.subtext0
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Toggles.exclusive("vpnPanel")
    }

    Tooltip {
        anchorItem: root
        active: ma.containsMouse && !Toggles.vpnPanelOpen
        text: root.up ? (Mihomo.currentNode || Mihomo.active) : "VPN отключён"
        subtext: root.up ? "ЛКМ — ноды и подписки" : "ЛКМ — подключить"
    }
}
