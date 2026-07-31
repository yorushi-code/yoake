import QtQuick
import Quickshell.Widgets

// One card on the dashboard.
//
// Every block of content sits on one of these, so the dashboard is a grid of a
// single object rather than a collection of panels that happen to look alike.
// The whole point of a card here is that it is quiet: a low fill, no border, no
// shadow. Depth is already carried by the sheet the cards sit on — repeating it
// per card is what turns a dashboard into a pile of boxes.
ClippingRectangle {
    id: root

    // An optional eyebrow across the top of the card.
    property string title: ""
    // Cards that are their own control surface light up on hover; static ones
    // (a calendar, a readout) do not, because nothing happens if you click.
    property bool interactive: false

    signal activated()

    radius: 18
    color: root.interactive && area.containsMouse
        ? Qt.alpha(Theme.text, 0.10)
        : Qt.alpha(Theme.text, 0.055)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    // Content starts below the eyebrow when there is one, so children can
    // simply fill this and never think about it.
    default property alias content: body.data

    Text {
        id: eyebrow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 14
        anchors.leftMargin: 16
        visible: root.title !== ""
        text: root.title.toUpperCase()
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.weight: Font.Medium
        font.letterSpacing: Theme.trackLabel
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: root.title !== "" ? 36 : 0
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.activated()
        z: -1
    }
}
