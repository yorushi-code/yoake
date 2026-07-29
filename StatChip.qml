import QtQuick

// Compact metric readout: glyph, value, and a fill bar underneath that turns
// warm as the metric climbs, so load is readable at a glance without having
// to parse the number.
Item {
    id: root

    property string glyph: ""
    property string label: ""
    // 0..1, drives both the bar width and the warning colour.
    property real level: 0

    implicitWidth: 78
    implicitHeight: 30

    readonly property color levelColor: {
        if (level > 0.85) return Theme.red;
        if (level > 0.65) return Theme.yellow;
        return Theme.accent;
    }

    Column {
        anchors.fill: parent
        spacing: 4

        Row {
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: root.levelColor
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                color: Theme.subtext1
                font.pixelSize: 11
            }
        }

        Rectangle {
            width: parent.width
            height: 3
            radius: 1.5
            color: Qt.alpha(Theme.text, 0.13)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.level))
                height: parent.height
                radius: parent.radius
                color: root.levelColor
                Behavior on width {
                    NumberAnimation { duration: Theme.animSlow; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                }
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
        }
    }
}
