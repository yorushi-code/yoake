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
// Still Nerd Font, deliberately: a coloured SVG set would look pasted on next
// to the rest of the shell, and the glyphs already match the menus and the
// control centre.
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
    property int glyphSize: 13

    property bool hovered: false
    property bool pressed: false

    implicitWidth: root.progress >= 0 || root.badge !== "" ? 24 : 18
    implicitHeight: Theme.barHeight

    readonly property bool hasRing: root.progress >= 0

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
            strokeColor: Qt.alpha(root.color, 0.22)
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
            strokeColor: root.ringColor
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

    Text {
        id: icon
        anchors.centerIn: parent
        text: root.glyph
        font.family: "Symbols Nerd Font"
        // Inside a ring the glyph has to give up a couple of pixels or the two
        // touch.
        font.pixelSize: root.hasRing ? root.glyphSize - 2 : root.glyphSize
        color: root.color
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        scale: root.pressed ? 0.85 : (root.hovered ? 1.18 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }

        // A short kick whenever the glyph itself changes, so crossing a
        // threshold registers as a change rather than a silent swap.
        SequentialAnimation {
            id: pop
            NumberAnimation { target: icon; property: "scale"; to: 1.28; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation {
                target: icon; property: "scale"; to: 1.0; duration: 160
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
            font.pixelSize: 8
            font.bold: true
        }
    }
}
