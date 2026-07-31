import QtQuick
import Quickshell.Widgets

// One digit of a clock, on a strip that rolls.
//
// A clock whose numbers simply change is a label that happens to update. A
// digit that rolls into place is the difference between the shell displaying
// the time and the shell keeping it — and it costs one translation on a column
// of ten glyphs, laid out once.
//
// The strip carries an extra 0 past the end so 9 → 0 rolls forward into it
// rather than winding all the way back through eight digits, and the jump home
// happens with the animation switched off, on the frame after the roll lands.
ClippingRectangle {
    id: root

    property int value: 0
    property int pixelSize: 56
    property string family: Theme.fontDisplayFamily
    property int weight: Font.DemiBold
    // `ink`, not `color`: ClippingRectangle already has one, and shadowing it
    // means the fill and the glyph are the same property.
    property color ink: Theme.text
    property real tracking: 0

    // Measured from the face rather than assumed: a display cut is narrower
    // than a text cut at the same size, and tabular figures are all one width.
    readonly property real cellHeight: probe.implicitHeight
    readonly property real cellWidth: probe.implicitWidth

    implicitWidth: root.cellWidth
    implicitHeight: root.cellHeight
    // Exposed so groups at different sizes can share a baseline. The cell is
    // exactly the face's implicit height, so a centred glyph's baseline is the
    // font ascent — which is what the probe reports.
    baselineOffset: probe.baselineOffset
    color: "transparent"
    radius: 0

    Text {
        id: probe
        visible: false
        text: "0"
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.letterSpacing: root.tracking
        font.features: ({ "tnum": 1 })
    }

    // Which cell of the strip is showing. Held as its own property so the wrap
    // can be done without the animation chasing it.
    property int slot: 0
    property bool animate: true

    onValueChanged: {
        if (root.value === 0 && root.slot === 9) {
            // Roll forward into the spare 0 at the end, then step home unseen.
            root.slot = 10;
            wrap.restart();
        } else {
            root.slot = root.value;
        }
    }

    Timer {
        id: wrap
        interval: Theme.animNormal + 40
        onTriggered: {
            root.animate = false;
            root.slot = 0;
            // Re-enabled a frame later, or the next change would also be
            // instant.
            reArm.restart();
        }
    }

    Timer {
        id: reArm
        interval: 16
        onTriggered: root.animate = true
    }

    Column {
        id: strip
        width: root.cellWidth
        y: -root.slot * root.cellHeight

        Behavior on y {
            enabled: root.animate
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                // Overshoots a little and settles, so the digit arrives rather
                // than sliding to a stop.
                easing.bezierCurve: Theme.easeSpring
            }
        }

        Repeater {
            model: 11

            delegate: Text {
                required property int index
                width: root.cellWidth
                height: root.cellHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: index % 10
                color: root.ink
                font.family: root.family
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.letterSpacing: root.tracking
                font.features: ({ "tnum": 1 })
            }
        }
    }
}
