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
    // Scoped to the output; the per-item suffix is added in the delegate,
    // since each tray icon owns a separate menu.
    readonly property string menuScope: Menus.idFor(root.barWindow, "tray")

    spacing: 4
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    // A Row with no visible children is zero wide but still a visible child of
    // the row above, and a positioner puts its spacing around one of those. So
    // an empty tray cost a gap that looked like a missing widget. The same
    // guard `BarMedia` uses, for the same reason.
    visible: width > 0

    // Tray icons used to blink in and out with no transition at all, and the
    // neighbours teleported into the gap — one of the places the shell simply
    // had no motion.
    add: MotionAdd {}
    move: MotionMove {}

    Repeater {
        // Passive means the application is asking not to be shown right now;
        // drawing it anyway leaves dead icons in the bar.
        //
        // Sorted, and it was not. The order was whichever order the applications
        // happened to claim their tray slots in, which is a race between programs
        // starting at login — caught by photographing the bar on a cold start and
        // again after a reload in the same session, bluetooth and the signal
        // meter swapping places between the two.
        //
        // These are aimed at with a mouse, and they are small enough that
        // position is most of how they are found. An icon that is third today and
        // second tomorrow defeats the only thing anybody remembers about a tray.
        // By `id`, which is the application's own name and does not move about
        // the way a title does.
        model: SystemTray.items.values
            .filter(i => i.status !== Status.Passive)
            .sort((a, b) => {
                const ai = (a.id || "").toLowerCase();
                const bi = (b.id || "").toLowerCase();
                if (ai !== bi) return ai < bi ? -1 : 1;
                return (a.title || "") < (b.title || "") ? -1 : 1;
            })

        delegate: Item {
            id: entry
            required property var modelData

            readonly property string menuId: root.menuScope + "/" + entry.modelData.id

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
                font.family: Theme.fontIconFamily
                font.pixelSize: Theme.fontIconSmall
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
                    Menus.toggle(entry.menuId);
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
                menuId: entry.menuId
                handle: entry.modelData.menu
                anchorItem: entry
                open: Menus.isOpen(entry.menuId)
            }

            Tooltip {
                anchorItem: entry
                active: trayMa.containsMouse && !Menus.isOpen(entry.menuId)
                text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                subtext: entry.modelData.tooltipDescription || ""
            }
        }
    }
}
