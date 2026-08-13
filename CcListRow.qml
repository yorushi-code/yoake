import QtQuick

// One entry in a control-centre page list: a network, a paired device.
//
// Connected state is a mark and a fill, not a "✓" glued onto the name — that
// version put the tick inside the elided text, so a long SSID hid the only
// indication the row was the connected one.
Rectangle {
    id: root

    property string label: ""
    property string detail: ""
    property bool connected: false
    property string glyph: ""

    signal activated()

    height: 40
    radius: Theme.radius
    color: root.connected
        ? Qt.alpha(Theme.accent, 0.18)
        : (ma.containsMouse ? Qt.alpha(Theme.text, Theme.fillMuted) : Qt.alpha(Theme.text, Theme.fillSubtle))
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        id: mark
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 15
        text: root.connected ? Glyphs.check : root.glyph
        font.family: Theme.fontIconFamily
        font.pixelSize: Theme.fontIconMicro
        color: root.connected ? Theme.accent : Theme.subtext0
    }

    Column {
        anchors.left: mark.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapPair

        Text {
            width: parent.width
            text: root.label
            color: Theme.text
            font.pixelSize: Theme.fontBody
            font.bold: root.connected
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            color: Theme.subtext0
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight
        }
    }

    // See DeviceRow: a row that answers nothing when pressed reads as a row
    // that did not hear the press.
    scale: ma.pressed ? Theme.pressScale : 1
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpringBig
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
