import QtQuick

// Notification bell. Carries the unread count, which the shell tracked but
// never showed, and is where do-not-disturb lives.
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "notifications")

    // Wider than the glyph so the count badge has somewhere to sit without
    // colliding with the tray icon beside it.
    width: 24
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    BarIcon {
        id: bell
        anchors.centerIn: parent
        glyph: Notifs.dnd ? Glyphs.bellOff : Glyphs.bell
        glyphSize: 14
        color: Notifs.dnd ? Theme.subtext0
            : (notifArea.containsMouse ? Theme.accent : Theme.text)
        badge: (Notifs.count > 0 && !Notifs.dnd) ? (Notifs.count > 9 ? "9+" : String(Notifs.count)) : ""
        hovered: notifArea.containsMouse
        pressed: notifArea.pressed

        // A quick swing when a new notification is registered, so the bar
        // acknowledges it even if the toast was missed.
        SequentialAnimation {
            id: bellRing
            RotationAnimation { target: bell; from: 0; to: 18; duration: 90; easing.type: Easing.OutQuad }
            RotationAnimation { target: bell; to: -14; duration: 130; easing.type: Easing.InOutQuad }
            RotationAnimation { target: bell; to: 8; duration: 110; easing.type: Easing.InOutQuad }
            RotationAnimation { target: bell; to: 0; duration: 90; easing.type: Easing.InQuad }
        }
        Connections {
            target: Notifs
            function onArrived() { bellRing.restart(); }
        }
    }

    MouseArea {
        id: notifArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Menus.toggle(root.menuId);
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                Notifs.dnd = !Notifs.dnd;
                return;
            }
            Menus.closeAll();
            Toggles.notifCenterOpen = !Toggles.notifCenterOpen;
        }
    }

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        model: Menus.isOpen(root.menuId) ? [
            {
                text: Notifs.dnd ? "Выключить «не беспокоить»" : "Не беспокоить",
                glyph: Notifs.dnd ? Glyphs.bell : Glyphs.bellOff,
                checkable: true,
                checked: Notifs.dnd,
                action: () => Notifs.dnd = !Notifs.dnd
            },
            { separator: true },
            {
                text: "История уведомлений",
                glyph: Glyphs.bellBadge,
                action: () => Toggles.notifCenterOpen = true
            },
            {
                text: "Очистить всё",
                glyph: Glyphs.close,
                enabled: Notifs.count > 0,
                destructive: true,
                action: () => Notifs.clearAll()
            }
        ] : []
    }

    Tooltip {
        anchorItem: root
        active: notifArea.containsMouse && !Menus.isOpen(root.menuId)
        text: Notifs.dnd ? "Не беспокоить"
            : (Notifs.count > 0 ? "Уведомлений: " + Notifs.count : "Нет уведомлений")
        subtext: "СКМ — не беспокоить · ПКМ — меню"
    }
}
