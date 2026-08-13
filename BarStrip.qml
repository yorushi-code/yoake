import QtQuick

// The bar, as three islands sized to what is in them.
//
// It has been all three shapes now, and the argument moved each time because
// each shape was answering a different complaint.
//
// It was islands, then one full-width strip. The case for the strip was the
// grid: the space between two islands is not *between* anything, so nothing in
// the bar had a place, only a neighbour. That is true, and it is not what a
// person notices. What a person notices on a 1920px screen is that the strip
// was about a thousand pixels of content and nine hundred of nothing — a
// surface stretched over half a screen of dead glass, with the frost and the
// hairline and the shadow all drawn faithfully around emptiness. Reported as
// "the length of the bar, too much space", which is exactly what it was.
//
// So the grid argument is answered rather than dropped. A zone is a *group*
// now, and a group with an edge around it is a stronger boundary than a hairline
// inside a continuous surface ever was: the left island is what you are doing,
// the centre is when, the right is how the machine is. A chip is still found by
// position, and now it is found by which object it is on before that.
//
// The air comes back for free, and it was the original argument for islands:
// the wallpaper shows through between them, so the shell reads as lying on the
// desktop rather than cropping the top off it.
Item {
    id: root

    // The three zones, assigned as lists: a caller that wants two chips and a
    // divider in one zone should write them in the order they appear on screen,
    // which a list does and three named slots do not.
    property alias leftItems: leftRow.data
    property alias centreItems: centreRow.data
    property alias rightItems: rightRow.data

    // Which point of the centre island lands on the bar's midpoint, measured
    // from that island's own row rather than from its edge.
    //
    // The clock is what has to be centred, not the island around it. Centring
    // the island puts its *midpoint* on the bar's, so the clock would slide
    // sideways by half the recorder chip's width the moment a recording started
    // — and a clock is read by position before it is read at all. Composing
    // against a fixed point instead means everything else opens room around a
    // clock that never moves.
    property real centreAnchorX: -1

    // How far the outer islands sit from the ends of the screen, on top of the
    // window's own margin. Small: the point of the change was to stop spending
    // width, and an island held far off the edge spends it at both ends.
    readonly property int pad: Theme.gapTight

    // The air inside an island, between its edge and the first chip. It has to
    // clear the corner radius, or the outermost glyph sits in the curve.
    readonly property int islandPad: Theme.gapWide

    // A pill. At a 36px bar a full round is the shape the eye reads as one
    // object rather than as a rectangle with softened corners, and three of them
    // in a row have to read as three objects — that is the entire change.
    readonly property int islandRadius: Math.round(root.height / 2)

    // A boundary inside one island, written once.
    //
    // Still wanted, and it means something narrower than it did: it separates
    // two runs of chips that belong to the same group, where the gap between
    // islands separates the groups themselves.
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

    // ── The islands ──
    //
    // Each is one object and arrives as one: the surface and the chips on it
    // scale, fade and travel together inside a single `Reveal`, rather than a
    // strip that grew while its contents slid about inside it. That was two
    // events drawn as one thing; this is one event, three times, on three beats.
    //
    // Left, then right, then centre, so the thing carrying the light lands last
    // — rule 3, and also the build anyone would choose. No vertical slide
    // anywhere: the window is exactly as tall as the islands, so anything moved
    // in y would be cropped by the layer surface instead of travelling.
    //
    // An island with nothing on it is not a small island, it is not there. The
    // tray empties, and a pill holding no chips is a bubble of glass in the bar.

    Item {
        id: leftIsland
        x: root.pad
        y: 0
        width: leftRow.width + root.islandPad * 2
        height: root.height
        visible: leftRow.width > 0

        Reveal {
            anchors.fill: parent
            shown: root.arrived
            delay: Direction.stagger(0)
            slideX: -Theme.revealSlide

            Surface {
                anchors.fill: parent
                radius: root.islandRadius
                elevation: "bar"
                // The window is itself inset by barMargin, and each island sits
                // at its own offset inside it, so the glass behind one samples
                // from where that island actually is. One shared origin would
                // hand the centre and right islands the left one's slice of
                // wallpaper.
                screenX: Theme.barMargin + leftIsland.x
                screenY: Theme.barMargin
            }

            Row {
                id: leftRow
                x: root.islandPad
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.chipGap
            }
        }
    }

    Item {
        id: rightIsland
        x: root.width - width - root.pad
        y: 0
        width: rightRow.width + root.islandPad * 2
        height: root.height
        visible: rightRow.width > 0

        Reveal {
            anchors.fill: parent
            shown: root.arrived
            delay: Direction.stagger(1)
            slideX: Theme.revealSlide

            Surface {
                anchors.fill: parent
                radius: root.islandRadius
                elevation: "bar"
                screenX: Theme.barMargin + rightIsland.x
                screenY: Theme.barMargin
            }

            Row {
                id: rightRow
                x: root.islandPad
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.chipGap
            }
        }
    }

    Item {
        id: centreIsland
        // Deliberately without a Behavior. This and the clock's own position
        // inside the row are recomputed from the same layout pass, so they move
        // on the same frame and the clock stays exactly still while the island
        // widens under it. Animating it would make the clock wobble by the
        // difference between two curves.
        x: Math.round(root.width / 2
                      - (root.centreAnchorX >= 0
                         ? root.islandPad + root.centreAnchorX
                         : width / 2))
        y: 0
        width: centreRow.width + root.islandPad * 2
        height: root.height
        visible: centreRow.width > 0

        Reveal {
            anchors.fill: parent
            shown: root.arrived
            delay: Direction.stagger(2)
            slideX: 0

            Surface {
                anchors.fill: parent
                radius: root.islandRadius
                elevation: "bar"
                screenX: Theme.barMargin + centreIsland.x
                screenY: Theme.barMargin
            }

            Row {
                id: centreRow
                x: root.islandPad
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.chipGap
            }
        }
    }
}
