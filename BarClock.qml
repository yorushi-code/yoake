import QtQuick
import Quickshell

// Time and date, stacked.
//
// One line became two because the strip is 36 tall and a date set beside the
// time competes with it: at a glance the eye has to pick the clock out of a
// phrase. Under it, in caps at the smallest rung, the date is a caption and the
// time is the subject, which is the relationship those two things actually
// have.
//
// Split into two hit areas deliberately — one widget, but each line opens the
// panel its content suggests.
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "clock")

    // Where the bar's midpoint should land, in this widget's coordinates. The
    // strip composes itself around this rather than centring the zone: the
    // clock is read by position before it is read at all, and it was the one
    // thing on the old bar that moved every time the player appeared.
    readonly property real anchorX: timeRow.x + timeRow.width / 2

    implicitWidth: Math.max(timeRow.width, dateLabel.implicitWidth)
    implicitHeight: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    SystemClock {
        id: clock
        // Seconds, because the reference has them and because a clock without
        // them is a thing you read rather than a thing that is running.
        precision: SystemClock.Seconds
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
            action: () => Quickshell.clipboardText = Qt.formatDateTime(clock.date, "hh:mm:ss")
        },
        { separator: true },
        {
            text: "Дата и время в системе",
            glyph: Glyphs.cog,
            action: () => Quickshell.execDetached(["sh", "-c", "gnome-control-center datetime || kitty -e timedatectl"])
        }
    ]

    Column {
        anchors.centerIn: parent
        spacing: 0

        Row {
            id: timeRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.gapPair

            RollClock {
                id: hhmm
                anchors.verticalCenter: parent.verticalCenter
                hours: clock.date.getHours()
                minutes: clock.date.getMinutes()
                pixelSize: Theme.fontLead
                family: Theme.fontFamily
                weight: Font.DemiBold
                ink: Theme.text
                groupGap: 2
                separatorRest: Theme.inkStrong
            }

            // Seconds are set, not rolled.
            //
            // A rolling second is an animation starting once a second, forever,
            // on the one surface that is always on screen -- about a fifth of
            // the time spent animating for a digit nobody reads deliberately.
            // The minute rolls, which is the moment worth having; the seconds
            // simply are.
            Text {
                anchors.baseline: hhmm.baseline
                text: Qt.formatDateTime(clock.date, ":ss")
                color: Qt.alpha(Theme.text, Theme.inkFaint)
                font.family: Theme.fontMonoFamily
                font.pixelSize: Theme.fontMicro
                font.features: ({ "tnum": 1 })
            }
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: Lang.dateCapitalised(clock.date, "dddd, d MMMM").toUpperCase()
            color: dateArea.containsMouse ? Theme.subtext1 : Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMicro
            // Caps have no ascenders or descenders to space them; at label
            // tracking they clot into a bar.
            font.letterSpacing: Theme.trackCaption
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    MouseArea {
        id: clockArea
        anchors.fill: parent
        anchors.bottomMargin: root.height / 2
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

    MouseArea {
        id: dateArea
        anchors.fill: parent
        anchors.topMargin: root.height / 2
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

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        model: Menus.isOpen(root.menuId) ? root.menuModel : []
        open: Menus.isOpen(root.menuId)
    }

    Tooltip {
        anchorItem: root
        active: (clockArea.containsMouse || dateArea.containsMouse) && !Menus.isOpen(root.menuId)
        text: Lang.dateCapitalised(clock.date, "dddd, d MMMM yyyy")
        subtext: "Время — панель управления · дата — календарь · ПКМ — меню"
    }
}
