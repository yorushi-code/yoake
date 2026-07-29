import QtQuick

// Reused for volume/brightness — a drag-to-set bar, since Quickshell has no
// built-in Slider control and pulling in QtQuick.Controls just for this
// would be a heavier dependency than writing by hand. Thin track + a round
// overhanging thumb (rather than a flat fill bar) reads as an actual
// tactile control instead of a static progress indicator.
Column {
    id: root
    property string label: ""
    property real value: 0 // 0..1
    signal moved(real value)

    width: parent ? parent.width : 200
    spacing: 4

    Text {
        text: root.label
        color: Theme.subtext1
        font.pixelSize: 11
    }

    Item {
        id: track
        width: parent.width
        height: 22

        Rectangle {
            id: trackBg
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 10
            radius: 5
            color: Theme.surface0
            clip: true

            Rectangle {
                id: fill
                width: trackBg.width * Math.max(0, Math.min(1, root.value))
                height: parent.height
                radius: 5
                color: Theme.accent
                Behavior on width {
                    NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                }
            }
        }

        Rectangle {
            id: thumb
            width: mouseArea.pressed ? 20 : (mouseArea.containsMouse ? 18 : 16)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
            color: Theme.text
            border.color: Theme.accent
            border.width: 2
            Behavior on width {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
            }
            Behavior on x {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.moved(Math.max(0, Math.min(1, mouse.x / width)))
            onPositionChanged: mouse => {
                if (pressed) root.moved(Math.max(0, Math.min(1, mouse.x / width)));
            }
        }
    }
}
