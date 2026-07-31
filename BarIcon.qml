import QtQuick

// One status mark in the masthead: a glyph, an optional meter, an optional
// count.
//
// This drew a progress ring around the glyph. A ring is a moulded shape, and
// among set type it was the last thing on the bar still speaking the old
// language — it also cost a Shape with two ShapePaths redrawn on every value
// change, per widget.
//
// The meter is a rule instead: it sits under the mark, fills from the left, and
// is the same device the focused desk uses. Same information, one quad, and it
// belongs to the page.
//
// Still Nerd Font for the glyph, deliberately: a coloured SVG set would look
// pasted on beside the type, and these already match the menus.
Item {
    id: root

    property string glyph: ""
    property color color: Theme.text
    // 0..1 draws a meter; negative draws none.
    property real progress: -1
    property color ringColor: Theme.accent
    // Empty for none. Set as a superscript figure, not a filled dot.
    property string badge: ""
    property color badgeColor: Theme.red
    property int glyphSize: 13

    property bool hovered: false
    property bool pressed: false

    implicitWidth: Math.max(mark.implicitWidth, root.progress >= 0 ? 18 : 0)
    implicitHeight: 22

    readonly property bool hasMeter: root.progress >= 0

    Text {
        id: mark
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: root.glyph
        font.family: Theme.fontIconFamily
        font.pixelSize: root.glyphSize
        color: root.color
        opacity: root.pressed ? 0.6 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // A short pop when the glyph itself changes — the battery crossing a
        // step, the volume crossing mute. Nothing pops on a value that only
        // moves the meter.
        onTextChanged: pop.restart()
        SequentialAnimation {
            id: pop
            NumberAnimation { target: mark; property: "scale"; to: 1.16; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: mark; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.OutBack }
        }
    }

    // The count, set as a superscript rather than enclosed. An enclosed number
    // is a badge; a raised one is an annotation, which is what it is.
    Text {
        anchors.left: mark.right
        anchors.leftMargin: 1
        anchors.top: parent.top
        anchors.topMargin: -2
        visible: root.badge !== ""
        text: root.badge
        color: root.badgeColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontMicro
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }

    // The meter.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        height: Theme.ruleBold
        visible: root.hasMeter

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(root.color, 0.20)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            color: root.ringColor
            Behavior on width {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasized
                }
            }
        }
    }
}
