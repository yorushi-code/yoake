import QtQuick

// What the shell shows when there is nothing to show.
//
// One component rather than a line of grey text in five files: an empty list is
// a place the eye lands often, and every time it landed on "Ничего не найдено"
// set in subtext0 it landed on nothing at all. The cat is asleep because that
// is what the surface is doing.
Column {
    id: root

    property string text: ""
    property real catSize: 104
    property real catOpacity: 0.5

    spacing: 4

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.catSize
        height: root.catSize * 0.72

        Image {
            anchors.centerIn: parent
            width: root.catSize
            height: root.catSize
            source: Qt.resolvedUrl("assets/bongo/bongo-sleeping.png")
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectFit
            opacity: root.catOpacity
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: "z"
            color: Qt.alpha(Theme.subtext0, 0.8)
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(10, root.catSize * 0.12)

            SequentialAnimation on y {
                running: root.visible
                loops: Animation.Infinite
                NumberAnimation { from: 10; to: -6; duration: Theme.animDoze; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: Theme.animBusy }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.text !== ""
        text: root.text
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
    }
}
