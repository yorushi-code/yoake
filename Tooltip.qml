import QtQuick
import Quickshell

// Hover label for bar widgets. Until now nothing in the bar explained itself —
// the tray in particular showed an application icon with no way to find out
// which application it belonged to.
//
// Delayed so sweeping the pointer across the bar on the way somewhere else
// doesn't strobe a row of tooltips.
PopupWindow {
    id: root

    property Item anchorItem: null
    property string text: ""
    property string subtext: ""
    property bool active: false

    anchor {
        item: root.anchorItem
        rect.y: root.anchorItem ? root.anchorItem.height + 4 : 0
        gravity: Edges.Bottom
        adjustment: PopupAdjustment.SlideX
    }

    implicitWidth: body.implicitWidth + 24
    implicitHeight: body.implicitHeight + 20
    color: "transparent"
    // Never grabs focus: a tooltip that stole the grab would dismiss the very
    // menu the pointer is on its way to.
    grabFocus: false

    readonly property bool shouldShow: root.active && root.text !== ""

    // Both conditions, and this one is the worst case of the family the rest of
    // the shell had. The window is mapped by `showDelay` half a second after the
    // pointer arrives, while the arrival was bound to `shouldShow` — which went
    // true at the start of that half second. The fade therefore ran to
    // completion, in full, before the tooltip existed: it appeared at full
    // opacity, always, every time.
    //
    // `visible` alone will not do either: it stays true through the exit so the
    // fade has somewhere to play, so gating on it would hold the tooltip lit
    // until the window unmapped underneath it. Asked for *and* on screen.
    property PanelArm _entrance: PanelArm {
        id: entrance
        requested: root.shouldShow && root.visible
    }

    Timer {
        id: showDelay
        interval: 500
        onTriggered: root.visible = true
    }
    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: root.visible = false
    }

    onShouldShowChanged: {
        if (root.shouldShow) {
            hideDelay.stop();
            showDelay.restart();
        } else {
            showDelay.stop();
            if (root.visible) hideDelay.restart();
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.radius - 2
        color: Qt.alpha(Theme.crust, Theme.veilSolid)
        border.color: Qt.alpha(Theme.text, Theme.strokeSoft)
        border.width: 1

        opacity: entrance.open ? 1 : 0
        scale: entrance.open ? 1 : Theme.revealScale
        transformOrigin: Item.Top
        Behavior on opacity {
            NumberAnimation {
                duration: entrance.open ? Theme.animFast : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: entrance.open ? Theme.easeEmphasized : Theme.easeExit
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: entrance.open ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: entrance.open ? Theme.easeSpring : Theme.easeExit
            }
        }

        Column {
            id: body
            anchors.centerIn: parent
            spacing: Theme.gapPair

            Text {
                text: root.text
                color: Theme.text
                font.pixelSize: Theme.fontSmall
                font.bold: root.subtext !== ""
            }
            Text {
                visible: root.subtext !== ""
                text: root.subtext
                color: Theme.subtext0
                font.pixelSize: Theme.fontLabel
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
            }
        }
    }
}
