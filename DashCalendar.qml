import QtQuick

// A month, as a grid.
//
// Built by hand rather than with Qt's MonthGrid because that one starts its
// week on Sunday and offers no way to say otherwise — which is wrong for every
// locale this desktop is used in. Seven columns, Monday first, the current day
// marked.
Column {
    id: root

    required property var today

    spacing: 6

    readonly property int year: root.today.getFullYear()
    readonly property int month: root.today.getMonth()
    readonly property int todayDate: root.today.getDate()

    // getDay() is Sunday-based; this shifts it so Monday is 0.
    readonly property int leading: {
        const first = new Date(root.year, root.month, 1).getDay();
        return (first + 6) % 7;
    }
    readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()

    readonly property var cells: {
        const out = [];
        for (let i = 0; i < root.leading; i++) out.push(0);
        for (let d = 1; d <= root.daysInMonth; d++) out.push(d);
        // Filled to whole weeks so the grid never changes height between
        // months, which would resize the card it sits in.
        while (out.length % 7 !== 0) out.push(0);
        while (out.length < 42) out.push(0);
        return out;
    }

    readonly property int cell: 27

    Row {
        spacing: 0

        Repeater {
            model: ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]

            delegate: Item {
                required property var modelData
                required property int index
                width: root.cell
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    // Saturday and Sunday sit apart without needing a colour
                    // that fights the accent.
                    color: parent.index >= 5 ? Qt.alpha(Theme.subtext0, 0.6) : Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                }
            }
        }
    }

    Grid {
        columns: 7
        spacing: 0

        Repeater {
            model: root.cells

            delegate: Item {
                id: day
                required property var modelData
                required property int index

                readonly property bool present: day.modelData > 0
                readonly property bool isToday: day.present && day.modelData === root.todayDate
                readonly property bool weekend: (day.index % 7) >= 5

                width: root.cell
                height: root.cell

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    visible: day.isToday
                    color: Theme.accent
                }

                Text {
                    anchors.centerIn: parent
                    visible: day.present
                    text: day.modelData
                    color: day.isToday ? Theme.crust
                        : (day.weekend ? Qt.alpha(Theme.subtext1, 0.65) : Theme.subtext1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: day.isToday ? Font.DemiBold : Font.Normal
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
