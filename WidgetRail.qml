import QtQuick

// The desktop's rail: one composition, not four widgets that happen to be
// stacked.
//
// Measured off a capture of the live desktop, the four independent widgets
// shared no edge, no width and no visual treatment, so the eye had no path down
// them — a composition problem rather than a styling one, and no amount of
// per-widget tuning was going to fix it. They are one object now: one measure,
// one right edge, one vertical rhythm, dragged as a whole.
//
// What that costs is placing the clock and the player in different corners.
// Nothing in the saved preferences was ever doing that — every widget sat at
// x = 1 with a slightly different y, which is this rail drawn by hand and
// slightly out of true.
Column {
    id: root

    // The player card's width, adopted as the rail's measure. Choosing the
    // widest member rather than a new number means nothing has to be sized
    // twice.
    readonly property int railWidth: 440

    // Where the rail sits on its output, so the card's glass can sample the
    // wallpaper under it. Set by the surface, the only thing that knows.
    property real screenX: 0
    property real screenY: 0

    // Exposed so the surface can take input for the transport alone. Masking
    // the whole rail would hand 440x400 of bare desktop to the widget layer and
    // clicks meant for the wallpaper would stop dismissing menus.
    readonly property alias cardItem: card

    width: root.railWidth
    // A rung tighter than the sections it separates, because the band between
    // the clock and the card is 64 tall and mostly air — it holds the space the
    // music will need, and that space already reads as the gap. At section
    // spacing the three blocks stopped looking stacked and started looking
    // scattered again.
    spacing: Theme.gapWide

    WidgetClock {
        railWidth: root.railWidth
    }

    WidgetSpectrum {
        railWidth: root.railWidth
    }

    // Deterministic, because a binding that reads `Media.hasPlayer` directly
    // would drop the card on the frame the player quits and the exit would
    // never play. Same shape as the panels: a flag only ever assigned.
    property bool cardMapped: false
    readonly property bool cardWanted: Media.hasPlayer || DesktopWidgets.editing

    onCardWantedChanged: {
        if (root.cardWanted) {
            cardHide.stop();
            root.cardMapped = true;
        } else {
            cardHide.restart();
        }
    }

    Component.onCompleted: root.cardMapped = root.cardWanted

    Timer {
        id: cardHide
        interval: Theme.animExit
        onTriggered: root.cardMapped = false
    }

    WidgetMedia {
        id: card
        railWidth: root.railWidth
        // The rail is anchored at its top, so a card arriving lengthens the
        // composition downward and moves nothing above it. Space opens on the
        // frame the flag flips and the card fades into it after — Direction's
        // rule 2, for free, because the layout and the opacity are separate
        // events already.
        visible: root.cardMapped
        opacity: root.cardWanted ? 1 : 0

        screenX: root.screenX
        screenY: root.screenY + y

        Behavior on opacity {
            NumberAnimation {
                duration: root.cardWanted ? Theme.animSlow : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.cardWanted ? Theme.easeEmphasized : Theme.easeExit
            }
        }
    }
}
