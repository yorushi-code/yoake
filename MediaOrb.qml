import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// The album, with the music drawn around it.
//
// A round cover ringed by the spectrum, mirrored left to right so the figure is
// symmetrical rather than reading left-to-right like a graph. The point is that
// the art and the sound are one object: a rectangular cover with a bar chart
// beside it is two widgets sharing a card, and this is a thing that reacts.
//
// Bars are plain rectangles inside rotated items rather than a Canvas or a
// Shape. A Canvas repaints the whole texture every frame and a Shape
// re-tessellates; sixty rectangles changing height is sixty transform updates
// the scene graph handles without touching the CPU.
Item {
    id: root

    // Diameter of the cover itself. Bars live outside it.
    property real coverSize: 150
    property real barLength: 26
    property real barWidth: 3
    property real gap: 12
    // Doubled and mirrored, so the low frequencies meet at the top and the
    // highs meet at the bottom.
    readonly property int bars: Cava.barCount * 2

    readonly property real radius: root.coverSize / 2 + root.gap
    implicitWidth: root.coverSize + (root.gap + root.barLength) * 2
    implicitHeight: implicitWidth

    readonly property bool live: Cava.active

    // Bass pushes the whole figure open a little, so the orb breathes with the
    // track instead of only its edge moving.
    readonly property real swell: root.live ? Cava.bass : 0

    // A glow behind everything, tinted by the accent. Sized from the bass, and
    // deliberately not animated by a Behavior: Cava.bass is already damped on
    // its falling edge, and a Behavior restarting every frame would re-render
    // the blur without ever finishing.
    RectangularShadow {
        anchors.centerIn: parent
        width: root.coverSize + 20
        height: root.coverSize + 20
        radius: width / 2
        color: Theme.accent
        blur: 44
        spread: 2 + root.swell * 18
        opacity: 0.18 + root.swell * 0.42
        offset: Qt.vector2d(0, 0)
    }

    // ── Spectrum ──
    Repeater {
        model: root.bars

        delegate: Item {
            id: spoke
            required property int index

            // Mirrored: the first half runs clockwise from the top, the second
            // half is its reflection, so index and its partner share a value.
            readonly property int band: spoke.index < Cava.barCount
                ? spoke.index
                : root.bars - 1 - spoke.index
            readonly property real value: root.live
                ? Math.max(0, Math.min(1, Cava.values[spoke.band] || 0))
                : 0

            anchors.fill: parent
            rotation: spoke.index * 360 / root.bars

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - root.radius - height
                width: root.barWidth
                height: 4 + spoke.value * root.barLength
                radius: root.barWidth / 2
                // Tinted along the ring so the figure has a direction rather
                // than being one flat colour.
                color: Qt.tint(Theme.accent,
                    Qt.alpha(Theme.blue, 0.35 * (spoke.band / Cava.barCount)))
                opacity: root.live ? 0.55 + spoke.value * 0.45 : 0.25
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            }
        }
    }

    // ── Cover ──
    ClippingRectangle {
        id: cover
        anchors.centerIn: parent
        width: root.coverSize + root.swell * 6
        height: width
        radius: width / 2
        color: Qt.alpha(Theme.text, 0.06)

        // What stands in when a player publishes no art, which Firefox does for
        // most tracks. A flat grey disc with a note on it is the shape of a
        // missing image; a lit one is a deliberate state, and it is what is on
        // screen most of the time.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: art.status !== Image.Ready
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, 0.42) }
                GradientStop { position: 0.55; color: Qt.alpha(Theme.blue, 0.22) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.55) }
            }

            Text {
                anchors.centerIn: parent
                text: Glyphs.music
                font.family: Theme.fontIconFamily
                font.pixelSize: root.coverSize * 0.26
                color: Qt.alpha(Theme.text, 0.55)
                // Lifts with the beat, so even a track with no art has
                // something that answers the music.
                scale: 1 + root.swell * 0.14
            }
        }

        Image {
            id: art
            anchors.fill: parent
            source: Media.cover
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 320
            sourceSize.height: 320
            asynchronous: true
            // Holds the previous cover while the next one loads instead of
            // blanking for the fetch, which is what stops the disc flickering
            // on every track change.
            retainWhileLoading: true
            visible: status === Image.Ready
        }
    }

    // A hairline around the cover, so it reads as a disc rather than as a
    // circular crop of a photograph.
    Rectangle {
        anchors.centerIn: parent
        width: cover.width
        height: cover.height
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.16)
    }
}
