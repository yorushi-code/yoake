import QtQuick

// A tank with something in it.
//
// A level drawn as a rectangle is a progress bar standing on end. A level with
// a curved, moving surface is a *quantity of something*, and that reading is
// worth having for the two values in this shell that really are quantities:
// how much sound is coming out and how much charge is left.
//
// The meniscus is two flattened ellipses sliding past each other at different
// speeds, not a recomputed path. A path redrawn every frame is geometry work
// sixty times a second for a 96px tile; two ellipses are transforms.
//
// `active` is not optional. This is a permanently running animation, and the
// measured cost of one of those on a large surface is a fifth of a core -- so
// it runs while the panel holding it is open and is genuinely stopped, not
// paused, the rest of the time.
Item {
    id: root

    property real value: 0
    property color tint: Theme.accent
    property bool active: false
    // How far the surface rises and falls. Small: this is water in a glass, not
    // a sea.
    property real swell: 3

    clip: true

    readonly property real waterline: root.height * (1 - Math.max(0, Math.min(1, root.value)))

    Behavior on waterline {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }

    // The body of the liquid, below the surface.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        y: root.waterline
        height: root.height - root.waterline
        color: root.tint
    }

    // Two crests. Wider than the tile and taller than they look, so only the
    // top of each arc is ever in frame -- which is what makes the surface read
    // as curved rather than as a lens sliding past.
    Repeater {
        model: 2

        delegate: Rectangle {
            id: crest
            required property int index

            readonly property real span: root.width * 1.9
            width: crest.span
            height: root.height * 1.4
            radius: width / 2
            color: root.tint
            opacity: crest.index === 0 ? 1 : Theme.veilFirm
            y: root.waterline - height + root.swell * (crest.index === 0 ? 1 : 0.5)

            SequentialAnimation on x {
                running: root.active && root.visible
                loops: Animation.Infinite
                NumberAnimation {
                    from: crest.index === 0 ? -crest.span * 0.5 : root.width - crest.span * 0.5
                    to: crest.index === 0 ? root.width - crest.span * 0.5 : -crest.span * 0.5
                    duration: crest.index === 0 ? Theme.animDoze : Math.round(Theme.animDoze * 1.6)
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: crest.index === 0 ? root.width - crest.span * 0.5 : -crest.span * 0.5
                    to: crest.index === 0 ? -crest.span * 0.5 : root.width - crest.span * 0.5
                    duration: crest.index === 0 ? Theme.animDoze : Math.round(Theme.animDoze * 1.6)
                    easing.type: Easing.InOutSine
                }
            }

            // Parked flat when the panel is shut, so a closed tile still reads
            // as a level rather than as a wave frozen mid-slosh.
            Binding on x {
                when: !root.active
                value: -crest.span * 0.25
            }
        }
    }
}
