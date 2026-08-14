import QtQuick
import QtQuick.Effects
import Quickshell

// Time and date, set to the rail's measure.
//
// Deliberately unadorned. Two earlier attempts at a glow both showed up as a
// visible rectangle behind the digits: a RectangularShadow draws an actual
// rounded box, and a blurred layer plus MultiEffect leaves a haze the size of
// the layer's texture bounds. The digits carry enough weight on their own —
// what they needed was not decoration but movement, so the places roll rather
// than relabel.
//
// The seconds are gone. They were the largest continuously moving thing on the
// desktop and the least informative thing on it, which is the exact trade
// Direction's rule 6 exists to refuse.
//
// This used to end "and the separator already pulses on the second, so the beat
// they were there for was never theirs to carry", which stopped being true and
// was still the stated reason. `RollClock.blink` is off — off by default and set
// nowhere — because two three-pixel dots breathing cost twenty points of a core:
// any running animation holds its window's render loop at the refresh rate, and
// this window is the size of the screen. `RollClock` carries the measurement.
//
// So nothing on this clock moves below the minute, and the argument is better
// for it rather than weaker. Rule 6 says only what is in focus may move, and a
// clock on the wallpaper is never what anybody is looking at. Caught by
// photographing the colon four times a third of a second apart and finding all
// four identical: the file was describing a pulse that had been deliberately
// removed, and using it to justify the removal of something else.
Item {
    id: root

    // Set by the rail. Everything here is right-aligned to it, because a shared
    // edge is the only thing making these blocks read as one object.
    property int railWidth: 440

    implicitWidth: root.railWidth
    implicitHeight: stack.height

    SystemClock {
        id: clock
        // Minutes, not seconds: nothing here is drawn from the second any more,
        // and a per-second wakeup for a display that cannot change is the kind
        // of idle cost that stays invisible until somebody measures it.
        precision: SystemClock.Minutes
        enabled: true
    }

    // The ground under the type, and only under the type.
    //
    // These are the only things in the shell drawn straight onto the picture,
    // and no ink choice can be right for all of it: a video's brightness was
    // measured from one extracted frame at 0.31 while the frame actually on
    // screen was 0.82, and even a still picture is rarely uniform under the
    // corner it happens to sit in. A scrim does not need to know. It follows
    // the digits rather than the rail because the rail is mostly empty and a
    // dim rectangle over bare wallpaper is a widget with a visible box around
    // it, which is the failure the glow attempts already made twice.
    RectangularShadow {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -10
        anchors.topMargin: -10
        width: Math.max(hhmm.width, dateLine.contentWidth) + 20
        height: stack.height + 20
        radius: Theme.radiusPanel
        blur: 44
        spread: 12
        color: "#000000"
        opacity: Theme.deskScrim
        visible: opacity > 0
        offset: Qt.vector2d(0, 2)
        z: -1
    }

    Column {
        id: stack
        width: parent.width
        spacing: Theme.gapTight

        Item {
            width: parent.width
            height: hhmm.height

            RollClock {
                id: hhmm
                anchors.right: parent.right
                hours: clock.date.getHours()
                minutes: clock.date.getMinutes()
                pixelSize: Theme.fontClock
                weight: Font.Bold
                ink: Theme.deskInk
                tracking: -2
                groupGap: 5
                minuteInk: Theme.deskAccent
            }
        }

        Text {
            id: dateLine
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: Lang.date(clock.date, "dddd, d MMMM").toUpperCase()
            color: Theme.wallpaperIsLight
                ? Qt.darker(Theme.subtext1, 2.2) : Theme.subtext1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLead
            font.letterSpacing: Theme.trackCaption
            opacity: 0.85
        }
    }
}
