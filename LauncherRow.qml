import QtQuick
import Quickshell
import Quickshell.Widgets

// One application in the launcher list.
//
// The icon comes from the icon theme through Quickshell's own lookup, which is
// the only way to get the same glyph the rest of the desktop shows for an app —
// a name-to-file guess gets it right until it meets a themed or scalable icon.
Rectangle {
    id: root

    required property var entry
    property bool selected: false

    signal activated()
    signal hovered()

    height: 52
    radius: Theme.radius
    color: root.selected ? Qt.alpha(Theme.accent, 0.16)
        : (ma.containsMouse ? Qt.alpha(Theme.text, 0.06) : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    // A rail on the selected row, so the selection reads at a glance in a list
    // where every row is otherwise the same shape.
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: root.selected ? 24 : 0
        radius: 1.5
        color: Theme.accent
        Behavior on height {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeSpring
            }
        }
    }

    // Resolved to a file here rather than handed to IconImage as a name with a
    // fallback. An icon theme can hold a name at 16, 22 and 24 and nothing
    // larger; asked for it at 30 by name the engine gives up -- and so does the
    // generic fallback, which AdwaitaLegacy also stops at 24 -- and IconImage
    // then draws Qt's magenta checkerboard while still reporting itself Ready,
    // so no status check can catch it. Given the file, it simply scales the
    // 24px art up.
    readonly property string iconSource: {
        const name = root.entry.icon || "";
        const found = name !== "" ? Quickshell.iconPath(name, true) : "";
        return found !== "" ? found : Quickshell.iconPath("application-x-executable", true);
    }

    Text {
        anchors.horizontalCenter: icon.horizontalCenter
        anchors.verticalCenter: icon.verticalCenter
        visible: root.iconSource === ""
        text: Glyphs.apps
        font.family: Theme.fontIconFamily
        font.pixelSize: 20
        color: Theme.subtext0
    }

    IconImage {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 30
        source: root.iconSource
        scale: root.selected ? 1.06 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animNormal
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeSpring
            }
        }
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.entry.name || ""
            color: root.selected ? Theme.text : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: root.selected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.entry.genericName || root.entry.comment || ""
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            elide: Text.ElideRight
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
