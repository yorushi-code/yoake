import QtQuick
import QtQuick.Effects

// One card in the wallpaper grid.
//
// Video wallpapers preview on hover, but the player itself is owned by the
// picker and lent to whichever tile the cursor is over. One MediaPlayer per
// tile would mean a dozen decoders running behind a grid where only one card
// can be under the pointer.
Item {
    id: root

    required property var modelData
    required property int index

    property bool current: false
    property bool thumbReady: false
    // Set by the picker to the tile the shared video player is attached to.
    property Item videoSurface: null

    signal activated()

    scale: mouse.containsMouse ? 1.05 : 1
    z: mouse.containsMouse ? 1 : 0
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpring
        }
    }

    RectangularShadow {
        anchors.fill: frame
        radius: frame.radius
        color: root.current ? Theme.accent : Theme.shadowColor
        blur: root.current ? 26 : Theme.shadowBlur
        spread: root.current ? 2 : Theme.shadowSpread
        offset: root.current ? Qt.vector2d(0, 0) : Qt.vector2d(0, 4)
        opacity: root.current ? 0.8 : (mouse.containsMouse ? 0.9 : 0.5)
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radius + 4
        color: Theme.surface0
        clip: true

        Image {
            id: thumb
            anchors.fill: parent
            source: root.thumbReady ? "file://" + root.modelData.thumb : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        }

        // Where the picker reparents its single VideoOutput while this tile is
        // hovered. Empty otherwise.
        Item {
            id: videoSlot
            objectName: "videoSlot"
            anchors.fill: parent
        }

        // Placeholder while the thumbnail is still being generated: a grid of
        // empty rectangles reads as broken, a pulsing one reads as loading.
        Rectangle {
            anchors.fill: parent
            color: Theme.surface1
            visible: !root.thumbReady || thumb.status !== Image.Ready
            opacity: 0.5 + 0.3 * Math.sin(shimmer.phase)
            QtObject {
                id: shimmer
                property real phase: 0
                NumberAnimation on phase {
                    running: parent.visible
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: 1600
                }
            }
        }

        // Caption strip. Gradient rather than a flat bar so a bright wallpaper
        // does not put light text on light pixels.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 44
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.92) }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                text: root.modelData.label
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
        }

        // Video badge, so it is obvious before hovering which cards move.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            width: videoGlyph.width + 14
            height: 22
            radius: 11
            visible: root.modelData.video
            color: Qt.alpha(Theme.crust, 0.8)

            Text {
                id: videoGlyph
                anchors.centerIn: parent
                text: Glyphs.video
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: Theme.accent
            }
        }
    }

    // Selected ring drawn outside the clip so the stroke is not halved.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: frame.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: root.current ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    readonly property bool hovered: mouse.containsMouse
    readonly property Item slot: videoSlot
}
