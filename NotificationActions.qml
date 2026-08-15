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

    spacing: Theme.spacing
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

    Component.onCompleted: {
        console.warn("YOAKE-ACT n=" + root.entries.length
            + " app=" + (root.notification ? root.notification.appName : "?"));
        for (const e of root.entries)
            console.warn("YOAKE-ACT   id=[" + e.identifier + "] textLen=" + (e.text || "").length);
    }

    visible: root.entries.length > 0
    // No explicit `height`. It used to read `visible ? implicitHeight : 0`,
    // which looks like a collapse-when-empty guard and is really the thing that
    // broke the layout: assigning `height` on a positioner takes its sizing off
    // it, and the `implicitHeight` the binding then reads came back as **6** —
    // the top padding alone, with two 24px buttons sitting in it unaccounted
    // for. The card is `histContent.height + 18`, so the card came out 30px
    // short and cut its own actions in half. That is where the grey stub under
    // every notification with actions came from: a button clipped to a sliver.
    //
    // The guard was not needed either. A `Column` skips invisible children, so
    // `visible` already collapses this to nothing; the height line was doing no
    // work except the damage.

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
                font.pixelSize: Theme.fontSmall
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
