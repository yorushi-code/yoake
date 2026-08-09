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

    // The animation hangs off this rather than off the waterline, because a
    // Behavior cannot be attached to a readonly property and the level is the
    // thing that actually moves -- the waterline is where the geometry puts it.
    property real level: Math.max(0, Math.min(1, root.value))

    Behavior on level {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }

    readonly property real waterline: root.height * (1 - root.level)

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

            // A circle squashed by a transform, not a rounded rectangle.
            //
            // The obvious spelling -- a wide, short rect with radius = width/2
            // -- does not work: Qt clamps the radius to half the *shorter*
            // side, so a 1.9x-wide, 30px-tall box comes out as a stadium and
            // fills the whole tile instead of arcing across it. Scaling a real
            // circle gives the ellipse the radius property cannot express.
            readonly property real span: root.width * 1.9
            width: crest.span
            height: crest.span
            radius: crest.span / 2
            color: root.tint
            opacity: crest.index === 0 ? 1 : Theme.veilFirm

            // The centre sits a full semi-axis below the surface, so only the
            // top of the arc clears the waterline and the rest of the ellipse
            // is inside the liquid where it cannot be seen.
            readonly property real bulge: root.swell * (crest.index === 0 ? 1 : 0.6)
            readonly property real semi: root.height
            y: root.waterline - crest.bulge - crest.span / 2 + crest.semi

            transform: Scale {
                origin.x: crest.span / 2
                origin.y: crest.span / 2
                yScale: crest.semi / (crest.span / 2)
            }

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
