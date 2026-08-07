import QtQuick
import Quickshell.Widgets

// One card on the dashboard.
//
// Every block of content sits on one of these, so the dashboard is a grid of a
// single object rather than a collection of panels that happen to look alike.
// The whole point of a card here is that it is quiet: a low fill, no border, no
// shadow. Depth is already carried by the sheet the cards sit on — repeating it
// per card is what turns a dashboard into a pile of boxes.
//
// The root is an Item with the clipped rectangle inside it, rather than being
// the rectangle. That was done to silence "Member data ... overrides a member
// of the base object", and it does not: a config containing nothing but a bare
// ClippingRectangle logs the same line, so it comes from Quickshell's own type
// declaration and no arrangement here can remove it. The shape stays as it is
// because it reads no worse, not because it fixed anything.
Item {
    id: root

    // An optional eyebrow across the top of the card.
    property string title: ""
    // Cards that are their own control surface light up on hover; static ones
    // (a calendar, a readout) do not, because nothing happens if you click.
    property bool interactive: false

    // Where this card sits in the reveal, and whether the reveal has been
    // triggered. A dashboard whose cards all appear on the same frame reads as
    // a screenshot being shown; one that builds itself in order reads as a
    // thing assembling, and the eye follows the order it is given.
    property int order: 0
    property bool revealed: true

    signal activated()

    // Content starts below the eyebrow when there is one, so children can
    // simply fill this and never think about it.
    default property alias content: body.data

    // The arrival is Reveal's now, and it is a sequence rather than the single
    // opacity-and-slide this file used to spell out. The card's room is made,
    // then the fill arrives, then the eyebrow lights, then the body fills in --
    // which is the difference between a dashboard that appears and one that
    // assembles. Everything that was hand-timed here (two SequentialAnimations,
    // Theme.animSlow twice, an 18px offset) is gone; the only thing this file
    // still says about time is where the card sits in the cascade.
    //
    // Reveal is anchored rather than filled, because a Behavior on this item's
    // own geometry would fight the anchors that place the card in the grid --
    // which is what the Translate below it was working around.
    Reveal {
        id: reveal
        anchors.fill: parent
        shown: root.revealed
        surfaceType: "narrative"
        delay: Direction.stagger(root.order)
        slideY: 18

        // The same object every raised thing in the shell is made of, at the
        // one elevation that does not cast a shadow: the sheet these sit on
        // already carries the depth, and repeating it per card is what turns a
        // dashboard into a pile of boxes. What the cards do gain is the lit top
        // edge, so they belong to the same family as the islands and the panels.
        Surface {
            id: card
            anchors.fill: parent
            radius: Theme.radiusCard
            elevation: "flat"
            glass: false
            fill: root.interactive && area.containsMouse
                ? Qt.alpha(Theme.text, Theme.fillHover)
                : Qt.alpha(Theme.text, Theme.fillSubtle)
            Behavior on fill { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: eyebrow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 14
                anchors.leftMargin: 16
                visible: root.title !== ""
                text: root.title.toUpperCase()
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackLabel
                // The card's accent beat, and the reason the fourth beat is
                // exposed rather than applied: Reveal cannot know which child
                // carries the emphasis, and on a card it is the eyebrow that
                // says what you are looking at.
                opacity: reveal.accentProgress
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.topMargin: root.title !== "" ? 36 : 0
            }

            MouseArea {
                id: area
                anchors.fill: parent
                enabled: root.interactive
                hoverEnabled: root.interactive
                cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton
                onClicked: root.activated()
                z: -1
            }
        }
    }
}
