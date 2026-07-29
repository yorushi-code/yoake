import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// System tray.
//
// The previous version was effectively inert. Right-click called
// `item.menu.display(x, y)` — but `menu` is a DBusMenuHandle, which has no
// `display` at all; that method lives on the tray item and takes the parent
// window (`display(parentWindow, relativeX, relativeY)`). The call silently did
// nothing, so tray menus simply never opened. On top of that the only hit area
// was the 15px icon itself inside a 34px bar, middle-click and scroll were
// unhandled, and items that asked to be hidden were drawn anyway.
Row {
    id: root

    // Needed for the fallback path: quickshell's own menu renderer wants the
    // window the popup should belong to.
    property var barWindow: null

    spacing: 4
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Repeater {
        // Passive means the application is asking not to be shown right now;
        // drawing it anyway leaves dead icons in the bar.
        model: SystemTray.items.values.filter(i => i.status !== Status.Passive)

        delegate: Item {
            id: entry
            required property var modelData

            // Full bar height so the icon is actually clickable — the old 15px
            // square demanded pixel-accurate aim.
            width: 26
            height: Theme.barHeight
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                id: icon
                anchors.centerIn: parent
                implicitSize: 16
                source: entry.modelData.icon
                visible: status === Image.Ready
                scale: trayMa.pressed ? 0.85 : (trayMa.containsMouse ? 1.3 : 1.0)
                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                }
            }

            // An icon name the theme doesn't have (mihomo asks for
            // "network-vpn-symbolic", which Adwaita lacks) would otherwise
            // leave an invisible but still clickable gap in the tray — the
            // application is running and has a menu, with nothing to show it.
            Text {
                anchors.centerIn: parent
                visible: !icon.visible
                text: Glyphs.apps
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: trayMa.containsMouse ? Theme.accent : Theme.subtext1
                scale: icon.scale
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            MouseArea {
                id: trayMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.secondaryActivate();
                        return;
                    }
                    // onlyMenu items have no primary action at all — sending
                    // them activate() is what made left-clicking some icons
                    // (Telegram's among them) appear to do nothing.
                    const wantsMenu = mouse.button === Qt.RightButton || entry.modelData.onlyMenu;
                    if (!wantsMenu) {
                        entry.modelData.activate();
                        return;
                    }
                    if (!entry.modelData.hasMenu) {
                        entry.modelData.activate();
                        return;
                    }
                    if (Menus.isOpen(menu)) Menus.closeAll();
                    else Menus.open(menu);
                }

                // Volume-style scroll handling is part of the spec and some
                // apps (mixers, players) rely on it.
                onWheel: wheel => {
                    if (wheel.angleDelta.y !== 0) entry.modelData.scroll(wheel.angleDelta.y, false);
                    if (wheel.angleDelta.x !== 0) entry.modelData.scroll(wheel.angleDelta.x, true);
                }
            }

            TrayMenu {
                id: menu
                handle: entry.modelData.menu
                anchorItem: entry
                open: Menus.isOpen(menu)
            }

            Tooltip {
                anchorItem: entry
                active: trayMa.containsMouse && !Menus.isOpen(menu)
                text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                subtext: entry.modelData.tooltipDescription || ""
            }
        }
    }
}
