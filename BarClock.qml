import QtQuick
import Quickshell

// Time and date. Split into two hit areas deliberately — one island, but each
// half opens the panel its label suggests.
Row {
    id: root

    property var barWindow: null

    spacing: 10
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: true
    }

    readonly property var menuModel: [
        {
            text: "Панель управления",
            glyph: Glyphs.tune,
            action: () => Toggles.controlCenterOpen = true
        },
        {
            text: "Календарь",
            glyph: Glyphs.calendar,
            action: () => Toggles.calendarOpen = true
        },
        { separator: true },
        {
            text: "Скопировать дату",
            glyph: Glyphs.copy,
            action: () => Quickshell.clipboardText = Qt.formatDateTime(clock.date, "yyyy-MM-dd")
        },
        {
            text: "Скопировать время",
            glyph: Glyphs.copy,
            action: () => Quickshell.clipboardText = Qt.formatDateTime(clock.date, "hh:mm")
        },
        { separator: true },
        {
            text: "Дата и время в системе",
            glyph: Glyphs.cog,
            action: () => Quickshell.execDetached(["sh", "-c", "gnome-control-center datetime || kitty -e timedatectl"])
        }
    ]

    Item {
        id: timeItem
        width: timeLabel.width
        height: Theme.barHeight

        Text {
            id: timeLabel
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
        }

        MouseArea {
            id: clockArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (Menus.isOpen(menu)) Menus.closeAll();
                    else Menus.open(menu);
                    return;
                }
                Menus.closeAll();
                Toggles.controlCenterOpen = !Toggles.controlCenterOpen;
            }
        }

        // Shared by both halves so the menu appears under whichever was
        // right-clicked without duplicating the model.
        ActionMenu {
            id: menu
            anchorItem: timeItem
            model: Menus.isOpen(menu) ? root.menuModel : []
            open: Menus.isOpen(menu)
        }

        Tooltip {
            anchorItem: timeItem
            active: clockArea.containsMouse && !Menus.isOpen(menu)
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            subtext: "ЛКМ — панель управления · ПКМ — меню"
        }
    }

    Item {
        id: dateItem
        width: dateLabel.width
        height: Theme.barHeight

        Text {
            id: dateLabel
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd, d MMM")
            color: dateArea.containsMouse ? Theme.text : Theme.subtext0
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        MouseArea {
            id: dateArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (Menus.isOpen(menu)) Menus.closeAll();
                    else Menus.open(menu);
                    return;
                }
                Menus.closeAll();
                Toggles.calendarOpen = !Toggles.calendarOpen;
            }
        }

        Tooltip {
            anchorItem: dateItem
            active: dateArea.containsMouse && !Menus.isOpen(menu)
            text: "Календарь"
            subtext: "ПКМ — меню"
        }
    }
}
