import QtQuick

// Wrapper that gives its contents one consistent arrive/leave motion.
//
// Every panel and row in the shell had been spelling out the same pair of
// Behaviors — opacity plus scale, different duration and curve per direction —
// and they had drifted: some scaled from 0.9, some from 0.92, one from 0.88,
// and a few had no exit curve at all so they lingered at low opacity until the
// window was cut. Routing them through here is what makes the shell read as
// one piece of software rather than several.
//
// `shown` is the requested state. `delay` staggers an item within a cascade —
// pass Theme.stagger(index).
Item {
    id: root

    default property alias content: inner.data

    property bool shown: false
    property int delay: 0
    // Which edge the content comes from. Zero for a pure scale-and-fade.
    property real slideX: 0
    property real slideY: 0
    property real fromScale: Theme.revealScale
    property int origin: Item.Center

    implicitWidth: inner.implicitWidth
    implicitHeight: inner.implicitHeight

    Item {
        id: inner
        anchors.fill: parent
        transformOrigin: root.origin

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : root.fromScale
        x: root.shown ? 0 : root.slideX
        y: root.shown ? 0 : root.slideY

        // The stagger applies on the way in only. Leaving in sequence looks
        // like the list is struggling to close.
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? root.delay : 0 }
                NumberAnimation {
                    duration: root.shown ? Theme.animNormal : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeEmphasized : Theme.easeExit
                }
            }
        }
        Behavior on scale {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? root.delay : 0 }
                NumberAnimation {
                    duration: root.shown ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                }
            }
        }
        Behavior on x {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? root.delay : 0 }
                NumberAnimation {
                    duration: root.shown ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                }
            }
        }
        Behavior on y {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? root.delay : 0 }
                NumberAnimation {
                    duration: root.shown ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                }
            }
        }
    }
}
