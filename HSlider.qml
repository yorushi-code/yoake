import QtQuick

// A value you can set, wherever the shell shows one.
//
// Deliberately one component for the device volume, the seek bar and the
// brightness: they are the same gesture, and the reason the old shell had three
// of them is that each panel wrote its own the day it needed one.
//
// The handle only appears under the pointer. At rest this is a reading; the
// moment it can be grabbed, it says so.
Item {
    id: root

    property real value: 0
    property color tint: Theme.accent
    property bool muted: false
    // Steps for a wheel notch and for the arrow keys.
    property real step: 0.05
    property real trackHeight: 6

    signal moved(real value)
    // Fired once at the end of a drag, for callers that must not write a value
    // sixty times a second -- a seek is a request to a player, not a slider.
    signal committed(real value)

    implicitHeight: 18
    implicitWidth: 120

    readonly property color activeTint: root.muted
        ? Qt.alpha(Theme.text, Theme.fillActive)
        : root.tint
    readonly property real clamped: Math.max(0, Math.min(1, root.value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.trackHeight
        radius: height / 2
        color: Qt.alpha(Theme.text, Theme.fillMuted)

        Rectangle {
            width: track.width * root.clamped
            height: parent.height
            radius: parent.radius
            color: root.activeTint

            // Only when nobody is dragging. A Behavior during a drag makes the
            // fill trail the pointer, which reads as the control being slow
            // rather than as the value being smoothed.
            Behavior on width {
                enabled: !hit.pressed
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
            }
        }
    }

    Rectangle {
        id: handle
        width: 12
        height: width
        radius: width / 2
        color: Theme.text
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(track.width * root.clamped - width / 2)
        opacity: hit.containsMouse || hit.pressed ? 1 : 0
        scale: hit.pressed ? 1.25 : 1

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }
        Behavior on x {
            enabled: !hit.pressed
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // The hit area is inset by -4 on every side, so its origin sits four
        // pixels left of the track's.
        function pick(x) {
            root.moved(Math.max(0, Math.min(1, (x - 4) / Math.max(1, track.width))));
        }

        onPressed: mouse => hit.pick(mouse.x)
        onPositionChanged: mouse => { if (hit.pressed) hit.pick(mouse.x); }
        onReleased: root.committed(root.value)
        onWheel: wheel => {
            const d = wheel.angleDelta.y > 0 ? root.step : -root.step;
            const v = Math.max(0, Math.min(1, root.value + d));
            root.moved(v);
            root.committed(v);
        }
    }
}
