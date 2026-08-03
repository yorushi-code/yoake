import QtQuick

// Track progress that can also scrub. Grows on hover and exposes a handle
// only then, so it reads as a thin progress line until you actually reach
// for it.
Item {
    id: root

    // Local override while dragging: binding straight to Media.progress makes
    // the fill snap back on every position poll mid-drag.
    property real dragValue: -1
    readonly property real shown: dragValue >= 0 ? dragValue : Media.progress

    height: 14

    function fractionAt(mouseX) {
        return Math.max(0, Math.min(1, mouseX / width));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: ma.containsMouse || ma.pressed ? 6 : 3
        radius: height / 2
        color: Qt.alpha(Theme.text, Theme.strokeFirm)
        Behavior on height {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }

        Rectangle {
            width: track.width * root.shown
            height: parent.height
            radius: parent.radius
            color: Theme.accent
            // Only smooth the once-a-second position poll; while dragging the
            // fill must track the cursor exactly.
            Behavior on width {
                enabled: root.dragValue < 0
                NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
            }
        }
    }

    Rectangle {
        width: 11
        height: 11
        radius: 5.5
        color: Theme.text
        border.color: Theme.accent
        border.width: 2
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(root.width - width, track.width * root.shown - width / 2))
        opacity: (ma.containsMouse || ma.pressed) && Media.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: Media.player !== null && Media.player.canSeek && Media.length > 0
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => root.dragValue = root.fractionAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) root.dragValue = root.fractionAt(mouse.x);
        }
        onReleased: mouse => {
            Media.seek(root.fractionAt(mouse.x));
            // Held until the next poll lands, otherwise the bar snaps back to
            // the stale pre-seek position for a frame.
            releaseHold.restart();
        }
    }

    Timer {
        id: releaseHold
        interval: 500
        onTriggered: root.dragValue = -1
    }
}
