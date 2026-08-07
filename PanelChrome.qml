import QtQuick

// Shared visual chrome for every popup panel (frosted glass + shadow + close
// button), so CheatSheet/Dashboard/NotificationCenter don't each reimplement it
// slightly differently.
//
// It also owns the arrival now. Six panels each spelled out the same
// opacity-and-scale pair with the same two curves, and they had drifted to
// 0.88, 0.90, 0.94 and revealScale — four answers to a question that has one,
// twenty lines apiece. `Reveal` was written to end exactly that and had a
// single caller; a panel is the surface it was most obviously for.
//
// screenX/screenY must be the panel's real on-screen position — the frosted
// backing samples the wallpaper there, and a wrong value shows up as glass
// that doesn't line up with what's behind it.
Item {
    id: root
    // `data`, not `children`: a panel's content is not always an Item — a
    // HoverHandler or a Timer belongs to the sheet as much as a Rectangle
    // does, and `children` rejects both. MenuSurface has always used data.
    default property alias content: inner.data
    property real screenX: 0
    property real screenY: 0

    // Whether the panel is up. Defaults true so a chrome with no arrival of its
    // own — the notification toasts, which animate their own delegate — renders
    // exactly as before: a Behavior does not fire for a value present at
    // construction.
    property bool shown: true
    // Which corner it grows out of. Set it to the corner the panel is anchored
    // by, so it appears to come from the thing that opened it rather than from
    // the middle of the screen.
    property int origin: Item.Top
    // A panel normally grows out of its own corner and does not travel; a
    // panel summoned by a key has no corner to grow from, and the drop is what
    // says where it came from. Both, and never both at once — that is rule 1.
    property real fromScale: Theme.revealScale
    property real slideY: 0

    signal closeRequested()

    Reveal {
        anchors.fill: parent
        shown: root.shown
        origin: root.origin
        surfaceType: "narrative"
        fromScale: root.fromScale
        slideY: root.slideY

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
}
