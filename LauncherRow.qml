import QtQuick
import Quickshell
import Quickshell.Widgets

// One result in the launcher, whatever kind of result it is.
//
// It used to take a `.desktop` entry and nothing else, which is what made the
// launcher a list of applications and only that. A row now takes a name, a
// subtitle, an icon and a *kind*, so an open window, a shell action and a sum
// can appear in the same list without any of them pretending to be an app.
//
// The kind is printed on the right, and only when the list actually holds more
// than one -- the caller decides that and passes an empty string otherwise.
// Four kinds in one list with nothing saying which is which answers the wrong
// question half the time; one kind labelled forty times is forty labels that
// answer nothing.
//
// It draws no selection of its own: the list hands that to one `Traveller`
// behind the delegates, because a fill that appears here while another
// disappears elsewhere is a cross-fade, and a cross-fade cannot say you moved
// down.
Item {
    id: root

    property string name: ""
    property string subtitle: ""
    // An icon theme name, or empty for the glyph fallback.
    property string iconName: ""
    property string glyph: Glyphs.apps
    property string kind: ""
    property bool selected: false

    signal activated()
    signal hovered()

    height: 52

    // Resolved to a file rather than handed to IconImage as a name. An icon
    // theme can hold a name at 16, 22 and 24 and nothing larger; asked for it
    // at 30 by name the engine gives up -- and so does the generic fallback --
    // and IconImage then draws Qt's magenta checkerboard while still reporting
    // itself Ready, so no status check can catch it.
    readonly property string iconSource: root.iconName !== ""
        ? Icons.forName(root.iconName) : ""

    MaterialSymbol {
        anchors.horizontalCenter: icon.horizontalCenter
        anchors.verticalCenter: icon.verticalCenter
        visible: root.iconSource === ""
        icon: root.glyph
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
        anchors.right: kindLabel.left
        // No badge, no gap for one: an empty label still sits at the right
        // inset, and reserving its margin anyway would pad the row's right side
        // wider than its left in every list that has no kinds to tell apart.
        anchors.rightMargin: root.kind === "" ? 0 : Theme.gapWide
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapPair

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
            text: root.name
            color: root.selected ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: root.selected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.selected ? Theme.subtext1 : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    Text {
        id: kindLabel
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: root.kind
        color: Theme.subtext0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontMicro
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
