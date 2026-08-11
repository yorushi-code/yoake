import QtQuick
import Quickshell.Widgets

// Album art as a record.
//
// A square cover is a file. A disc with a hole in it, turning while the music
// plays and stopping when it does not, is a *player* -- and it answers "is this
// actually playing" from across the room without anyone reading a glyph.
//
// The rotation is a permanently running animation, which this shell otherwise
// forbids. It is allowed here for the reason the doctrine gives: it is not
// decoration, it is a report on something that is happening, and it stops the
// moment that thing stops.
Item {
    id: root

    property string source: ""
    property bool spinning: false
    property color ring: Theme.accent
    // The spindle, as a fraction of the disc. Too small and it reads as a
    // smudge; too large and the art has nothing left of it.
    property real holeRatio: 0.13

    implicitWidth: 190
    implicitHeight: 190

    Glow {
        anchors.fill: parent
        radius: width / 2
        tint: root.ring
        reach: 28
        amount: Theme.veilSoft
    }

    ClippingRectangle {
        id: disc
        anchors.fill: parent
        radius: width / 2
        color: Theme.surface0
        border.width: 2
        border.color: root.ring

        // What a record looks like with no sleeve. Drawn rather than left
        // blank: an empty circle reads as art that failed to load, and this
        // happens routinely -- a browser playing a stream often reports no
        // artwork at all.
        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.source === "" || art.status !== Image.Ready
            icon: Glyphs.music
            size: Theme.fontIconHero
            color: Qt.alpha(Theme.text, Theme.inkGhost)
        }

        Image {
            id: art
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 400

            RotationAnimator on rotation {
                running: root.spinning && root.visible
                loops: Animation.Infinite
                from: 0
                to: 360
                // A record turns slowly. At anything quicker the art becomes a
                // texture and the whole point of showing the cover is lost.
                duration: Theme.animDoze * 4
            }
        }
    }

    // The spindle. Hidden when there is no sleeve, because it is a detail *of*
    // a sleeve -- drawn over the empty-state glyph it punched a dark dot
    // through the middle of it and the two together read as neither.
    Rectangle {
        anchors.centerIn: parent
        visible: root.source !== ""
        width: root.width * root.holeRatio
        height: width
        radius: width / 2
        color: Theme.crust
    }
}
