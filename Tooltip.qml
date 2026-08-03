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
        color: Qt.alpha(Theme.crust, 0.94)
        border.color: Qt.alpha(Theme.text, Theme.strokeSoft)
        border.width: 1

        opacity: root.shouldShow ? 1 : 0
        scale: root.shouldShow ? 1 : 0.9
        transformOrigin: Item.Top
        Behavior on opacity {
            NumberAnimation {
                duration: root.shouldShow ? Theme.animFast : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.shouldShow ? Theme.easeEmphasized : Theme.easeExit
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.shouldShow ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.shouldShow ? Theme.easeSpring : Theme.easeExit
            }
        }

        Column {
            id: body
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: root.text
                color: Theme.text
                font.pixelSize: 11
                font.bold: root.subtext !== ""
            }
            Text {
                visible: root.subtext !== ""
                text: root.subtext
                color: Theme.subtext0
                font.pixelSize: 10
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
            }
        }
    }
}
