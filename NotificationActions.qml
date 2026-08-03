import QtQuick

// Action buttons an application attached to its notification.
//
// The server has always advertised `actionsSupported: true`, so applications
// were sending actions and getting no way to invoke them — "Reply", "Mark as
// read" and the like were accepted and silently discarded. Collapses to zero
// height when there are none, which is the common case.
Flow {
    id: root

    property var notification: null
    signal invoked()

    spacing: 6
    topPadding: visible ? 6 : 0
    // Same guard as NotificationIcon — the object can go away underneath a
    // toast that is still on screen.
    readonly property var entries: {
        try {
            return root.notification ? root.notification.actions : [];
        } catch (e) {
            return [];
        }
    }

    visible: root.entries.length > 0
    height: visible ? implicitHeight : 0

    Repeater {
        model: root.entries

        delegate: Rectangle {
            required property var modelData

            width: actionLabel.implicitWidth + 20
            height: 24
            radius: Theme.radiusChip
            color: actionMa.containsMouse ? Theme.accent : Qt.alpha(Theme.text, Theme.fillMuted)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            scale: actionMa.pressed ? 0.94 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
            }

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: modelData.text
                color: actionMa.containsMouse ? Theme.crust : Theme.text
                font.pixelSize: 11
            }

            MouseArea {
                id: actionMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    modelData.invoke();
                    // Invoking an action is an answer; leaving the toast up
                    // afterwards would invite a second, duplicate press.
                    root.invoked();
                }
            }
        }
    }
}
