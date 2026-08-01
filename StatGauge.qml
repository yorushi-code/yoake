import QtQuick
import QtQuick.Shapes

// One machine metric on the desktop, drawn as a ring.
//
// The flat chips this replaces were a glyph, a number and a hairline three
// pixels tall, sitting under a clock ninety-six pixels high — at that contrast
// they read as a caption on the wallpaper rather than as part of the shell. A
// ring is the same information with a shape the eye can find, and it is the
// same mark the dashboard already uses for the same numbers.
Item {
    id: root

    property string glyph: ""
    property string value: ""
    // 0..1, drives both the sweep and the warning colour.
    property real level: 0
    property real ringSize: 56
    property real thickness: 4

    readonly property color levelColor: {
        if (root.level > 0.85) return Theme.red;
        if (root.level > 0.65) return Theme.yellow;
        return Theme.deskAccent;
    }

    implicitWidth: root.ringSize
    implicitHeight: root.ringSize + 16

    Item {
        id: ring
        width: root.ringSize
        height: root.ringSize
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.alpha(Theme.deskInk, 0.22)
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.width / 2 - root.thickness
                    radiusY: ring.height / 2 - root.thickness
                    // Open at the bottom: a closed ring at zero and a closed
                    // ring at full draw the same shape.
                    startAngle: 130
                    sweepAngle: 280
                }
            }

            ShapePath {
                strokeColor: root.levelColor
                strokeWidth: root.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.width / 2 - root.thickness
                    radiusY: ring.height / 2 - root.thickness
                    startAngle: 130
                    sweepAngle: 280 * Math.max(0, Math.min(1, root.level))

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: Theme.animSlow
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasized
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.value
            color: Theme.deskInk
            font.family: Theme.fontDisplayFamily
            font.pixelSize: 15
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }

    Text {
        anchors.top: ring.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.glyph
        font.family: Theme.fontIconFamily
        font.pixelSize: 12
        color: root.levelColor
        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
    }
}
