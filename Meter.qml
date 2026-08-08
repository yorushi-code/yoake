import QtQuick

// A row of bars for a spectrum.
//
// The one detail that matters here is what a bar does at zero. Drawn as a
// rectangle it becomes a one-pixel sliver, and a row of slivers reads as a
// broken widget -- something that was meant to be there and failed. Given round
// caps and a floor equal to its own width, the same bar collapses into a dot,
// and a row of evenly spaced dots reads as *quiet*, which is what it is.
//
// That is the whole difference between a spectrum that looks alive when the
// music stops and one that looks dead.
Row {
    id: root

    // 0..1 each.
    property var values: []
    property color tint: Theme.accent
    property real barWidth: 4
    property real maxHeight: 18
    // Nothing below this: the dot. Exactly the bar's width, so it is a circle.
    readonly property real floorHeight: root.barWidth

    spacing: 3

    Repeater {
        model: root.values.length

        delegate: Rectangle {
            required property int index
            readonly property real level: Math.max(0, Math.min(1, root.values[index] || 0))

            width: root.barWidth
            height: root.floorHeight + (root.maxHeight - root.floorHeight) * level
            radius: width / 2
            color: root.tint
            anchors.verticalCenter: parent.verticalCenter

            // No Behavior. cava already delivers a damped falling edge, and a
            // per-bar animation restarting on every frame never finishes and
            // re-renders the row for nothing (see BarIsland's measurement).
        }
    }
}
