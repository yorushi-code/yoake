import QtQuick

// A labelled row with a real switch on the right and an optional expander.
//
// Replaces the Wi-Fi/Bluetooth rows' previous scheme, where clicking the left
// quarter of the row toggled power and the rest expanded the list — with
// nothing drawn to say so. There was no way to discover it short of reading the
// source, and no way to tell the toggle had been hit except by the colour of
// the whole row changing.
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool active: false
    property bool expandable: true
    property bool expanded: false

    signal toggled()
    signal expandRequested()

    height: 44
    radius: 22
    color: root.active ? Theme.accent : Theme.surface0
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    readonly property color contentColor: root.active ? Theme.crust : Theme.text

    // Expanding is the whole-row action now that the switch owns toggling.
    MouseArea {
        anchors.fill: parent
        enabled: root.expandable
        cursorShape: root.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.expandRequested()
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 14
            color: root.contentColor
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: root.label
                color: root.contentColor
                font.pixelSize: 12
            }
            Text {
                visible: root.detail !== ""
                text: root.detail
                color: root.active ? Qt.alpha(Theme.crust, 0.7) : Theme.subtext0
                font.pixelSize: 10
                width: Math.min(implicitWidth, 150)
                elide: Text.ElideRight
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.expandable
            text: Glyphs.chevronDown
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            rotation: root.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
            }
            color: root.active ? Theme.crust : Theme.subtext1
        }

        // The switch: a track with a knob that slides. Unambiguous both as a
        // control and as a state readout.
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 18
            radius: 9
            color: root.active ? Qt.alpha(Theme.crust, 0.45) : Qt.alpha(Theme.text, 0.18)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Rectangle {
                width: 14
                height: 14
                radius: 7
                y: 2
                x: root.active ? track.width - width - 2 : 2
                color: root.active ? Theme.crust : Theme.text
                Behavior on x {
                    NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                anchors.fill: parent
                // Generous margins: an 18px-tall switch is a small target, and
                // this sits at the edge of the panel.
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }
    }
}
