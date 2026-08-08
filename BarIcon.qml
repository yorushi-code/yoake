import QtQuick
import QtQuick.Shapes

// One bar icon: glyph, optional progress ring, optional badge.
//
// The bar's icons were bare Nerd Font glyphs with a number beside them, which
// read as flat and gave every widget the same weight — a battery at 8% looked
// exactly like a battery at 80%. The ring puts the value into the icon itself,
// so the shape carries the state and the number becomes confirmation rather
// than the only information.
//
// Material Symbols, and the ring and the fill say different things: the ring
// is *how much*, the fill is *whether*. A battery at 80% wants an arc; a
// bluetooth radio that is on wants a solid glyph. Nerd Font could express
// neither without a second picture.
Item {
    id: root

    property string glyph: ""
    property color color: Theme.text
    // 0..1 draws a ring; negative draws none.
    property real progress: -1
    property color ringColor: Theme.accent
    // Empty for none. Kept short — this is 13px tall.
    property string badge: ""
    property color badgeColor: Theme.red
    property int glyphSize: Theme.fontIconSmall
    // 0 outline, 1 solid. For state the ring cannot carry.
    property real fill: 0

    property bool hovered: false
    property bool pressed: false

    implicitWidth: root.progress >= 0 || root.badge !== "" ? 24 : 18
    implicitHeight: Theme.barHeight

    readonly property bool hasRing: root.progress >= 0

    // How much of the ring to actually draw in colour.
    //
    // The arc was written so the shape carries the state, and it does — but a
    // complete sweep is a solid circle, and 100% battery and 100% signal are
    // the two commonest readings this bar ever shows. So the two least
    // interesting states in the shell were also the two loudest things in it:
    // a plugged-in laptop on good wifi wore two bright accent halos all day.
    // The arc is at full strength while the number is worth reading and fades
    // into its own track over the top of the range, where it is not.
    readonly property real ringPresence:
        1 - Math.max(0, (Math.min(1, root.progress) - 0.85) / 0.15)

    Shape {
        id: ring
        anchors.centerIn: parent
        width: 22
        height: 22
        visible: root.hasRing
        // The ring is redrawn on every value change, so antialiasing it in the
        // renderer rather than through a multisampled layer keeps it to one
        // draw call.
        antialiasing: true
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            strokeColor: Qt.alpha(root.color, Theme.fillActive)
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 11
                centerY: 11
                radiusX: 9
                radiusY: 9
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            // Alpha rather than an item opacity: a ShapePath has none, and
            // fading the whole Shape would take the track with it.
            strokeColor: Qt.alpha(root.ringColor, root.ringPresence)
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 11
                centerY: 11
                radiusX: 9
                radiusY: 9
                startAngle: -90
                // Never a full 360: a complete sweep and an empty one draw the
                // same arc, so a full battery would look flat.
                sweepAngle: Math.max(0, Math.min(359.9, root.progress * 360))

                Behavior on sweepAngle {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasized
                    }
                }
            }
        }
    }

    MaterialSymbol {
        id: mark
        anchors.centerIn: parent
        icon: root.glyph
        // Inside a ring the glyph has to give up a rung or the two touch.
        size: root.hasRing ? Theme.fontIconMicro : root.glyphSize
        fill: root.fill
        color: root.color
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        scale: root.pressed ? 0.85 : (root.hovered ? 1.18 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }

        // A short kick whenever the glyph itself changes, so crossing a
        // threshold registers as a change rather than a silent swap. Still
        // needed alongside the fill: a battery stepping from four bars to three
        // is a different glyph, not a different fill.
        SequentialAnimation {
            id: pop
            NumberAnimation { target: mark; property: "scale"; to: 1.28; duration: Theme.animFlick; easing.type: Easing.OutQuad }
            NumberAnimation {
                target: mark; property: "scale"; to: 1.0; duration: Theme.animNormal
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig
            }
        }
        onTextChanged: pop.restart()
    }

    // Deliberately a small chip rather than a full pill: the bar is 34px tall
    // and anything larger unbalances the island. The ring in the island's own
    // colour separates it from the glyph underneath, which it must overlap at
    // this size.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.rightMargin: -3
        width: Math.max(13, badgeText.implicitWidth + 7)
        height: 13
        radius: 6.5
        color: root.badgeColor
        border.color: Theme.crust
        border.width: 1.5
        visible: root.badge !== ""
        scale: visible ? 1 : 0
        Behavior on scale {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.badge
            color: Theme.crust
            font.pixelSize: Theme.fontMicro
            font.bold: true
        }
    }
}
