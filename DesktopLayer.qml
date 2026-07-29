import QtQuick
import Quickshell
import Quickshell.Wayland

// Click-catcher for bare desktop space, one per output.
//
// Clicking the wallpaper used to do nothing at all: WallpaperView is a
// full-output Background surface with no mask, so it claimed the entire input
// region and silently ate every desktop click, while the bar's own catcher
// only covered its 34px strip. A menu therefore stayed up until the user found
// the widget that opened it again.
//
// This sits on the Bottom layer — above the wallpaper, below normal windows —
// so a click on a window is still a click on that window. It must be created
// before any other Bottom-layer surface in shell.qml: same-layer surfaces
// stack in creation order, and this one has to end up underneath the desktop
// widgets so their own hit areas keep working.
PanelWindow {
    id: catcher

    required property var modelData
    readonly property ShellScreen catcherScreen: modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: false
    WlrLayershell.layer: WlrLayer.Bottom
    // Span the full output rather than being shrunk by the bar's exclusive
    // zone; the strip under the bar islands is desktop too.
    exclusiveZone: -1

    readonly property string menuId: catcher.catcherScreen.name + "/desktop"

    // Dropped entirely during the overview, where niri owns the pointer and a
    // layer surface claiming input would swallow workspace picking.
    mask: Region { item: Niri.overviewOpen ? null : full }

    Item {
        id: full
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    // Park the anchor where the click landed so the menu opens
                    // under the cursor rather than in the corner.
                    anchorDot.x = mouse.x;
                    anchorDot.y = mouse.y;
                    Toggles.closeAll();
                    Menus.open(catcher.menuId);
                } else {
                    Menus.closeAll();
                    Toggles.closeAll();
                }
            }
        }
    }

    // Zero-size handle the popup hangs from; PopupWindow anchors to an item,
    // and there is no real widget at an arbitrary desktop coordinate.
    Item {
        id: anchorDot
        width: 1
        height: 1
    }

    ActionMenu {
        menuId: catcher.menuId
        anchorItem: anchorDot
        model: Menus.isOpen(catcher.menuId) ? ShellActions.desktopMenu : []
        open: Menus.isOpen(catcher.menuId)
    }
}
