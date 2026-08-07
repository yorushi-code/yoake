import QtQuick
import Quickshell
import Quickshell.Wayland

// Month grid hanging under the bar's date readout. Written by hand rather
// than pulled from QtQuick.Controls: the Controls calendar drags in a styling
// stack that would fight the rest of the shell's look.
PanelWindow {
    id: win
    // Overlay, not the default Top: niri draws a fullscreen window above
    // the Top layer, so a panel the user just asked for would open behind
    // the video they were watching and read as a dead keystroke.
    WlrLayershell.layer: WlrLayer.Overlay

    // Animations bind to this, not to the toggle. The panel is created lazily,
    // which means it is born with the toggle already true — an entry animation
    // bound straight to the toggle has nothing to animate from and the panel
    // simply appears at its final size. `armed` turns on a frame later, so the
    // open state is always a transition.
    readonly property bool open: Toggles.calendarOpen && win.armed
    property bool armed: false
    Component.onCompleted: {
        armTick.start();
        win.mapped = Toggles.calendarOpen;
    }
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: win.armed = true
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    // Bound to the toggle, not to `open`. `open` waits a frame for `armed`
    // so the entrance has something to animate from, and a surface mapped
    // asking for no keyboard never gets offered one afterwards -- which is
    // a panel that ignores Escape and every key in it.
    focusable: Toggles.calendarOpen
    // Exclusive, not merely focusable. `focusable` alone asks for
    // on-demand interactivity, which means the compositor hands over the
    // keyboard when the surface is clicked -- so a panel opened from a
    // keybind ignored Escape until you had clicked it first.
    WlrLayershell.keyboardFocus: Toggles.calendarOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // Escape closes it, from anywhere inside.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Toggles.calendarOpen = false;
                event.accepted = true;
            }
        }
    }
    // Explicit mapping bool — see ControlCenter.qml (avoids the visible-binding
    // race that cut the exit animation short).
    property bool mapped: false
    visible: mapped

    // Months away from the real current month, reset whenever the panel is
    // reopened so it never comes back showing some month from last time.
    property int monthOffset: 0
    // Day-of-month the user picked, or 0 for none. The cells used to have a
    // hover-enabled MouseArea with no onClicked whatsoever: they highlighted
    // under the pointer and then did nothing at all.
    // Set here as well as on open: the panel is created lazily, so on the very
    // first open it is born after the toggle has already flipped and the
    // handler for that change never runs.
    property int selectedDay: new Date().getDate()

    readonly property date viewDate: {
        const now = new Date();
        return new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
    }
    readonly property date today: new Date()

    readonly property var monthNames: [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]

    // 42 cells = 6 rows, enough for any month/offset combination, so the grid
    // never changes height as you page through months.
    readonly property var cells: {
        const y = viewDate.getFullYear();
        const m = viewDate.getMonth();
        // JS weeks start Sunday; shift so Monday is column 0.
        const lead = (new Date(y, m, 1).getDay() + 6) % 7;
        const count = new Date(y, m + 1, 0).getDate();
        const prevCount = new Date(y, m, 0).getDate();

        const out = [];
        for (let i = 0; i < 42; i++) {
            const dayNum = i - lead + 1;
            if (dayNum < 1) {
                out.push({ day: prevCount + dayNum, inMonth: false });
            } else if (dayNum > count) {
                out.push({ day: dayNum - count, inMonth: false });
            } else {
                out.push({ day: dayNum, inMonth: true });
            }
        }
        return out;
    }

    function isToday(cell) {
        return cell.inMonth
            && viewDate.getFullYear() === today.getFullYear()
            && viewDate.getMonth() === today.getMonth()
            && cell.day === today.getDate();
    }

    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: win.mapped = false
    }
    Connections {
        target: Toggles
        function onCalendarOpenChanged() {
            if (Toggles.calendarOpen) {
                hideDelay.stop();
                win.mapped = true;
                win.monthOffset = 0;
                // Today, not nothing. The line under the grid counts the days
                // to whatever is selected, and opening on "Выберите день" spent
                // that line on an instruction instead of on the one date the
                // panel already knows the reader cares about.
                win.selectedDay = new Date().getDate();
            } else {
                hideDelay.restart();
            }
        }
    }
    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.calendarOpen = false

        // Click-outside-to-close. The panel previously masked input to the card
        // only, which left the keybind or the ✕ as the sole ways out.
        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.calendarOpen = false
        }

        PanelChrome {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            width: 320
            height: 352
            screenX: (Screen.width - width) / 2
            screenY: Theme.barHeight + Theme.barMargin * 2
            onCloseRequested: Toggles.calendarOpen = false

            // Swallows clicks so the backdrop doesn't read a click on the
            // calendar itself as "outside".
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.9
            transformOrigin: Item.Top
            // See ControlCenter: open punches in, exit accelerates.
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeSpringBig : Theme.easeExit
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                anchors.topMargin: 16
                spacing: 12

                // ── Month header ──
                Item {
                    width: parent.width
                    height: 28

                    MediaButton {
                        glyph: Glyphs.chevronLeft
                        size: 26
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        onActivated: win.monthOffset--
                    }

                    Text {
                        anchors.centerIn: parent
                        text: `${win.monthNames[win.viewDate.getMonth()]} ${win.viewDate.getFullYear()}`
                        color: Theme.text
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                    }

                    MediaButton {
                        glyph: Glyphs.chevronRight
                        size: 26
                        // Sits left of the chrome's close button rather than in
                        // the corner, which the close button already owns.
                        anchors.right: parent.right
                        anchors.rightMargin: 26
                        anchors.verticalCenter: parent.verticalCenter
                        onActivated: win.monthOffset++
                    }
                }

                // ── Weekday header ──
                Row {
                    width: parent.width
                    Repeater {
                        model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                        delegate: Text {
                            required property var modelData
                            required property int index
                            width: parent.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            // Weekend columns are dimmer so the working week
                            // reads as the default.
                            color: index >= 5 ? Theme.subtext0 : Theme.subtext1
                            font.pixelSize: Theme.fontLabel
                            font.bold: true
                        }
                    }
                }

                // ── Day grid ──
                Grid {
                    width: parent.width
                    columns: 7
                    rowSpacing: 2

                    Repeater {
                        model: win.cells
                        delegate: Item {
                            id: dayCell
                            required property var modelData
                            required property int index
                            width: parent.width / 7
                            height: 32

                            readonly property bool isToday: win.isToday(modelData)
                            readonly property bool isSelected: modelData.inMonth
                                && win.selectedDay === modelData.day

                            Rectangle {
                                id: dayCircle
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                radius: Theme.pill(height)
                                // Today keeps the accent fill; the picked day
                                // gets a ring; everything else a soft circle
                                // that scales in on hover.
                                color: dayCell.isToday
                                    ? Theme.accent
                                    : (dayMa.containsMouse ? Qt.alpha(Theme.accent, Theme.tintSubtle) : "transparent")
                                border.color: Theme.accent
                                border.width: (dayCell.isSelected && !dayCell.isToday) ? 2 : 0
                                scale: (dayCell.isToday || dayCell.isSelected || dayMa.containsMouse) ? 1.0 : 0.6
                                Behavior on scale {
                                    NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                                }
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Ripple {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    rippleColor: Theme.accent
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.pixelSize: Theme.fontBody
                                font.bold: dayCell.isToday || dayCell.isSelected
                                color: {
                                    if (dayCell.isToday) return Theme.crust;
                                    if (!modelData.inMonth) return Qt.alpha(Theme.subtext0, Theme.inkFaint);
                                    return index % 7 >= 5 ? Theme.subtext1 : Theme.text;
                                }
                            }

                            MouseArea {
                                id: dayMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Clicking a leading/trailing day pages to the
                                // month it belongs to, which is what makes them
                                // worth showing at all.
                                onClicked: {
                                    if (!modelData.inMonth) {
                                        win.monthOffset += (dayCell.index < 7) ? -1 : 1;
                                    }
                                    // Always selects. Clicking the selected day
                                    // used to clear it, which now only puts the
                                    // line back to an instruction -- there is no
                                    // state under it worth returning to.
                                    win.selectedDay = modelData.day;
                                }
                            }
                        }
                    }
                }

                // ── Footer: what the picked day actually is ──
                // Selecting a day is only useful if it tells you something; the
                // full weekday and the distance from today are the two things
                // worth knowing about a date you just tapped.
                Item {
                    width: parent.width
                    height: 22

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (win.selectedDay === 0) return "Выберите день";
                            const d = new Date(win.viewDate.getFullYear(), win.viewDate.getMonth(), win.selectedDay);
                            const label = Lang.dateCapitalised(d, "dddd, d MMMM yyyy");
                            const today = new Date();
                            const days = Math.round((d - new Date(today.getFullYear(), today.getMonth(), today.getDate())) / 86400000);
                            if (days === 0) return label + " · сегодня";
                            if (days > 0) return label + ` · через ${days} дн.`;
                            return label + ` · ${-days} дн. назад`;
                        }
                        color: win.selectedDay === 0 ? Theme.subtext0 : Theme.subtext1
                        font.pixelSize: Theme.fontSmall
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }
    }
}
