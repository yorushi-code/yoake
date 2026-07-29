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
    property alias borderColor: border.border.color
    property real screenX: 0
    property real screenY: 0
    signal closeRequested()

    RectangularShadow {
        anchors.fill: glass
        radius: glass.radius
        color: Theme.shadowColor
        blur: Theme.shadowBlur
        spread: Theme.shadowSpread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    FrostedBackground {
        id: glass
        anchors.fill: parent
        radius: Theme.radiusLarge
        screenX: root.screenX
        screenY: root.screenY
        // Denser than the bar's glass: these panels carry small body text that
        // has to stay readable over arbitrary wallpaper detail.
        tintOpacity: 0.78

        Item {
            id: inner
            anchors.fill: parent
        }
    }

    // Drawn outside the clipping backing so the stroke isn't cut in half.
    Rectangle {
        id: border
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: "transparent"
        border.color: Qt.alpha(Theme.text, 0.12)
        border.width: 1
    }

    Rectangle {
        width: 24
        height: 24
        radius: 12
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        color: closeMa.containsMouse ? Theme.red : Qt.alpha(Theme.text, 0.10)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        scale: closeMa.containsMouse ? 1.1 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
        }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: Theme.text
            font.pixelSize: 11
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
