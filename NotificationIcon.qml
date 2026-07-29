import QtQuick
import Quickshell
import Quickshell.Widgets

// Icon for a notification, preferring what the application actually sent.
//
// The server advertises image support, so a notification carrying inline image
// data has to be drawn — it used to be accepted over D-Bus and then never
// rendered, which is why every notification looked identical regardless of
// what sent it. Falls back through the app icon to a generic bell so the slot
// is never an empty hole.
ClippingRectangle {
    id: root

    property var notification: null
    property int size: 32
    property color accent: Theme.accent

    width: size
    height: size
    radius: Math.round(size * 0.28)
    color: Qt.alpha(root.accent, 0.14)

    // `image` is the raw image hint; `appIcon` is a themed icon name, which has
    // to go through iconPath() before an Image can load it.
    // Guarded against the notification being destroyed while its toast is still
    // fading out: reading a property off a dead QObject throws, which would
    // take the whole binding down mid-animation.
    readonly property string resolved: {
        try {
            if (!root.notification) return "";
            if (root.notification.image) return root.notification.image;
            const icon = root.notification.appIcon;
            if (icon && Quickshell.hasThemeIcon(icon)) return Quickshell.iconPath(icon);
            return "";
        } catch (e) {
            return "";
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.resolved
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        asynchronous: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        // Error matters as much as Null: a themed icon name that fails to
        // resolve would otherwise leave a blank tile.
        visible: img.status !== Image.Ready
        text: Glyphs.bell
        font.family: "Symbols Nerd Font"
        font.pixelSize: Math.round(root.size * 0.5)
        color: root.accent
    }
}
