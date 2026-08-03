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
            RotationAnimation { target: bell; from: 0; to: 18; duration: Theme.animFlick; easing.type: Easing.OutQuad }
            RotationAnimation { target: bell; to: -14; duration: 130; easing.type: Easing.InOutQuad }
            RotationAnimation { target: bell; to: 8; duration: 110; easing.type: Easing.InOutQuad }
            RotationAnimation { target: bell; to: 0; duration: Theme.animFlick; easing.type: Easing.InQuad }
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

    // A card rather than a tooltip, like the audio, network, battery and VPN
    // chips beside it. A count is not what anyone hovers a bell to learn --
    // what they want is which application wants them, and whether it can wait.
    Popover {
        anchorItem: root
        hovered: notifArea.containsMouse && !Menus.isOpen(root.menuId)
        minWidth: 264

        Column {
            spacing: Theme.gapWide

            Row {
                spacing: Theme.gapWide

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.dnd ? Glyphs.bellOff : Glyphs.bell
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIcon
                    color: Notifs.dnd ? Theme.subtext0
                        : (Notifs.count > 0 ? Theme.accent : Theme.subtext1)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.dnd ? "Не беспокоить"
                        : (Notifs.count > 0 ? "Уведомлений: " + Notifs.count : "Тихо")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Medium
                }
            }

            // The last few, newest first. Three is what fits without the card
            // becoming a second notification centre -- the panel is one click
            // away and is the place for the whole list.
            Column {
                spacing: Theme.spacing
                visible: Notifs.tracked.length > 0

                Repeater {
                    model: Math.min(3, Notifs.newestFirst.length)

                    delegate: Row {
                        id: item
                        required property int index
                        readonly property var entry: Notifs.newestFirst[item.index]
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 26
                            radius: 1.5
                            color: item.index === 0
                                ? Qt.alpha(Theme.accent, 0.9)
                                : Qt.alpha(Theme.text, Theme.strokeFirm)
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: 226
                                text: (item.entry && item.entry.appName) || "Уведомление"
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                elide: Text.ElideRight
                            }

                            Text {
                                width: 226
                                text: (item.entry && (item.entry.summary || item.entry.body)) || ""
                                color: Theme.subtext1
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 238
                height: 1
                color: Qt.alpha(Theme.text, Theme.fillHover)
            }

            // Sibling of the row, not a child of it: a MouseArea inside a Row
            // is laid out as another column of it.
            Item {
                width: 238
                height: 22

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: Notifs.dnd ? Glyphs.bell : Glyphs.bellOff
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIconMicro
                        color: Theme.subtext1
                    }

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: Notifs.dnd ? "Включить уведомления" : "Не беспокоить"
                        color: dndHit.containsMouse ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }
                }

                MouseArea {
                    id: dndHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.dnd = !Notifs.dnd
                }
            }

            Text {
                text: "ЛКМ — все уведомления · ПКМ — меню"
                color: Qt.alpha(Theme.subtext0, 0.75)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
            }
        }
    }
}
