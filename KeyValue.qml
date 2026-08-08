import QtQuick

// A named number, on one line, with the name at the left and the number at the
// right. The gap between them is the point: a value pushed against its label
// has to be read as a phrase, and a value on the far margin can be read down a
// column with the others.
Item {
    id: root

    property string key: ""
    property string value: ""
    property color valueColor: Theme.text
    property real pixelSize: Theme.fontSmall

    implicitHeight: Math.max(keyText.implicitHeight, valueText.implicitHeight)
    implicitWidth: keyText.implicitWidth + valueText.implicitWidth + Theme.gapSection

    Text {
        id: keyText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.key
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        elide: Text.ElideRight
        width: Math.min(implicitWidth, root.width - valueText.width - Theme.spacing)
    }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.valueColor
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
    }
}
