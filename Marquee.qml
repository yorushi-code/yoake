import QtQuick

// Text too long for its slot, moving continuously past it.
//
// The shell elided. Eliding is right for a list you are scanning and wrong for
// the one line that is the subject of its own widget: "параноия - ALASKA PU…"
// is not a track title, it is a promise that there is a track title somewhere.
//
// A second copy follows the first across a gap, so the line is a loop rather
// than a shuttle. Sliding to the end and back is the obvious implementation and
// it reads as the text being dragged by something; a loop reads as a ticker,
// which is a thing people already know how to read.
Item {
    id: root

    property string text: ""
    property color color: Theme.text
    property real pixelSize: Theme.fontBody
    property int weight: Font.Normal
    // Blank between the tail of one copy and the head of the next. Too small
    // and the loop looks like a rendering fault.
    property real gap: 48
    // Pixels a second. Reading speed, not scrolling speed: fast enough not to
    // be a wait, slow enough to actually read.
    property real speed: 34
    property bool paused: false

    clip: true
    implicitWidth: probe.implicitWidth
    implicitHeight: probe.implicitHeight

    readonly property bool overflows: probe.implicitWidth > root.width + 1
    readonly property real span: probe.implicitWidth + root.gap

    Text {
        id: probe
        visible: false
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: root.pixelSize
        font.weight: root.weight
    }

    Row {
        id: track
        spacing: root.gap
        x: 0

        Repeater {
            // Two copies when it loops, one when it does not -- a second copy
            // of a line that already fits is a second line.
            model: root.overflows ? 2 : 1

            delegate: Text {
                text: root.text
                color: root.color
                font.family: Theme.fontFamily
                font.pixelSize: root.pixelSize
                font.weight: root.weight
            }
        }
    }

    // Restarted rather than looped forever: the animation is stopped whenever
    // the line fits or playback is paused, and a stopped animation is the only
    // kind that lets the window's render loop go idle.
    NumberAnimation {
        id: run
        target: track
        property: "x"
        from: 0
        to: -root.span
        duration: Math.max(1, Math.round(root.span / Math.max(1, root.speed) * 1000))
        loops: Animation.Infinite
        running: root.overflows && !root.paused && root.visible
    }

    // A new title starts from the beginning rather than from wherever the old
    // one happened to be.
    onTextChanged: {
        track.x = 0;
        if (run.running) run.restart();
    }
}
