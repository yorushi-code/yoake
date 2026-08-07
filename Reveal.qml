import QtQuick

// Wrapper that gives its contents one consistent arrival — as a sequence, not
// as a single event.
//
// Every panel and row in the shell had been spelling out the same pair of
// Behaviors — opacity plus scale, different duration and curve per direction —
// and they had drifted: some scaled from 0.9, some from 0.92, one from 0.88,
// and a few had no exit curve at all so they lingered at low opacity until the
// window was cut. Routing them through here is what makes the shell read as
// one piece of software rather than several.
//
// It used to give its contents *one* motion, which was the whole technical
// debt: four things that should be four events — the room being made, the
// surface arriving, the accent lighting, the content filling in — happened on
// the same frame, and simultaneity is exactly what makes an interface read as
// a machine executing instructions rather than a space rearranging itself.
//
// This file now contains no durations and no offsets. It asks Direction for
// the beats of its declared surface type and plays them. Changing the
// choreography means changing the type or changing Direction; there is nothing
// here to tune, which is the point.
//
// `shown` is the requested state. `delay` staggers an item within a cascade —
// pass Direction.stagger(index) — and composes with the beats rather than
// replacing them.
Item {
    id: root

    default property alias content: contentLayer.children

    property bool shown: false
    // "narrative" | "acknowledge" | "continuous" | "ambient" — see Direction.
    property string surfaceType: "narrative"
    property int delay: 0
    // Which edge the content comes from. Zero for a pure scale-and-fade.
    property real slideX: 0
    property real slideY: 0
    property real fromScale: Theme.revealScale
    property int origin: Item.Center

    readonly property var _beats: Direction.beatsFor(root.surfaceType)

    // How far the accent beat has got, 0 to 1. Exposed rather than applied,
    // because this wrapper cannot know which of its children is the accent —
    // a caller binds a glow, a ring or a fill to it. Without this the accent
    // beat would be unplayable by anything and the sequence would be three
    // beats pretending to be four.
    property real accentProgress: root.shown ? 1 : 0
    Behavior on accentProgress {
        SequentialAnimation {
            PauseAnimation { duration: root.shown ? root.delay + root._beats.accent : 0 }
            NumberAnimation {
                duration: root.shown ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.shown ? Theme.easeEmphasized : Theme.easeExit
            }
        }
    }

    implicitWidth: contentLayer.implicitWidth
    implicitHeight: contentLayer.implicitHeight

    // ── Beat 1: space ──
    //
    // The room is made before anything moves into it. A surface arriving into
    // room that does not exist yet has to shove its neighbours aside, and
    // shoving is the difference between an interface that opens and one that
    // interrupts. This is the scale change, and it leads because it is the one
    // beat that changes how much space the thing occupies.
    Item {
        id: spaceLayer
        anchors.fill: parent
        transformOrigin: root.origin
        scale: root.shown ? 1 : root.fromScale

        Behavior on scale {
            SequentialAnimation {
                PauseAnimation { duration: root.shown ? root.delay + root._beats.space : 0 }
                NumberAnimation {
                    duration: root.shown ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                }
            }
        }

        // ── Beat 2: the surface ──
        //
        // The object becomes present. Motion is already under way by the time
        // this is legible, which is rule 4: movement is what the eye catches,
        // and arriving and then starting to move is two events where there
        // should be one.
        Item {
            id: surfaceLayer
            anchors.fill: parent
            opacity: root.shown ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.shown ? root.delay + root._beats.object : 0 }
                    NumberAnimation {
                        duration: root.shown ? Theme.animNormal : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.shown ? Theme.easeEmphasized : Theme.easeExit
                    }
                }
            }

            // ── Beat 4: content ──
            //
            // Last, and the only beat that travels: the slide lives here
            // rather than on the whole wrapper so what settles into place is
            // the material, after the container holding it has already
            // stopped.
            //
            // Leaving is not sequenced. A cascade on the way out looks like
            // the panel struggling to close — beats direct attention toward
            // something, and on the way out there is nothing to direct it to.
            Item {
                id: contentLayer
                anchors.fill: parent
                x: root.shown ? 0 : root.slideX
                y: root.shown ? 0 : root.slideY
                opacity: root.shown ? 1 : 0

                Behavior on x {
                    SequentialAnimation {
                        PauseAnimation { duration: root.shown ? root.delay + root._beats.content : 0 }
                        NumberAnimation {
                            duration: root.shown ? Theme.animSlow : Theme.animExit
                            easing.type: Easing.Bezier
                            easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                        }
                    }
                }
                Behavior on y {
                    SequentialAnimation {
                        PauseAnimation { duration: root.shown ? root.delay + root._beats.content : 0 }
                        NumberAnimation {
                            duration: root.shown ? Theme.animSlow : Theme.animExit
                            easing.type: Easing.Bezier
                            easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                        }
                    }
                }
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: root.shown ? root.delay + root._beats.content : 0 }
                        NumberAnimation {
                            duration: root.shown ? Theme.animNormal : Theme.animExit
                            easing.type: Easing.Bezier
                            easing.bezierCurve: root.shown ? Theme.easeEmphasized : Theme.easeExit
                        }
                    }
                }
            }
        }
    }
}
