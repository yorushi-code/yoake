import QtQuick
import Quickshell.Widgets

// Expanding circle from the click point, clipped to the parent's shape.
//
// Drop it inside any Rectangle-shaped control and it draws a press ripple
// without taking the click — the control keeps its own MouseArea. Kept
// separate from the hover fills already on these controls because a ripple has
// to outlive the press: it plays to completion on release rather than
// snapping back.
ClippingRectangle {
    id: root

    // Named apart from ClippingRectangle's own `color`, which this must
    // leave transparent to avoid painting over the control it sits on.
    property color rippleColor: Theme.accent
    property real maxOpacity: 0.35

    // Press point, in this item's coordinates. The circle is positioned from
    // these rather than anchored, so it stays centred as it grows.
    property real originX: 0
    property real originY: 0
    // Reaches the far corner whichever edge the press landed near.
    readonly property real target: Math.hypot(root.width, root.height) * 2

    anchors.fill: parent
    color: "transparent"

    Rectangle {
        id: circle
        width: 0
        height: width
        radius: width / 2
        x: root.originX - width / 2
        y: root.originY - width / 2
        color: root.rippleColor
        opacity: 0
    }

    ParallelAnimation {
        id: anim
        NumberAnimation {
            target: circle; property: "width"
            from: 0; to: root.target
            duration: Theme.animSlow; easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation { target: circle; property: "opacity"; from: 0; to: root.maxOpacity; duration: Theme.animFlick }
            NumberAnimation { target: circle; property: "opacity"; to: 0; duration: Theme.animSlow; easing.type: Easing.InQuad }
        }
    }

    function play(x, y) {
        anim.stop();
        root.originX = x;
        root.originY = y;
        anim.restart();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        // Draws only — the press is handed straight back so the control's own
        // MouseArea still sees it.
        onPressed: mouse => {
            root.play(mouse.x, mouse.y);
            mouse.accepted = false;
        }
    }
}
