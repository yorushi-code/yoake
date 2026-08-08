import QtQuick

// Two to four mutually exclusive views of the same list.
//
// The marker travels, because it is the same marker: Outputs and Inputs are two
// states of one control, and a highlight that appears over there while another
// disappears over here says they are two controls that happen to be adjacent.
// This is rule 7 in the smallest place it applies.
Item {
    id: root

    // Plain strings.
    property var model: []
    property int current: 0
    property string tone: "audio"

    signal picked(int index)

    implicitHeight: 34
    implicitWidth: 240

    readonly property real cellWidth: root.model.length > 0
        ? root.width / root.model.length
        : root.width

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusChip
        color: Qt.alpha(Theme.text, Theme.fillMuted)
    }

    Traveller {
        id: marker
        active: root.current >= 0 && root.current < root.model.length
        slotX: Math.round(root.cellWidth * root.current) + 3
        slotY: 3
        slotWidth: Math.round(root.cellWidth) - 6
        slotHeight: root.height - 6
        span: root.width

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusChip - 2
            color: Theme.tone(root.tone)
        }
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: root.model

            delegate: Item {
                id: cell
                required property var modelData
                required property int index

                width: root.cellWidth
                height: root.height

                readonly property bool chosen: root.current === cell.index

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData
                    color: cell.chosen ? Theme.onTone(root.tone)
                        : (cellHit.containsMouse ? Theme.text : Theme.subtext0)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: cell.chosen ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    id: cellHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(cell.index)
                }
            }
        }
    }
}
