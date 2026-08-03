import QtQuick
import Quickshell

// The application-provided tray menu, drawn by us.
//
// The alternative is SystemTrayItem.display(), which pops a plain Qt widget
// menu that looks nothing like the rest of the shell. QsMenuOpener exposes the
// same DBusMenu tree as a model, so entries go through MenuItemRow and a tray
// menu is indistinguishable from the shell's own.
//
// `opener.menu` is bound to the open state rather than set once: creating the
// opener is what tells the application its menu is being shown, which is when
// DBusMenu clients (Telegram among them) actually populate or refresh entries.
// Holding it open permanently would keep every tray app rebuilding menus
// nobody is looking at.
//
// Submenus expand inline instead of opening child popups. QML forbids a
// component from nesting itself, and a popup-inside-a-popup has no reliable
// stacking order on layer-shell — inline expansion sidesteps both and reads
// better in a menu this compact.
MenuSurface {
    id: root

    // A QsMenuHandle — SystemTrayItem.menu.
    property var handle: null
    property Item anchorItem: null
    // The owner's key in the Menus registry; see ActionMenu.
    property string menuId: ""

    anchor {
        item: root.anchorItem
        rect.y: root.anchorItem ? root.anchorItem.height : 0
        gravity: Edges.Bottom
        // Slides along the bar instead of hanging off-screen when the tray icon
        // sits in the far corner, which is exactly where it always is.
        adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY
    }

    // See ActionMenu: width is measured, not taken from the layout, because the
    // rows are sized to the column and the column to this popup.
    // Capped and scrollable in height: real tray menus run long (nm-applet
    // ships 16 entries before any submenu is opened) and would otherwise grow
    // past the bottom of the screen.
    contentHeight: Math.min(column.implicitHeight, Screen.height * 0.7)

    TextMetrics {
        id: metrics
        font.pixelSize: Theme.fontBody
    }

    function measure(entries) {
        let w = 200;
        for (const e of entries) {
            if (e.isSeparator) continue;
            metrics.text = (e.text || "").replace(/_([^_])/g, "$1");
            // Extra room for the chevron on rows that expand.
            w = Math.max(w, metrics.advanceWidth + (e.hasChildren ? 92 : 76));
        }
        return Math.min(440, Math.ceil(w));
    }

    onEntriesChanged: root.contentWidth = root.measure(root.entries)

    onDismissed: Menus.close(root.menuId)
    onOpenChanged: if (!root.open) root.expanded = null

    // Which entry currently has its children shown. One at a time, so the menu
    // cannot grow taller than the screen through repeated expansion.
    property var expanded: null

    QsMenuOpener {
        id: opener
        menu: root.open ? root.handle : null
    }

    // Applications emit separators liberally — leading, trailing and in pairs
    // (blueman sends two in a row, nm-applet ends on one). Drawing them
    // verbatim leaves gaps that read as rendering faults, so runs are collapsed
    // and the edges trimmed.
    readonly property var entries: {
        const src = opener.children ? opener.children.values : [];
        const out = [];
        for (const e of src) {
            if (e.isSeparator) {
                if (out.length === 0) continue;
                if (out[out.length - 1].isSeparator) continue;
            }
            out.push(e);
        }
        while (out.length > 0 && out[out.length - 1].isSeparator) out.pop();
        return out;
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: parent.width

            Repeater {
                model: root.entries

                delegate: Column {
                    id: entryGroup
                    required property var modelData

                    width: column.width

                    readonly property bool isExpanded: root.expanded === modelData

                    MenuItemRow {
                        width: entryGroup.width
                        // DBusMenu labels carry mnemonic underscores meant for a
                        // widget toolkit's Alt-navigation, which we don't do.
                        text: (modelData.text || "").replace(/_([^_])/g, "$1")
                        iconSource: modelData.icon || ""
                        // buttonType 0 is a plain item; checkbox and radio both
                        // render as a check, since a row has no room to tell
                        // them apart usefully.
                        checkable: modelData.buttonType !== undefined && modelData.buttonType !== 0
                        checked: modelData.checkState === Qt.Checked
                        separator: modelData.isSeparator === true
                        hasSubmenu: modelData.hasChildren === true
                        enabled: modelData.enabled !== false

                        onTriggered: {
                            if (modelData.hasChildren) {
                                root.expanded = entryGroup.isExpanded ? null : modelData;
                                return;
                            }
                            modelData.triggered();
                            Menus.close(root.menuId);
                        }
                    }

                    // Children are only opened while actually shown, for the
                    // same reason the top-level opener is gated on `open`.
                    QsMenuOpener {
                        id: childOpener
                        menu: entryGroup.isExpanded ? modelData : null
                    }

                    Column {
                        width: entryGroup.width
                        // Height animates from zero so expansion reads as the
                        // menu growing rather than the rows below teleporting.
                        height: entryGroup.isExpanded ? implicitHeight : 0
                        clip: true
                        opacity: entryGroup.isExpanded ? 1 : 0
                        Behavior on height {
                            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

                        Repeater {
                            model: childOpener.children
                            delegate: MenuItemRow {
                                required property var modelData

                                width: entryGroup.width - 14
                                x: 14
                                text: (modelData.text || "").replace(/_([^_])/g, "$1")
                                iconSource: modelData.icon || ""
                                checkable: modelData.buttonType !== undefined && modelData.buttonType !== 0
                                checked: modelData.checkState === Qt.Checked
                                separator: modelData.isSeparator === true
                                enabled: modelData.enabled !== false

                                onTriggered: {
                                    modelData.triggered();
                                    Menus.close(root.menuId);
                                }
                            }
                        }
                    }
                }
            }

            // A tray icon that advertises a menu but delivers nothing would
            // otherwise show an empty sliver of glass with no explanation.
            MenuItemRow {
                width: column.width
                visible: root.entries.length === 0
                text: "Меню пусто"
                enabled: false
            }
        }
    }
}
