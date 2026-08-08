import QtQuick
import Quickshell

// Applications, resolved through DesktopEntries so the real Exec line is used
// and anything not installed simply does not appear.
Flow {
    id: root

    // The settings-adjacent things worth a chip on a machine that has just been
    // installed, before there is any habit to read.
    readonly property var fallbackIds: [
        "org.pulseaudio.pavucontrol",
        "org.gnome.Nautilus",
        "kitty",
        "nm-connection-editor"
    ]

    property int limit: 8

    // What actually gets opened, most-opened first, topped up from the defaults.
    //
    // The launcher already counts every launch and the card was three fixed
    // chips adrift in a card four times their height -- a hole, and a hole that
    // knew nothing about the person using it. Habits are the one thing here
    // that can fill the space and be worth reading at the same time.
    readonly property var ids: {
        const usage = Prefs.get("launcher.usage", {}) || {};
        const ranked = Object.keys(usage).filter(id => usage[id] > 0);
        ranked.sort((a, b) => usage[b] - usage[a]);

        const out = ranked.slice(0, root.limit);
        for (const id of root.fallbackIds) {
            if (out.length >= root.limit) break;
            if (out.indexOf(id) < 0) out.push(id);
        }
        return out;
    }

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
            radius: Theme.pill(height)
            color: appArea.containsMouse ? Qt.alpha(Theme.text, Theme.strokeFirm) : Qt.alpha(Theme.text, Theme.fillSubtle)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            scale: appArea.pressed ? 0.94 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacing

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16

                    Image {
                        id: appIcon
                        anchors.fill: parent
                        source: Icons.forName(app.modelData.icon, "")
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
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIconMicro
                        color: Theme.subtext1
                    }
                }

                Text {
                    id: appLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: app.modelData.name
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                }
            }

            MouseArea {
                id: appArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(app.modelData.command);
                    Toggles.dashboardOpen = false;
                }
            }
        }
    }
}
