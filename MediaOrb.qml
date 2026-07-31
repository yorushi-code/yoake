import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// The record.
//
// The cover is pressed into a disc that turns while the track plays and stops
// where it was when you pause it. Around it: the position as a ring, then the
// spectrum. Everything about the state of playback lives in one object, and it
// is an object everybody already knows how to read.
//
// The spin is a RotationAnimator, which runs on the render thread — the disc
// keeps turning at the compositor's frame rate without waking the main thread
// once, and `paused` stops it where it is rather than snapping back to zero.
//
// The bars are rectangles inside rotated items rather than a Canvas or a Shape:
// a Canvas repaints its whole texture every frame and a Shape re-tessellates,
// where sixty rectangles changing height is sixty transforms the scene graph
// absorbs on its own.
Item {
    id: root

    property real coverSize: 150
    property real barLength: 26
    property real barWidth: 3
    property real gap: 16
    property bool showProgress: true
    // Doubled and mirrored, so the lows meet at the top and the highs at the
    // bottom and the figure is symmetrical rather than reading like a graph.
    readonly property int bars: Cava.barCount * 2

    readonly property real ringRadius: root.coverSize / 2 + 7
    readonly property real barRadius: root.coverSize / 2 + root.gap
    implicitWidth: root.coverSize + (root.gap + root.barLength) * 2
    implicitHeight: implicitWidth

    readonly property bool live: Cava.active
    readonly property real swell: root.live ? Cava.bass : 0

    // ── Glow ──
    // Sized from the bass, and deliberately without a Behavior: Cava.bass is
    // already damped on its falling edge, and a Behavior restarting on every
    // frame would re-render the blur without ever finishing it.
    RectangularShadow {
        anchors.centerIn: parent
        width: root.coverSize + 24
        height: root.coverSize + 24
        radius: width / 2
        color: Theme.accent
        blur: 48
        spread: 2 + root.swell * 20
        opacity: 0.16 + root.swell * 0.44
        offset: Qt.vector2d(0, 0)
    }

    // ── Spectrum ──
    Repeater {
        model: root.bars

        delegate: Item {
            id: spoke
            required property int index

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
                y: parent.height / 2 - root.barRadius - height
                width: root.barWidth
                height: 3 + spoke.value * root.barLength
                radius: root.barWidth / 2
                color: Qt.tint(Theme.accent,
                    Qt.alpha(Theme.blue, 0.4 * (spoke.band / Cava.barCount)))
                opacity: root.live ? 0.5 + spoke.value * 0.5 : 0.2
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            }
        }
    }

    // ── Position ──
    // A ring rather than a bar under the text: on a record, position belongs on
    // the record. It does not turn with the disc — a moving reference would make
    // the reading meaningless.
    Shape {
        anchors.fill: parent
        visible: root.showProgress && Media.length > 0
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Theme.text, 0.14)
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
            strokeColor: Theme.accent
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

    // ── The disc ──
    Item {
        id: disc
        anchors.centerIn: parent
        width: root.coverSize + root.swell * 5
        height: width

        RotationAnimator on rotation {
            from: 0
            to: 360
            // Slow enough to be noticed rather than watched. A real 33⅓ turn is
            // 1.8 seconds, which at this size is a smear.
            duration: 16000
            loops: Animation.Infinite
            running: true
            paused: !Media.playing
        }

        ClippingRectangle {
            id: cover
            anchors.fill: parent
            radius: width / 2
            color: Qt.alpha(Theme.crust, 0.9)

            // What is on screen whenever a player publishes no cover, which for
            // Firefox is most sites — so this is the usual case, not the edge
            // one. The desk's own wallpaper stands in: the record is always
            // pressed with something, it is in the palette everything else is
            // in, and it changes when the desk does. A flat gradient here read
            // as a placeholder no matter how it was coloured.
            Image {
                id: fallback
                anchors.fill: parent
                visible: art.status !== Image.Ready
                source: Wallpaper.blurSource
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 256
                sourceSize.height: 256
                asynchronous: true
                cache: true
            }

            // Deepened towards the rim, the way a pressing darkens away from
            // the label.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: fallback.visible
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, 0.34) }
                    GradientStop { position: 0.55; color: Qt.alpha(Theme.crust, 0.30) }
                    GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.62) }
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
                // Holds the previous cover while the next loads instead of
                // blanking for the fetch, which is what stops the disc flashing
                // on every track change.
                retainWhileLoading: true
                visible: status === Image.Ready
            }

            // Grooves. Faint, unevenly spaced, and inside the disc so they turn
            // with it — on a cover with no strong features they are the only
            // reason the rotation is visible at all.
            Repeater {
                model: [0.94, 0.86, 0.78, 0.70, 0.60, 0.50]

                delegate: Rectangle {
                    required property var modelData
                    anchors.centerIn: parent
                    width: parent.width * modelData
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha("black", 0.13)
                }
            }

            // The label, and the spindle hole through it.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.30
                height: width
                radius: width / 2
                color: Qt.alpha(Theme.crust, 0.82)
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.14)

                Text {
                    anchors.centerIn: parent
                    text: Glyphs.music
                    font.family: Theme.fontIconFamily
                    font.pixelSize: parent.width * 0.42
                    color: Qt.alpha(Theme.text, 0.45)
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.055
                height: width
                radius: width / 2
                color: Theme.crust
            }
        }
    }

    // ── Light ──
    // Fixed while the disc turns underneath, which is what reads as a sheen on
    // vinyl rather than as a texture printed on the cover.
    ClippingRectangle {
        anchors.centerIn: parent
        width: disc.width
        height: disc.height
        radius: width / 2
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            rotation: -28
            gradient: Gradient {
                GradientStop { position: 0.00; color: "transparent" }
                GradientStop { position: 0.36; color: Qt.alpha("white", 0.13) }
                GradientStop { position: 0.44; color: Qt.alpha("white", 0.05) }
                GradientStop { position: 0.52; color: "transparent" }
                GradientStop { position: 1.00; color: "transparent" }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: disc.width
        height: disc.height
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.18)
    }
}
