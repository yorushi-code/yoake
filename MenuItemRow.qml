import QtQuick
import Quickshell

// One row of a menu. Shared by the shell's own action menus and by the
// DBus-backed tray menus so a tray popup is visually indistinguishable from a
// native one — the whole point of drawing tray menus ourselves rather than
// calling SystemTrayItem.display(), which renders an unstyled Qt widget menu.
Item {
    id: root

    property string text: ""
    property string glyph: ""
    // Freedesktop icon name or file path, used by tray entries that carry one.
    property string iconSource: ""
    property bool checked: false
    property bool checkable: false
    property bool hasSubmenu: false
    property bool separator: false
    property bool destructive: false

    signal triggered()
    signal hovered()

    implicitWidth: Math.max(180, label.implicitWidth + 76)
    implicitHeight: separator ? 9 : 30

    Rectangle {
        visible: root.separator
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        height: 1
        color: Qt.alpha(Theme.text, Theme.fillHover)
    }

    Rectangle {
        id: hoverFill
        visible: !root.separator
        anchors.fill: parent
        radius: Theme.radius - 3
        color: ma.containsMouse
            ? (root.destructive ? Qt.alpha(Theme.red, Theme.tintActive) : Qt.alpha(Theme.accent, Theme.tintActive))
            : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Ripple {
            anchors.fill: parent
            radius: parent.radius
            rippleColor: root.destructive ? Theme.red : Theme.accent
        }
    }

    Row {
        visible: !root.separator
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Check column is always reserved on checkable rows so labels in a
        // group of radio items line up whether or not they are selected.
        Item {
            width: (root.checkable || root.glyph || root.iconSource) ? 16 : 0
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                visible: root.checkable
                text: Glyphs.check
                font.family: "Symbols Nerd Font"
                font.pixelSize: Theme.fontIconMicro
                color: Theme.accent
                opacity: root.checked ? 1 : 0
                scale: root.checked ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.checkable && root.glyph !== ""
                text: root.glyph
                font.family: "Symbols Nerd Font"
                font.pixelSize: Theme.fontIconMicro
                color: root.destructive ? Theme.red : Theme.subtext1
            }

            Image {
                id: iconImage
                anchors.centerIn: parent
                // DBusMenu entries carry a themed icon *name*, which an Image
                // cannot load — pointing it straight at one renders Qt's
                // magenta broken-image placeholder in every row. Paths and
                // image:// URLs (embedded pixmaps) are passed through as-is.
                source: {
                    if (root.iconSource === "") return "";
                    if (root.iconSource.startsWith("/")) return root.iconSource;
                    // An icon:// URL for a name the theme lacks still "loads":
                    // the provider hands back a placeholder, so status is Ready
                    // and a magenta broken-image square lands in every row.
                    // The name has to be checked against the theme first.
                    const name = root.iconSource.startsWith("image://icon/")
                        ? root.iconSource.slice("image://icon/".length)
                        : root.iconSource;
                    if (root.iconSource.indexOf("://") >= 0 && !root.iconSource.startsWith("image://icon/")) {
                        return root.iconSource;
                    }
                    return Icons.forName(name, "");
                }
                visible: !root.checkable && root.glyph === "" && source != "" && status === Image.Ready
                sourceSize.width: 16
                sourceSize.height: 16
                width: 16
                height: 16
                asynchronous: true
            }
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - 60)
            text: root.text
            elide: Text.ElideRight
            color: !root.enabled ? Qt.alpha(Theme.text, Theme.inkFaint)
                : (root.destructive ? Theme.red : Theme.text)
            font.pixelSize: Theme.fontBody
        }
    }

    Text {
        visible: root.hasSubmenu
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: Glyphs.chevronRight
        font.family: "Symbols Nerd Font"
        font.pixelSize: Theme.fontIconMicro
        color: Theme.subtext0
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: !root.separator && root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
        onEntered: root.hovered()
    }
}
