import QtQuick
import Quickshell
import Quickshell.Widgets

// One application in the launcher list.
//
// It used to draw its own selection — a tinted fill and an accent rail that
// appeared here and disappeared on whichever row you came from. That is a
// cross-fade between two rows, and a cross-fade cannot say you moved *down*;
// the list now hands that job to one `Traveller` behind the delegates, and what
// is left here is only what genuinely belongs to a row: how its own content
// reacts to being the one under the marker.
//
// The icon comes from the icon theme through Quickshell's own lookup, which is
// the only way to get the same glyph the rest of the desktop shows for an app —
// a name-to-file guess gets it right until it meets a themed or scalable icon.
Item {
    id: root

    required property var entry
    property bool selected: false

    signal activated()
    signal hovered()

    height: 52

    // Resolved to a file here rather than handed to IconImage as a name with a
    // fallback. An icon theme can hold a name at 16, 22 and 24 and nothing
    // larger; asked for it at 30 by name the engine gives up -- and so does the
    // generic fallback, which AdwaitaLegacy also stops at 24 -- and IconImage
    // then draws Qt's magenta checkerboard while still reporting itself Ready,
    // so no status check can catch it. Given the file, it simply scales the
    // 24px art up.
    readonly property string iconSource: Icons.forName(root.entry.icon)

    MaterialSymbol {
        anchors.horizontalCenter: icon.horizontalCenter
        anchors.verticalCenter: icon.verticalCenter
        visible: root.iconSource === ""
        icon: Glyphs.apps
        size: Theme.fontIcon
        fill: root.selected ? 1 : 0
        color: root.selected ? Theme.text : Theme.subtext0
    }

    IconImage {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 30
        source: root.iconSource
        // Enough to read as picked up off the surface, and no more: this fires
        // on every arrow key, so anything with real travel in it turns walking
        // the list into a sequence of small explosions.
        scale: root.selected ? 1.10 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeSpringBig
            }
        }
    }

    Column {
        id: labels
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        // Leans into the marker as it lands. Two pixels, which is below the
        // threshold at which anyone would name it and above the one at which
        // the row stops feeling attached to the selection.
        x: root.selected ? 2 : 0
        Behavior on x {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeSpring
            }
        }

        Text {
            width: parent.width
            text: root.entry.name || ""
            color: root.selected ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: root.selected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.entry.genericName || root.entry.comment || ""
            color: root.selected ? Theme.subtext1 : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }
}
