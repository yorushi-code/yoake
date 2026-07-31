import QtQuick
import Quickshell

// Time and date, sized to its own content so it can be dragged anywhere.
//
// Deliberately unadorned. Two earlier attempts at a glow both showed up as a
// visible rectangle behind the digits: a RectangularShadow draws an actual
// rounded box, and a blurred layer plus MultiEffect leaves a haze the size of
// the layer's texture bounds. The digits carry enough weight on their own —
// what they needed was not decoration but movement, so the places roll rather
// than relabel, and the seconds roll with them at a tenth the size.
Column {
    id: root

    spacing: 8

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: true
    }

    Item {
        id: timeGroup
        width: hhmm.width + 10 + seconds.width
        height: hhmm.height

        RollClock {
            id: hhmm
            anchors.left: parent.left
            hours: clock.date.getHours()
            minutes: clock.date.getMinutes()
            pixelSize: 96
            weight: Font.Bold
            tracking: -2
            groupGap: 5
            minuteInk: Theme.accent
        }

        // Its own group rather than a third place on the clock: seconds move
        // sixty times as often, and at full size that is a widget that never
        // stops twitching. Small and set on the shared baseline, the movement
        // reads as a pulse next to the time instead of competing with it.
        Row {
            id: seconds
            anchors.left: hhmm.right
            anchors.leftMargin: 10
            anchors.baseline: hhmm.baseline
            baselineOffset: s1.baselineOffset

            component Tick: RollDigit {
                pixelSize: 34
                weight: Font.Bold
                ink: Theme.subtext1
            }

            Tick { id: s1; value: Math.floor(clock.date.getSeconds() / 10) }
            Tick { value: clock.date.getSeconds() % 10 }
        }
    }

    Text {
        anchors.right: timeGroup.right
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
        color: Theme.subtext1
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.letterSpacing: 3
        opacity: 0.85
    }
}
