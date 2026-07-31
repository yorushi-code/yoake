import QtQuick
import QtQuick.Effects
import Quickshell

// Now-playing popup, in the bottom-right corner.
//
// It used to sit centred at the bottom, which on a browser is exactly where
// video controls, cookie banners and chat inputs live — it covered the page
// with something the user had not asked for and could not get rid of. Three
// things changed:
//
//   - It does not appear at all while the window playing the audio is focused.
//     Telling you what is playing, over the player you are looking at, is
//     noise.
//   - Resting the pointer on it makes it ghost: nearly transparent and
//     click-through, so whatever it is covering can be used. The ghost is
//     latched until the popup hides, because dropping the input region ends
//     the hover, and re-arming would flicker it back on the next frame.
//   - It can be dismissed outright: a close button, or drag it aside.
PanelWindow {
    id: win

    // Wider than the card on purpose: layer-shell surfaces cannot be dragged
    // outside their own geometry, so the slack to the card's left is the
    // travel the dismiss gesture needs.
    readonly property int cardWidth: 440
    readonly property int cardHeight: 116

    anchors.bottom: true
    anchors.right: true
    margins.bottom: 24
    margins.right: 24
    implicitWidth: win.cardWidth + 280
    implicitHeight: win.cardHeight + 14
    color: "transparent"
    exclusiveZone: 0
    focusable: false

    // Explicit mapping bool — see ControlCenter.qml. Keeps the window mapped
    // through the whole exit instead of unmapping instantly.
    property bool mapped: false
    visible: mapped

    // Latched: once ghosted, it stays out of the way until it hides. Collapsing
    // the input region is what ends the hover that set it, so re-evaluating
    // would toggle it back on the very next frame.
    property bool ghosted: false
    property real dragOffset: 0

    // Ghosting drops the input region entirely, which is the point: the popup
    // stops being a click-trap over whatever is underneath it.
    mask: Region { item: win.ghosted ? null : card }

    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: win.mapped = false
    }
    Connections {
        target: Media
        function onOsdShownChanged() {
            if (Media.osdShown) {
                hideDelay.stop();
                win.mapped = true;
                win.ghosted = false;
                win.dragOffset = 0;
                ghostDwell.stop();
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: win.mapped = Media.osdShown

    // A dwell rather than an immediate ghost: the pointer crossing the corner
    // on its way somewhere else should not blank the popup, and a grab for the
    // dismiss drag has to survive long enough to start.
    Timer {
        id: ghostDwell
        interval: 320
        onTriggered: win.ghosted = true
    }

    Item {
        id: host
        width: win.cardWidth
        height: win.cardHeight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        x: 0
        opacity: Media.osdShown ? (win.ghosted ? 0.12 : 1) : 0
        // Rises into place rather than just fading — reinforces that it came
        // from the bottom edge. On exit it sinks back down with an accelerate
        // curve, matching the other panels.
        y: Media.osdShown ? 0 : 20
        Behavior on opacity {
            NumberAnimation {
                duration: Media.osdShown ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Media.osdShown ? Theme.easeEmphasized : Theme.easeExit
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Media.osdShown ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Media.osdShown ? Theme.easeSpring : Theme.easeExit
            }
        }

        // A handler rather than a MouseArea: the transport buttons have their
        // own hover areas, and a parent MouseArea would lose the hover — and
        // hide the close button — the moment the pointer crossed one.
        HoverHandler {
            id: hover
            onHoveredChanged: hovered ? ghostDwell.restart() : ghostDwell.stop()
        }

        RectangularShadow {
            anchors.fill: card
            radius: card.radius
            color: Theme.shadowColor
            blur: Theme.shadowBlur
            spread: Theme.shadowSpread
            offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
        }

        FrostedBackground {
            id: card
            anchors.fill: parent
            radius: Theme.radiusLarge
            screenX: Screen.width - win.margins.right - win.cardWidth + host.x
            screenY: Screen.height - win.margins.bottom - win.implicitHeight + host.y + 7
            tintOpacity: 0.80

            // Under the controls, so the transport buttons still take their own
            // clicks and only the card body starts a drag.
            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: host
                drag.axis: Drag.XAxis
                drag.minimumX: -240
                drag.maximumX: 0

                // A drag must not be cut short by the popup ghosting out from
                // under the cursor mid-gesture.
                onPressed: ghostDwell.stop()
                onReleased: {
                    if (host.x < -80) {
                        Media.hideOsd();
                    } else {
                        returnHome.restart();
                        ghostDwell.restart();
                    }
                }
            }

            NumberAnimation {
                id: returnHome
                target: host
                property: "x"
                to: 0
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeSpringBig
            }

            // The same card the desktop widget draws. Two copies of one
            // player is how they end up different players.
            MediaCard {
                anchors.fill: parent
                showGlass: false
                radius: card.radius
            }
        }

        // Inside the card's bounds, because the window's input region is the
        // card: a button hanging over the edge would not be clickable. Shown
        // only while the pointer is near — a permanent ✕ on a popup that
        // dismisses itself after four seconds is clutter.
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            width: 22
            height: 22
            radius: 11
            color: closeArea.containsMouse ? Theme.red : Theme.surface1
            opacity: hover.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            Text {
                anchors.centerIn: parent
                text: Glyphs.close
                font.family: "Symbols Nerd Font"
                font.pixelSize: 11
                color: Theme.text
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: ghostDwell.stop()
                onClicked: Media.hideOsd()
            }
        }
    }
}
