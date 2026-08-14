import QtQuick

// What a sheet is about, at the top of it.
//
// Title, then the technical name under it. The second line is what makes these
// panels usable when two things are called the same: two "Analog Stereo"
// outputs are indistinguishable until one of them says `alsa_output.pci-0000…`.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property color ink: Theme.text

    default property alias trailing: slot.data

    implicitHeight: Math.max(labels.implicitHeight, slot.childrenRect.height)

    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: Theme.gapWide
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapPair

        Text {
            width: parent.width
            text: root.title
            color: root.ink
            font.family: Theme.fontDisplayFamily
            font.pixelSize: Theme.fontDisplay
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
