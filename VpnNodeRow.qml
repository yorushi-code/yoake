import QtQuick

// One node inside a selector group.
//
// Latency is shown as a measurement or as an explicit miss, never as a blank:
// "no number" and "the probe failed" are different facts, and conflating them
// is how a dead node passes for an untested one.
Rectangle {
    id: root

    required property string name
    property bool current: false
    // Milliseconds, null when the probe failed, undefined when never probed.
    property var delay: undefined
    property bool probing: false

    signal activated()

    height: 36
    radius: Theme.radius
    color: root.current
        ? Qt.alpha(Theme.accent, 0.16)
        : (ma.containsMouse ? Qt.alpha(Theme.text, 0.07) : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    readonly property color delayColor: {
        if (root.delay === null) return Theme.red;
        if (root.delay === undefined) return Theme.subtext0;
        if (root.delay < 150) return Theme.green;
        if (root.delay < 400) return Theme.yellow;
        return Theme.red;
    }

    Text {
        id: mark
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        text: root.current ? Glyphs.check : ""
        font.family: "Symbols Nerd Font"
        font.pixelSize: 12
        color: Theme.accent
    }

    Text {
        anchors.left: mark.right
        anchors.leftMargin: 6
        anchors.right: pill.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        color: root.current ? Theme.text : Theme.subtext1
        font.pixelSize: Theme.fontBody
        font.bold: root.current
        elide: Text.ElideRight
    }

    Rectangle {
        id: pill
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: pillText.width + 14
        height: 19
        radius: 9.5
        color: Qt.alpha(root.delayColor, 0.16)
        visible: root.delay !== undefined || root.probing

        // A re-probe used to replace every number with an ellipsis, erasing
        // readings that were about to be confirmed. Only nodes that have never
        // been measured say nothing; the rest fade while the new number arrives.
        opacity: root.probing && root.delay !== undefined ? 0.45 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: {
                if (root.delay === undefined) return "…";
                if (root.delay === null) return "нет";
                return root.delay + " мс";
            }
            color: root.delayColor
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
