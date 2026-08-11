import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// One frame in the wallpaper filmstrip.
//
// ClippingRectangle, not `Rectangle { clip: true }`: Qt's clip is a rectangular
// scissor that ignores `radius`, so the thumbnail's square corners used to poke
// out from under the rounded frame — which is exactly what stood out against
// the selection ring.
//
// The tile draws a still thumbnail even for video. Preview playback belongs to
// the picker, which runs one full-screen decoder for the focused entry; a
// player per tile is a dozen decoders for a strip where only one frame is being
// looked at.
Item {
    id: root

    required property var modelData
    required property int index

    // Where the strip's attention is. Distinct from `applied`, which is the
    // wallpaper actually on screen.
    property bool focusedItem: false
    property bool applied: false
    property bool thumbReady: false

    signal activated()
    signal requested()

    // Unfocused frames sit back rather than disappearing: the strip has to read
    // as a continuous reel, and the focused frame has to be unmistakable.
    scale: root.focusedItem ? 1.0 : 0.87
    z: root.focusedItem ? 2 : (mouse.containsMouse ? 1 : 0)
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpringBig
        }
    }

    RectangularShadow {
        anchors.fill: frame
        radius: frame.radius
        color: root.focusedItem ? Theme.accent : Theme.shadowColor
        blur: root.focusedItem ? 34 : Theme.shadowBlur
        spread: root.focusedItem ? 2 : Theme.shadowSpread
        offset: root.focusedItem ? Qt.vector2d(0, 0) : Qt.vector2d(0, 6)
        opacity: root.focusedItem ? 0.85 : 0.4
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        Behavior on blur { NumberAnimation { duration: Theme.animNormal } }
    }

    ClippingRectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radius + 6
        color: Theme.surface0

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

        // Everything but the focused frame is pushed towards the backdrop, so
        // the eye lands on one image instead of scanning a wall of them.
        Rectangle {
            anchors.fill: parent
            color: Theme.crust
            opacity: root.focusedItem ? 0 : (mouse.containsMouse ? 0.18 : 0.45)
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        }

        // Placeholder while the thumbnail is still being generated: a strip of
        // empty rectangles reads as broken, a pulsing one reads as loading.
        Rectangle {
            id: placeholder
            anchors.fill: parent
            color: Theme.surface1
            visible: !root.thumbReady || thumb.status !== Image.Ready
            opacity: 0.5 + 0.3 * Math.sin(shimmer.phase)
            QtObject {
                id: shimmer
                property real phase: 0
                NumberAnimation on phase {
                    // By id, and it matters more here than it reads: a
                    // property-value-source animation runs by default, and
                    // `parent` inside one resolves to nothing -- so this
                    // shimmered forever behind every thumbnail that had already
                    // loaded, in a grid of them.
                    running: placeholder.visible
                    loops: Animation.Infinite
                    from: 0
                    to: Math.PI * 2
                    duration: Theme.animDrift
                }
            }
        }

        // Caption only on the focused frame. On every frame the strip turns
        // into a list of filenames, which is the opposite of what a filmstrip
        // is for.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 40
            opacity: root.focusedItem ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, Theme.veilSolid) }
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 9
                text: root.modelData.label
                color: Theme.text
                font.pixelSize: Theme.fontSmall
                font.bold: true
                elide: Text.ElideRight
            }
        }

        // Video badge, so it is obvious before focusing which frames move.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 7
            width: 22
            height: 22
            radius: Theme.radiusChip
            visible: root.modelData.video
            color: Qt.alpha(Theme.crust, Theme.veilDense)

            Text {
                anchors.centerIn: parent
                text: Glyphs.video
                font.family: Theme.fontIconFamily
                font.pixelSize: Theme.fontIconMicro
                color: Theme.accent
            }
        }
    }

    // Focus ring drawn outside the clip so the stroke is not halved.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: frame.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: root.focusedItem ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    }

    // The wallpaper currently on screen. Marked even when it is not the frame
    // under attention — otherwise walking the strip loses track of where you
    // started.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 7
        width: 22
        height: 22
        radius: Theme.radiusChip
        visible: root.applied
        color: Theme.accent

        Text {
            anchors.centerIn: parent
            text: Glyphs.check
            font.family: Theme.fontIconFamily
            font.pixelSize: Theme.fontIconMicro
            color: Theme.crust
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Hovering moves attention, clicking commits. Splitting the two is what
        // lets the full-screen preview follow the cursor without a stray click
        // changing the wallpaper.
        onEntered: root.requested()
        onClicked: root.focusedItem ? root.activated() : root.requested()
    }
}
