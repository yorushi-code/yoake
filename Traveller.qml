import QtQuick

// The one marker, moving between slots.
//
// Selection in this shell was drawn by whoever happened to be selected: the
// workspace pill widened itself, the launcher row lit its own fill, and the
// one you came from gave the same thing up on the same frame. Two objects
// changing in opposite directions is a cross-fade, and a cross-fade says the
// state changed without saying *from what* — the eye has nothing to follow, so
// switching desk reads as the bar repainting rather than as going somewhere.
//
// One object that travels answers both at once, and the journey is the message:
// where it set off from is where you were.
//
// The deformation is not decoration. A rigid rectangle sliding at constant
// width reads as a sprite being moved by a program; anything with mass leaves
// its tail behind when it starts and catches up when it stops, and half a
// frame of that is the whole difference between motion and translation. It is
// a transform, so the scene graph applies it for free — no relayout, no
// re-rasterise, which is the reason this is a `Scale` and not an animated
// width.
Item {
    id: root

    // Where the marker belongs, in its parent's coordinates. A caller usually
    // binds these to the geometry of whichever child is current.
    property real slotX: 0
    property real slotY: 0
    property real slotWidth: 0
    property real slotHeight: 0

    // Whether there is anything to mark. A list with nothing selected must not
    // leave the marker parked on a stale row.
    property bool active: true

    // How much a full-length journey deforms the marker, as a fraction of its
    // length. Past about a third it stops reading as mass and starts reading as
    // a rubber band.
    property real give: 0.30
    // The journey length that earns the full `give`. Short hops deform less,
    // which is what keeps a one-step arrow-key walk from looking as dramatic as
    // a jump across the whole list.
    property real span: 140

    // 0 at rest, 1 at the height of the journey. Exposed because the marker is
    // rarely the only thing that should know it is moving — a glow that swells
    // while it travels is the same event, and reading it from here keeps the
    // two in phase without a second timer.
    property real flight: 0
    readonly property bool travelling: root.flight > 0.01

    x: root.slotX
    y: root.slotY
    width: root.slotWidth
    height: root.slotHeight

    opacity: root.active ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.animFast }
    }

    Behavior on x {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpring
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeSpring
        }
    }
    // The size settles faster than the position. A marker that is still growing
    // after it has arrived reads as two arrivals.
    Behavior on width {
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }

    // ── The journey ──

    // The target as it was last seen, rather than the marker's own position.
    //
    // The obvious way to measure a journey is to compare the new slot against
    // where the marker currently is, and it is wrong: by the time a change
    // handler runs, the binding that moves the marker may already have been
    // re-evaluated, so the comparison reads zero distance and the deformation
    // silently never plays. That bug is invisible in code review and obvious on
    // screen, which is the worst combination.
    property real _lastX: 0
    property real _lastY: 0
    // The first placement is not a journey. Without this the marker arrives at
    // the shell's first frame having apparently crossed the entire bar.
    property bool _primed: false

    // 0 horizontal, 1 vertical. A marker travels on one axis at a time; the
    // dominant one wins, because deforming on both at once is a blob.
    property int _axis: 0
    property bool _backward: false
    property real _reach: 0

    onSlotXChanged: root._depart()
    onSlotYChanged: root._depart()

    function _depart() {
        const dx = root.slotX - root._lastX;
        const dy = root.slotY - root._lastY;
        root._lastX = root.slotX;
        root._lastY = root.slotY;
        if (!root._primed) {
            root._primed = true;
            return;
        }
        const distance = Math.hypot(dx, dy);
        // Under a pixel is a rounding artefact of the layout, not a move.
        if (distance < 1) return;
        root._axis = Math.abs(dx) >= Math.abs(dy) ? 0 : 1;
        root._backward = (root._axis === 0 ? dx : dy) < 0;
        root._reach = Math.min(1, distance / root.span);
        journey.restart();
    }

    // Builds quickly and releases slowly, which is the shape of the thing: the
    // tail is longest just after setting off and the marker is at rest again
    // slightly after it lands. Written as fractions of the tempo rather than in
    // milliseconds, so it stays in phase with the position animation at every
    // speed Perception can ask for.
    SequentialAnimation {
        id: journey
        NumberAnimation {
            target: root; property: "flight"; to: 1
            duration: Math.round(Direction.tempo * 0.40)
            easing.type: Easing.OutSine
        }
        NumberAnimation {
            target: root; property: "flight"; to: 0
            duration: Math.round(Direction.tempo * 0.90)
            easing.type: Easing.InOutSine
        }
    }

    readonly property real _amount: root.flight * root.give * root._reach

    // Anchored at the leading edge, so the marker grows a tail rather than
    // swelling in place: heading right, the right edge stays put and the left
    // edge falls behind.
    transform: Scale {
        origin.x: root._axis === 0 ? (root._backward ? 0 : root.width) : root.width / 2
        origin.y: root._axis === 1 ? (root._backward ? 0 : root.height) : root.height / 2
        xScale: root._axis === 0 ? 1 + root._amount : 1 - root._amount * 0.5
        yScale: root._axis === 1 ? 1 + root._amount : 1 - root._amount * 0.5
    }
}
