import QtQuick
import QtQuick.Shapes

// A resource, drawn as a ring with the number inside it.
//
// The number is the point and the ring is the context: 41°C means nothing on
// its own, and 41°C against a track that is a fifth full means "cold". Both in
// one mark is what lets three of these sit side by side and be read at a
// glance rather than compared digit by digit.
Item {
    id: root

    property real value: 0        // 0..1, drives the arc
    property string primary: ""   // the number in the middle
    property string label: ""     // what it is
    property string secondary: "" // a second fact, set beside the ring
    property color arcColor: Theme.accent

    implicitWidth: 128
    implicitHeight: 128

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(root.arcColor, 0.18)
            strokeWidth: 9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 8
                radiusY: root.height / 2 - 8
                // A gap at the bottom rather than a closed circle: the track has
                // to have a visible beginning or a full ring and an empty one
                // draw the same shape.
                startAngle: 130
                sweepAngle: 280
            }
        }

        ShapePath {
            strokeColor: root.arcColor
            strokeWidth: 9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - 8
                radiusY: root.height / 2 - 8
                startAngle: 130
                sweepAngle: 280 * Math.max(0, Math.min(1, root.value))

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

    Column {
        anchors.centerIn: parent
        spacing: Theme.gapPair

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.primary
            color: Theme.text
            font.family: Theme.fontDisplayFamily
            font.pixelSize: Theme.fontDisplay
            font.weight: Font.Medium
            font.letterSpacing: Theme.trackDisplay
            font.features: ({ "tnum": 1 })
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.secondary !== ""
            text: root.secondary
            color: Qt.alpha(Theme.subtext0, Theme.inkStrong)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMicro
            font.features: ({ "tnum": 1 })
        }
    }
}
