import QtQuick
import QtQuick.Effects

// Shared visual chrome for every popup panel (frosted glass + shadow + close
// button), so CheatSheet/ControlCenter/NotificationCenter don't each
// reimplement it slightly differently.
//
// screenX/screenY must be the panel's real on-screen position — the frosted
// backing samples the wallpaper there, and a wrong value shows up as glass
// that doesn't line up with what's behind it.
Item {
    id: root
    default property alias content: inner.children
    property real screenX: 0
    property real screenY: 0
    signal closeRequested()

    // The same object the islands and the cards are made of, so a panel is a
    // bigger relative of them rather than a different idea of a surface.
    Surface {
        id: glass
        anchors.fill: parent
        radius: Theme.radiusPanel
        elevation: "panel"
        screenX: root.screenX
        screenY: root.screenY
        tintOpacity: 0.78

        Item {
            id: inner
            anchors.fill: parent
        }
    }

    Rectangle {
        width: 24
        height: 24
        radius: Theme.radiusChip
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        color: closeMa.containsMouse ? Theme.red : Qt.alpha(Theme.text, Theme.fillMuted)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        scale: closeMa.containsMouse ? 1.1 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
        }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Theme.text
            font.pixelSize: Theme.fontSmall
        }

        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }
    }
}
