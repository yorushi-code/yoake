import QtQuick
import Quickshell

// The time, set large enough to be the first thing read on the page.
//
// The date moved out to BarDateline, in the centre of row one: in a masthead
// the time is the anchor at the left edge and the dateline is the centred
// caption, not a smaller word beside it.
Item {
    id: root

    property var barWindow: null
    readonly property string menuId: Menus.idFor(root.barWindow, "clock")

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

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

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.text
        font.family: Theme.fontDisplayFamily
        font.pixelSize: Theme.fontDisplay
        font.weight: Font.Medium
        font.letterSpacing: Theme.trackDisplay
        // Proportional digits make the time breathe in and out as the minute
        // changes, and at this size the whole left edge of the masthead moves
        // with it.
        font.features: ({ "tnum": 1 })
    }

    MouseArea {
        id: clockArea
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Menus.toggle(root.menuId);
                return;
            }
            Menus.closeAll();
            Toggles.controlCenterOpen = !Toggles.controlCenterOpen;
        }
    }

    ActionMenu {
        menuId: root.menuId
        anchorItem: root
        model: Menus.isOpen(root.menuId) ? root.menuModel : []
        open: Menus.isOpen(root.menuId)
    }

    Tooltip {
        anchorItem: root
        active: clockArea.containsMouse && !Menus.isOpen(root.menuId)
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
        subtext: "ЛКМ — панель управления · ПКМ — меню"
    }
}
