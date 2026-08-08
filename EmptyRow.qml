import QtQuick

// What a list says when it has nothing in it.
//
// A panel that lists devices and finds none must say so. Left blank it reads as
// a panel that failed to load, and the difference between "no bluetooth devices
// nearby" and "this thing is broken" is a sentence.
Item {
    id: root

    property string text: ""
    property string glyph: ""

    implicitWidth: 200
    implicitHeight: 84

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacing

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.glyph !== ""
            icon: root.glyph
            size: Theme.fontIcon
            color: Qt.alpha(Theme.text, Theme.inkGhost)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.text
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
        }
    }
}
