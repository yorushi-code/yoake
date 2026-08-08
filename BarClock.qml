import QtQuick
import Quickshell

// Time and date. Split into two hit areas deliberately — one island, but each
// half opens the panel its label suggests.
Row {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "clock")

    spacing: Theme.gapWide
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
            action: () => Toggles.dash("control")
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

        // Rolling digits, not a label that updates.
        //
        // The lock screen and the desktop clock have rolled since RollDigit was
        // written; the bar -- the clock anyone actually reads, sixty times an
        // hour, all day -- was still a Text being reassigned. It is the highest
        // frequency piece of motion this shell can own, it costs one
        // translation on a column of ten glyphs laid out once, and it is the
        // difference between a shell that displays the time and one that keeps
        // it.
        //
        // Tabular figures are still what makes it safe: the island's optical
        // centre is composed against this widget's width, so a clock that
        // changed width at 09:59 would shove the whole bar.
        RollClock {
            id: timeLabel
            anchors.centerIn: parent
            hours: clock.date.getHours()
            minutes: clock.date.getMinutes()
            pixelSize: Theme.fontLead
            family: Theme.fontFamily
            weight: Font.DemiBold
            ink: Theme.text
            groupGap: 2
            separatorRest: Theme.inkStrong
        }

        MouseArea {
            id: clockArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    Menus.toggle(root.menuId);
                    return;
                }
                Menus.closeAll();
                Toggles.dash("control");
            }
        }

        // Shared by both halves so the menu appears under whichever was
        // right-clicked without duplicating the model.
        ActionMenu {
            id: menu
            menuId: root.menuId
            anchorItem: timeItem
            model: Menus.isOpen(root.menuId) ? root.menuModel : []
            open: Menus.isOpen(root.menuId)
        }

        Tooltip {
            anchorItem: timeItem
            active: clockArea.containsMouse && !Menus.isOpen(root.menuId)
            text: Lang.dateCapitalised(clock.date, "dddd, d MMMM yyyy")
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
            text: Lang.dateCapitalised(clock.date, "ddd, d MMM")
            color: dateArea.containsMouse ? Theme.text : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.weight: Font.Medium
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
                    Menus.toggle(root.menuId);
                    return;
                }
                Menus.closeAll();
                Toggles.calendarOpen = !Toggles.calendarOpen;
            }
        }

        Tooltip {
            anchorItem: dateItem
            active: dateArea.containsMouse && !Menus.isOpen(root.menuId)
            text: "Календарь"
            subtext: "ПКМ — меню"
        }
    }
}
