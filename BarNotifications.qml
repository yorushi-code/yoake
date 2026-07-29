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
    width: 22
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Text {
        id: bellText
        anchors.centerIn: parent
        text: Notifs.dnd ? Glyphs.bellOff : Glyphs.bell
        font.family: "Symbols Nerd Font"
        font.pixelSize: 14
        color: Notifs.dnd ? Theme.subtext0
            : (notifArea.containsMouse ? Theme.accent : Theme.text)
        scale: notifArea.pressed ? 0.85 : (notifArea.containsMouse ? 1.25 : 1.0)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }

        // A quick swing when a new notification is registered, so the bar
        // acknowledges it even if the toast was missed.
        SequentialAnimation {
            id: bellRing
            RotationAnimation { target: bellText; from: 0; to: 18; duration: 90; easing.type: Easing.OutQuad }
            RotationAnimation { target: bellText; to: -14; duration: 130; easing.type: Easing.InOutQuad }
            RotationAnimation { target: bellText; to: 8; duration: 110; easing.type: Easing.InOutQuad }
            RotationAnimation { target: bellText; to: 0; duration: 90; easing.type: Easing.InQuad }
        }
        Connections {
            target: Notifs
            function onArrived() { bellRing.restart(); }
        }
    }

    // Count badge. Deliberately a small chip rather than a full pill: the bar
    // is 34px tall and anything larger unbalances the island. The ring in the
    // island's own colour separates it from the bell underneath, which it
    // necessarily overlaps at this size.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.rightMargin: -5
        width: Math.max(13, countText.implicitWidth + 7)
        height: 13
        radius: 6.5
        color: Theme.red
        border.color: Theme.crust
        border.width: 1.5
        visible: Notifs.count > 0 && !Notifs.dnd
        scale: visible ? 1 : 0
        Behavior on scale {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
        }

        Text {
            id: countText
            anchors.centerIn: parent
            text: Notifs.count > 9 ? "9+" : Notifs.count
            color: Theme.crust
            font.pixelSize: 8
            font.bold: true
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
