import QtQuick

// A time made of rolling digits.
//
// Each place is its own strip, so at 09:59 → 10:00 three of them move and the
// leading 0 sits still — which is what the eye expects and what a whole-string
// animation cannot do.
Row {
    id: root

    // 0..23 and 0..59.
    property int hours: 0
    property int minutes: 0

    property int pixelSize: 56
    property string family: Theme.fontDisplayFamily
    property int weight: Font.DemiBold
    property color ink: Theme.text
    // The minutes can be tinted apart from the hours; by default they are not.
    property color minuteInk: root.ink
    property real tracking: 0
    // The gap between hours and minutes; the separator sits inside it.
    property real groupGap: 6
    property bool showSeparator: true
    // Pulses on the second. Off everywhere, and off by default.
    //
    // It was on, on the desktop clock, forever. Measured: two three-pixel dots
    // breathing cost twenty points of a core -- not because of the dots, but
    // because *any* running animation holds its window's render loop at the
    // refresh rate, and the widget window is the size of the screen. Switching
    // it off with the sleeping cat's floating "z" took the shell from 48% of a
    // core to 27% with nothing playing and nothing on screen moving.
    //
    // That is the line this shell draws: continuous motion is for something
    // that is *happening* -- cava has music behind it, the load ring has load
    // -- and a colon pulsing at three in the morning for nobody is the whole
    // cost with none of the reason. The digits roll once a minute, which is the
    // life this clock actually has.
    property bool blink: false
    // How present the colon is between pulses -- and, with `blink` off, all the
    // time. A hero clock wants it faint enough that the digits lead; a 15px bar
    // clock wants it as legible as they are, or the time reads as two numbers.
    property real separatorRest: Theme.inkFaint

    spacing: 0

    baselineOffset: h1.baselineOffset

    component Place: RollDigit {
        pixelSize: root.pixelSize
        family: root.family
        weight: root.weight
        ink: root.ink
        tracking: root.tracking
    }

    Place { id: h1; value: Math.floor(root.hours / 10) }
    Place { value: root.hours % 10 }

    Item {
        width: root.groupGap * 2 + sep.width
        height: 1
        anchors.verticalCenter: parent.verticalCenter

        Column {
            id: sep
            anchors.centerIn: parent
            visible: root.showSeparator
            spacing: Math.round(root.pixelSize * 0.16)

            Repeater {
                model: 2

                delegate: Rectangle {
                    required property int index
                    width: Math.max(3, Math.round(root.pixelSize * 0.075))
                    height: width
                    radius: width / 2
                    color: root.ink
                    // The two dots breathe out of phase, which reads as a pulse
                    // rather than as a colon flashing on and off.
                    opacity: root.separatorRest

                    SequentialAnimation on opacity {
                        running: root.blink
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * Theme.animBusy }
                        NumberAnimation { to: 1.0; duration: Theme.animBusy; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: root.separatorRest; duration: Theme.animBusy; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }
    }

    Place { value: Math.floor(root.minutes / 10); ink: root.minuteInk }
    Place { value: root.minutes % 10; ink: root.minuteInk }
}
