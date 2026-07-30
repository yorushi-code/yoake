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

    height: 54
    radius: Theme.radius
    color: root.modelData.active
        ? Qt.alpha(Theme.accent, 0.14)
        : (ma.containsMouse ? Qt.alpha(Theme.text, 0.07) : Qt.alpha(Theme.text, 0.04))
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: actions.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Row {
            spacing: 7

            Text {
                text: root.modelData.name
                color: Theme.text
                font.pixelSize: 12
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
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

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
                radius: 13
                color: buttonArea.containsMouse
                    ? (button.modelData.act === "remove" ? Theme.red : Qt.alpha(Theme.text, 0.16))
                    : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: button.modelData.glyph
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 12
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
