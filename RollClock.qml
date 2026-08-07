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
    // Pulses on the second. Off where there is no room for it to read.
    property bool blink: true

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
                    opacity: 0.35

                    SequentialAnimation on opacity {
                        running: root.blink
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * Theme.animBusy }
                        NumberAnimation { to: 1.0; duration: Theme.animBusy; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0.35; duration: Theme.animBusy; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }
    }

    Place { value: Math.floor(root.minutes / 10); ink: root.minuteInk }
    Place { value: root.minutes % 10; ink: root.minuteInk }
}
