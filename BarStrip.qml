import QtQuick

// The bar, as one strip.
//
// It was three floating islands, and the air between them was the whole
// argument for them: the wallpaper showed through, so the shell read as lying
// *on* the desktop rather than cropping it. What that air cost was the grid.
// The space between two islands is not *between* anything — it is three objects
// with holes punched around them — so nothing in the bar had a place, only a
// neighbour, and every chip had to be found by reading its glyph.
//
// One strip is a row with slots in it. The zones are separated by order and by
// a hairline, which is a boundary a person can see; a gap is only a boundary if
// you already know one is supposed to be there.
Item {
    id: root

    // The three zones, assigned as lists: a caller that wants two chips and a
    // divider in one zone should write them in the order they appear on screen,
    // which a list does and three named slots do not.
    property alias leftItems: leftRow.data
    property alias centreItems: centreRow.data
    property alias rightItems: rightRow.data

    // The centre zone, for handlers that want the whole of it rather than one
    // widget inside it — the dashboard peek is the only one.
    readonly property alias centreArea: centreZone

    // Which point of the centre zone lands on the bar's midpoint, measured from
    // that zone's own left edge. Negative means "whatever is in the middle of
    // it".
    //
    // The clock is what has to be centred, not the zone around it. Centring the
    // zone puts its *midpoint* on the bar's, so the clock would slide sideways
    // by half the recorder chip's width the moment a recording started — and a
    // clock is read by position before it is read at all. Composing the zone
    // against a fixed point instead means everything else opens room around a
    // clock that never moves.
    property real centreAnchorX: -1

    // Inset from the ends of the strip. The strip is nearly the width of the
    // screen, so this is the only air the layout has and it has to read as
    // deliberate at both ends.
    readonly property int pad: Theme.gapWide

    // A zone boundary, written once.
    //
    // Derived from the bar's height rather than pinned at 16: a rule that is
    // 45% of the strip stays a rule if the strip ever changes, where a literal
    // becomes either a tick or a full-height wall.
    component Divider: Rectangle {
        width: 1
        height: Math.round(Theme.barHeight * 0.45)
        radius: width / 2
        color: Qt.alpha(Theme.text, Theme.fillMuted)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // A frame, so `shown` has a false to animate away from. Bound straight to
    // true the entrance has nothing to play and the bar is simply there — which
    // is what it did for as long as it existed: the one surface on screen
    // before anything else, and the only one that never said hello.
    property bool arrived: false

    Timer {
        interval: 16
        running: true
        onTriggered: root.arrived = true
    }

    // The strip plays the space beat for everything on it: one surface stretching
    // out, and the three zones arriving into a room that is already made.
    Reveal {
        id: entrance
        anchors.fill: parent
        shown: root.arrived

        Surface {
            anchors.fill: parent
            radius: Theme.radiusStrip
            elevation: "bar"
            // The window is itself inset by barMargin, so the glass behind the
            // strip samples from there rather than from the screen origin.
            screenX: Theme.barMargin
            screenY: Theme.barMargin
        }
    }

    // ── The zones ──
    //
    // Each arrives on its own beat, and the two ends travel inward from the
    // edge they belong to. No vertical slide anywhere: the window is exactly as
    // tall as the strip, so anything moved in y is cropped by the layer surface
    // instead of travelling. The scale beat is the strip's, not theirs — a zone
    // that also grew would be the same event played twice at two sizes.
    Item {
        id: leftZone
        x: root.pad
        y: 0
        width: leftRow.width
        height: root.height

        Reveal {
            anchors.fill: parent
            shown: root.arrived
            delay: Direction.stagger(0)
            fromScale: 1
            slideX: -Theme.revealSlide

            Row {
                id: leftRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.chipGap
            }
        }
    }

    Item {
        id: rightZone
        x: root.width - rightRow.width - root.pad
        y: 0
        width: rightRow.width
        height: root.height

        Reveal {
            anchors.fill: parent
            shown: root.arrived
            delay: Direction.stagger(1)
            fromScale: 1
            slideX: Theme.revealSlide

            Row {
                id: rightRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.chipGap
            }
        }
    }

    Item {
        id: centreZone
        // Deliberately without a Behavior. This and the clock's own position
        // inside the row are recomputed from the same layout pass, so they move
        // on the same frame and the clock stays exactly still while the zone
        // widens under it. Animating it would make the clock wobble by the
        // difference between two curves.
        x: Math.round(root.width / 2
                      - (root.centreAnchorX >= 0 ? root.centreAnchorX : centreRow.width / 2))
        y: 0
        width: centreRow.width
        height: root.height

        Reveal {
            anchors.fill: parent
            shown: root.arrived
            // Last, so the thing carrying the light lands after the shell has
            // told you where you are and how the machine is.
            delay: Direction.stagger(2)
            fromScale: 1
            slideX: 0

            Row {
                id: centreRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.chipGap
            }
        }
    }
}
