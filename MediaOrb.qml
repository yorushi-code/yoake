import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// The cover, with the music radiating from behind it.
//
// This was a spinning record, and the record was wrong. A circular crop cuts
// the composition of every square cover ever made, grooves drawn over the art
// muddy it, a tonearm crosses it, and a picture that rotates cannot be looked
// at. The one genuinely beautiful thing available was being spent on a gimmick.
//
// So the cover is a cover: square, whole, still, sharp. What reacts is
// everything around it — bars radiating from behind the corners, a halo lit in
// the album's own colours, and the position as a ring outside both. The art is
// the subject and the sound is the light on it.
//
// The bars are rectangles inside rotated items rather than a Canvas or a Shape:
// a Canvas repaints its whole texture every frame and a Shape re-tessellates,
// where rectangles changing height are transforms the scene graph absorbs.
Item {
    id: root

    property real coverSize: 150
    property real barLength: 26
    property real barWidth: 3
    property real gap: 14
    property bool showProgress: true

    // Bars start outside the square's circumcircle, or they would be drawn
    // under the corners of the cover and only the ones on the axes would show.
    readonly property real barRadius: root.coverSize * 0.707 + root.gap
    readonly property real ringRadius: root.barRadius + root.barLength + 7

    // Only as many as the circumference can show. One per four pixels keeps
    // them separate at every size the shell uses; on a small disc, fifty-six
    // land two pixels apart and overlap into a fringe.
    readonly property int bars: {
        const room = Math.floor(Math.PI * 2 * root.barRadius / 4);
        return Math.max(12, Math.min(Cava.barCount * 2, room - (room % 2)));
    }

    implicitWidth: (root.ringRadius + 6) * 2
    implicitHeight: implicitWidth

    // The cover that makes the whole figure fit a box this tall. Callers know
    // the room they have; they do not know the arithmetic between the cover,
    // the bars and the ring, and the caller that worked it out by hand got it
    // wrong -- the ring was drawn 29px outside the card and clipped flat.
    function coverFor(diameter) {
        return Math.max(24, (diameter / 2 - root.gap - root.barLength - 13) / 0.707);
    }

    readonly property bool live: Cava.active
    readonly property real swell: root.live ? Cava.bass : 0

    // ── Halo ──
    // The cover itself, blown up and blurred behind the cover. The light around
    // an album is the album's own colours rather than one accent for every
    // record, which is the difference between a glow and a highlight.
    Image {
        id: haloSource
        anchors.centerIn: parent
        width: root.coverSize
        height: root.coverSize
        source: Media.cover
        sourceSize.width: 128
        sourceSize.height: 128
        asynchronous: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.centerIn: parent
        width: root.coverSize * 1.5
        height: root.coverSize * 1.5
        source: haloSource
        visible: haloSource.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        blurMultiplier: 1.6
        saturation: 0.5
        opacity: 0.30 + root.swell * 0.30
    }

    // Falls back to the accent when there is no cover to take colour from.
    RectangularShadow {
        anchors.centerIn: parent
        width: root.coverSize
        height: root.coverSize
        radius: root.coverSize * 0.16
        visible: haloSource.status !== Image.Ready
        color: MediaTint.accent
        blur: 48
        spread: 2 + root.swell * 18
        opacity: 0.18 + root.swell * 0.40
        offset: Qt.vector2d(0, 0)
    }

    // ── Spectrum ──
    Repeater {
        model: root.bars

        delegate: Item {
            id: spoke
            required property int index

            // Mirrored, so the lows meet at the top and the highs at the bottom
            // and the figure is symmetrical rather than reading like a graph.
            readonly property int band: spoke.index < Cava.barCount
                ? Math.floor(spoke.index * Cava.barCount / (root.bars / 2))
                : Math.floor((root.bars - 1 - spoke.index) * Cava.barCount / (root.bars / 2))
            readonly property real value: root.live
                ? Math.max(0, Math.min(1, Cava.values[spoke.band] || 0))
                : 0

            anchors.fill: parent
            rotation: spoke.index * 360 / root.bars

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - root.barRadius - height
                width: root.barWidth
                // The resting length follows the band rather than being one
                // number for every spoke. An even floor is a ring of identical
                // ticks -- a clock face, not an instrument -- and it also
                // throws away the one thing the figure could say while nothing
                // is playing: where the lows are. They meet at the top, so at
                // rest the corona is already the shape the music will grow
                // into.
                height: root.barLength
                    * (0.16 + 0.26 * (1 - spoke.band / Cava.barCount))
                    + spoke.value * root.barLength * 0.78
                radius: root.barWidth / 2
                // The ramp runs between the sleeve's two colours rather than
                // to the shell's blue: the whole figure should belong to the
                // record, not half of it.
                color: Qt.tint(MediaTint.accent,
                    Qt.alpha(MediaTint.accentAlt, 0.55 * (spoke.band / Cava.barCount)))
                opacity: root.live ? 0.5 + spoke.value * 0.5 : 0.18
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            }
        }
    }

    // ── Position ──
    Shape {
        anchors.fill: parent
        visible: root.showProgress && Media.length > 0
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Theme.text, 0.12)
            strokeWidth: 2.5
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: MediaTint.accent
            strokeWidth: 2.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: Math.max(0, Math.min(359.9, Media.progress * 360))
            }
        }
    }

    // ── The cover ──
    ClippingRectangle {
        id: cover
        anchors.centerIn: parent
        // Breathes with the bass. The only motion the art itself is allowed,
        // because it does not stop it being looked at.
        width: root.coverSize + root.swell * 5
        height: width
        radius: width * 0.16
        color: Qt.alpha(Theme.crust, 0.9)

        // What is on screen whenever a player publishes no cover, which for
        // Firefox is most sites — so this is the usual case, not the edge one.
        // The desk's own wallpaper stands in: always something, always in the
        // palette everything else is in, and it changes when the desk does.
        Image {
            id: fallback
            anchors.fill: parent
            visible: art.status !== Image.Ready
            source: Wallpaper.isVideo ? Wallpaper.stillPath : Wallpaper.path
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            sourceSize.height: 640
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            visible: fallback.visible
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(MediaTint.accent, 0.30) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.55) }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: fallback.visible
            text: Glyphs.music
            font.family: Theme.fontIconFamily
            font.pixelSize: root.coverSize * 0.22
            color: Qt.alpha(Theme.text, 0.5)
        }

        Image {
            id: art
            anchors.fill: parent
            source: Media.cover
            fillMode: Image.PreserveAspectCrop
            // Covers are served at 300-640px; decoding to 640 costs one texture
            // and is the difference between a cover and a mosaic.
            sourceSize.width: 640
            sourceSize.height: 640
            asynchronous: true
            // Holds the previous cover while the next loads instead of blanking
            // for the fetch, which is what stops it flashing on a track change.
            retainWhileLoading: true
            visible: status === Image.Ready
        }
    }

    // A hairline, so the cover reads as a printed square rather than as a hole
    // cut in the card.
    Rectangle {
        anchors.centerIn: parent
        width: cover.width
        height: cover.height
        radius: cover.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, Theme.strokeFirm)
    }
}
