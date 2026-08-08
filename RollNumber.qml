import QtQuick

// A whole number made of rolling digits.
//
// RollDigit has been in this shell since the first clock and has only ever had
// one caller shape: a time. Every other number the shell shows -- a volume, a
// percentage, a count -- was a Text being reassigned, which is the same thing
// the bar clock was doing and wrong for the same reason: a number that changes
// by being replaced tells you it is different without telling you it *moved*,
// and moved is the whole content of a volume key.
//
// Fixed places, hidden rather than destroyed. A Repeater whose model length
// changes rebuilds delegates, and a rebuilt RollDigit has no previous value to
// roll from -- so 99 -> 100 would drop the two digits that were about to roll
// and replace them with three that simply appear.
Row {
    id: root

    property int value: 0
    // Below this, places are padded with zeros rather than dropped. A clock
    // wants two; a percentage wants one, so nine per cent is "9" and not "09".
    property int minPlaces: 1

    property int pixelSize: Theme.fontBody
    property string family: Theme.fontFamily
    property int weight: Font.Medium
    property color ink: Theme.text
    property real tracking: 0

    // Four covers everything this shell counts: a percentage, a notification
    // backlog, a temperature, a port number is not a thing anyone rolls.
    readonly property int _slots: 4
    readonly property int _shown: Math.max(root.minPlaces,
        String(Math.max(0, root.value)).length)

    spacing: 0

    // When 99 becomes 100 a place appears on the left, and the digits that were
    // already there should slide over rather than jump.
    move: MotionMove {}

    Repeater {
        id: places
        model: root._slots

        delegate: RollDigit {
            required property int index
            // Slot 0 is the most significant. A positioner skips invisible
            // children, so hiding one is also how it stops taking room.
            visible: index >= root._slots - root._shown
            value: Math.floor(Math.max(0, root.value)
                / Math.pow(10, root._slots - 1 - index)) % 10
            pixelSize: root.pixelSize
            family: root.family
            weight: root.weight
            ink: root.ink
            tracking: root.tracking
        }
    }
}
