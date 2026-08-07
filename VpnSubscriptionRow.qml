import QtQuick

// One subscription.
//
// Only the host is ever shown. The stored URL carries the provider's access
// token in its query string, and putting that on screen is the same as
// publishing it — a screenshot of this panel would hand over the account.
Rectangle {
    id: root

    required property var modelData
    property bool busy: false

    signal connectRequested()
    signal refreshRequested()
    signal removeRequested()
    signal coreRequested(string core)

    // The three cores, in the order the chip cycles through them. Which one a
    // subscription runs on is part of the subscription: providers differ in
    // what they hand out, and a key that needs xhttp cannot run on sing-box
    // while one built on hysteria2 cannot run on Xray at all.
    readonly property var cores: ["mihomo", "sing-box", "xray"]
    readonly property string core: root.modelData.core || "mihomo"
    readonly property string nextCore:
        root.cores[(Math.max(0, root.cores.indexOf(root.core)) + 1) % root.cores.length]

    // Node count, quota and expiry as the provider reported them during the
    // last download. It only sends them in the headers of that download, so
    // there is nothing to poll and nothing more recent to show.
    readonly property var meta: root.modelData.meta || ({})
    readonly property real used: (root.meta.upload || 0) + (root.meta.download || 0)
    readonly property real quota: root.meta.total || 0
    readonly property int daysLeft: root.meta.expire
        ? Math.floor((root.meta.expire * 1000 - Date.now()) / 86400000)
        : -9999

    readonly property string detail: {
        const parts = [];
        if (root.meta.nodes) parts.push(root.meta.nodes + " нод");
        if (root.quota > 0) {
            parts.push(Mihomo.formatBytes(root.used) + " / " + Mihomo.formatBytes(root.quota));
        } else if (root.used > 0) {
            parts.push(Mihomo.formatBytes(root.used));
        }
        if (root.meta.expire) {
            parts.push(root.daysLeft < 0
                ? "истекла"
                : "до " + Qt.formatDate(new Date(root.meta.expire * 1000), "dd.MM.yy"));
        }
        return parts.join(" · ");
    }

    height: info.implicitHeight + 20
    radius: Theme.radius
    color: root.modelData.active
        ? Qt.alpha(Theme.accent, 0.14)
        : (ma.containsMouse ? Qt.alpha(Theme.text, 0.07) : Qt.alpha(Theme.text, 0.04))
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Column {
        id: info
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: actions.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Row {
            spacing: Theme.spacing

            Text {
                text: root.modelData.name
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: Theme.accent
                visible: root.modelData.active
            }
        }

        Text {
            width: parent.width
            text: root.modelData.host
            color: Theme.subtext0
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            // Red once the subscription has run out of either resource: by then
            // it is the reason nothing connects, not a detail.
            color: root.daysLeft < 0 || (root.quota > 0 && root.used >= root.quota)
                ? Theme.red : Theme.subtext1
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight
        }
    }

    // Quota as a hairline along the bottom edge, so the ratio is legible
    // without reading the numbers.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 4
        height: 2
        radius: 1
        color: Qt.alpha(Theme.text, Theme.fillMuted)
        visible: root.quota > 0

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.min(1, root.used / root.quota)
            color: root.used / root.quota > 0.9 ? Theme.red
                : (root.used / root.quota > 0.7 ? Theme.yellow : Theme.accent)
            Behavior on width { NumberAnimation { duration: Theme.animNormal } }
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // The core, and the only place to change it. Xray is marked because it
        // has no TUN: on that core nothing is tunnelled except what points at
        // the proxy port, which is otherwise indistinguishable from a tunnel
        // that came up and carries nothing.
        Rectangle {
            id: coreChip
            anchors.verticalCenter: parent.verticalCenter
            width: coreLabel.implicitWidth + 14
            height: 20
            radius: Theme.radiusChip
            color: coreArea.containsMouse
                ? Qt.alpha(Theme.accent, 0.24)
                : Qt.alpha(Theme.text, 0.08)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: coreLabel
                anchors.centerIn: parent
                text: root.core
                // Yellow rather than a badge: the chip is 20px tall and the
                // fact it carries is "this core does not tunnel the system".
                color: root.core === "xray"
                    ? Theme.yellow
                    : (coreArea.containsMouse ? Theme.text : Theme.subtext0)
                font.pixelSize: Theme.fontLabel
            }

            MouseArea {
                id: coreArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.coreRequested(root.nextCore)
            }

            Tooltip {
                anchorItem: coreChip
                active: coreArea.containsMouse
                text: "Ядро: " + root.core + " → " + root.nextCore
                subtext: root.core === "xray"
                    ? "Xray без TUN: в туннель идёт только то, что смотрит в порт 7890"
                    : "Переключение пересобирает конфиг при следующем подключении"
            }
        }

        Repeater {
            model: [
                { glyph: Glyphs.power, hint: "Подключить", act: "connect" },
                { glyph: Glyphs.refresh, hint: "Обновить список нод", act: "refresh" },
                { glyph: Glyphs.close, hint: "Удалить", act: "remove" }
            ]

            delegate: Rectangle {
                id: button
                required property var modelData

                width: 26
                height: 26
                radius: Theme.radiusChip
                color: buttonArea.containsMouse
                    ? (button.modelData.act === "remove" ? Theme.red : Qt.alpha(Theme.text, 0.16))
                    : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: button.modelData.glyph
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: Theme.fontIconMicro
                    color: buttonArea.containsMouse ? Theme.text : Theme.subtext0
                }

                MouseArea {
                    id: buttonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (button.modelData.act === "connect") root.connectRequested();
                        else if (button.modelData.act === "refresh") root.refreshRequested();
                        else root.removeRequested();
                    }
                }

                Tooltip {
                    anchorItem: button
                    active: buttonArea.containsMouse
                    text: button.modelData.hint
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        // Below the action buttons: this only exists for the hover tint.
        acceptedButtons: Qt.NoButton
        z: -1
    }
}
