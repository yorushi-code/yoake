import QtQuick
import Quickshell

// Applications, resolved through DesktopEntries so the real Exec line is used
// and anything not installed simply does not appear.
Flow {
    id: root

    readonly property var ids: [
        "org.pulseaudio.pavucontrol",
        "org.gnome.Nautilus",
        "kitty",
        "nm-connection-editor"
    ]

    readonly property var entries: {
        // byId() registers no dependency, so the model is touched here to make
        // this binding re-run once the async scan has finished.
        const _ = DesktopEntries.applications.values.length;
        const out = [];
        for (const id of root.ids) {
            const entry = DesktopEntries.byId(id);
            if (entry) out.push(entry);
        }
        return out;
    }

    spacing: 8

    Repeater {
        model: root.entries

        delegate: Rectangle {
            id: app
            required property var modelData

            width: appLabel.implicitWidth + 36
            height: 34
            radius: 17
            color: appArea.containsMouse ? Qt.alpha(Theme.text, 0.16) : Qt.alpha(Theme.text, 0.06)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            scale: appArea.pressed ? 0.94 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
            }

            Row {
                anchors.centerIn: parent
                spacing: 7

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        source: app.modelData.icon ? Quickshell.iconPath(app.modelData.icon, true) : ""
                        sourceSize.width: 32
                        sourceSize.height: 32
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // Themes do not carry every icon an app asks for, which
                    // otherwise leaves a blank gap where the icon should be.
                    Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: Glyphs.apps
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 13
                        color: Theme.subtext1
                    }
                }

                Text {
                    id: appLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.modelData.name
                    color: Theme.text
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: appArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(app.modelData.command);
                    Toggles.controlCenterOpen = false;
                }
            }
        }
    }
}
