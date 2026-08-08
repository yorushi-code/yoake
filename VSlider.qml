import QtQuick

// One equaliser band.
//
// Vertical rather than a rotated HSlider, because the two are not the same
// control: a band has a centre -- unity gain -- and the fill grows *from the
// bottom* while the meaning is measured from the middle. Rotating the
// horizontal one would have inherited a fill that means "how much of the way
// along", which is the wrong sentence about a gain.
Item {
    id: root

    // In the caller's units; the caller says what the ends mean.
    property real value: 0
    property real from: -12
    property real to: 12
    property string caption: ""
    property color tint: Theme.accent

    signal moved(real value)
    signal committed(real value)

    implicitWidth: 26
    implicitHeight: 120

    readonly property real fraction:
        Math.max(0, Math.min(1, (root.value - root.from) / Math.max(0.0001, root.to - root.from)))
    readonly property real trackTop: 0
    readonly property real trackBottom: root.height - captionText.implicitHeight - Theme.gapTight
    readonly property real handleY:
        root.trackBottom - (root.trackBottom - root.trackTop) * root.fraction

    Rectangle {
        id: rail
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.trackTop
        width: 5
        height: root.trackBottom - root.trackTop
        radius: width / 2
        color: Qt.alpha(Theme.text, Theme.fillMuted)
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 5
        radius: width / 2
        y: root.handleY
        height: Math.max(0, root.trackBottom - root.handleY)
        color: root.tint

        Behavior on y {
            enabled: !hit.pressed
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }
        Behavior on height {
            enabled: !hit.pressed
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }
    }

    Rectangle {
        id: knob
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.handleY - height / 2
        width: 13
        height: width
        radius: width / 2
        color: Theme.text
        scale: hit.pressed ? 1.2 : (hit.containsMouse ? 1.1 : 1)

        Behavior on y {
            enabled: !hit.pressed
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }
    }

    Text {
        id: captionText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.caption
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontMicro
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function pick(y) {
            const span = Math.max(1, root.trackBottom - root.trackTop);
            const f = Math.max(0, Math.min(1, (root.trackBottom - (y - 3)) / span));
            root.moved(root.from + (root.to - root.from) * f);
        }

        onPressed: mouse => hit.pick(mouse.y)
        onPositionChanged: mouse => { if (hit.pressed) hit.pick(mouse.y); }
        onReleased: root.committed(root.value)
        // Double-click returns the band to unity, which is the only way anyone
        // ever gets an equaliser back to something they can hear properly.
        onDoubleClicked: {
            const mid = (root.from + root.to) / 2;
            root.moved(mid);
            root.committed(mid);
        }
    }
}
