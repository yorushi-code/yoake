import QtQuick
import QtQuick.Effects

// Audio spectrum, mirrored around the vertical centre so the shape reads as a
// waveform rather than a bar chart.
//
// It sat on a flat four-pixel floor, which meant that between two loud passages
// it collapsed into a dotted line across the wallpaper — the thing on screen
// stopped looking like an instrument at rest and started looking like a
// rendering fault. The floor is an arc now: at silence the row still has a
// shape, and the shape is the one the music will grow out of.
Item {
    id: root

    // Drawn whenever the desktop is, sounding or not.
    //
    // It used to fade out with the audio, which left a 64px hole between the
    // clock and the player every time the music stopped — the rail's one
    // connective element, absent exactly as often as it was present. The floor
    // arc below was written to be the shape at rest and had never once been
    // seen. Now it is the rest state: a dotted rule tying the two blocks
    // together, that the music grows out of and settles back into.
    //
    // Costs nothing while silent. Cava stops publishing, so every delegate's
    // level binding holds its last value and is never re-evaluated; what the
    // old gate was really buying was dropping the delegates while the desktop
    // is covered, and that half is kept.
    readonly property bool live: Wallpaper.desktopVisible
    readonly property bool sounding: Cava.active && root.live

    // Set to the rail's measure. Sized to fill it rather than to its own idea
    // of a bar width: this band is what ties the time block to the player, and
    // a row that stops short of both their edges ties nothing to anything.
    property int railWidth: 440

    readonly property int barGap: 5
    // Integral, so the pills never land on a half pixel and shimmer; the
    // remainder goes into the spacing instead, where a fraction is invisible.
    readonly property int barWidth: Math.max(2, Math.floor(
        (root.railWidth - (Cava.barCount - 1) * root.barGap) / Cava.barCount))
    readonly property real fillGap: Cava.barCount > 1
        ? (root.railWidth - Cava.barCount * root.barWidth) / (Cava.barCount - 1)
        : 0
    // A band rather than a block: at the full 96 it competed with the clock for
    // the eye, and the rail only has one hero.
    readonly property int span: 64

    implicitWidth: root.railWidth
    implicitHeight: root.span

    // At rest the band pulls back rather than leaving: still there, plainly not
    // the thing to look at.
    opacity: root.live ? (root.sounding ? 1 : 0.5) : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasized
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.fillGap

        Repeater {
            // Zero rows, not just an invisible Row: occlusion does not stop Qt
            // from re-evaluating bindings, so twenty-eight delegates kept
            // recomputing their heights off every cava frame behind an opaque
            // window — about half the shell's idle CPU, spent on something
            // nobody could see. Dropping the delegates is what actually stops
            // the work.
            model: root.live ? Cava.barCount : 0

            delegate: Item {
                id: bar
                required property int index

                readonly property real level: Cava.values[index] || 0
                readonly property real peak: Cava.peaks[index] || 0
                // 0 at the ends, 1 in the middle.
                readonly property real arch:
                    Math.sin(Math.PI * (bar.index + 0.5) / Cava.barCount)
                // Never below the bar's own width, so a resting band is a row
                // of round dots rather than a row of clipped slots — at 4px
                // tall under a 10px radius the pill stops reading as a shape
                // and starts reading as a rendering fault, which is the same
                // complaint the arc was introduced to answer.
                readonly property real floorHeight:
                    Math.max(root.barWidth, 4 + bar.arch * 12)

                // Hue walks along the row rather than up each bar. A vertical
                // ramp is invisible on a bar four pixels tall; a horizontal one
                // is legible whatever the music is doing, and it makes the low
                // end and the high end tell themselves apart at a glance.
                readonly property color tint: Qt.tint(
                    Theme.deskAccent,
                    Qt.alpha(Theme.blue, (bar.index + 0.5) / Cava.barCount))

                width: root.barWidth
                height: root.span

                // Glow scales with the band's own level, so loud bands bloom and
                // quiet ones stay clean. Gated on being visible at all: below
                // this the glow is under 0.17 opacity and indistinguishable from
                // nothing, but all 28 were still drawn every frame.
                RectangularShadow {
                    anchors.fill: barRect
                    radius: barRect.radius
                    visible: bar.level > 0.25
                    color: bar.tint
                    blur: 20
                    spread: 1
                    opacity: bar.level * 0.75
                    offset: Qt.vector2d(0, 0)
                }

                Rectangle {
                    id: barRect
                    width: parent.width
                    height: Math.max(bar.floorHeight, bar.level * root.span)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: bar.tint
                    // Brightens as it grows, so the loud bands are lighter as
                    // well as taller and the shape survives a busy wallpaper.
                    opacity: 0.55 + bar.level * 0.45
                    // See BarMedia: the fall is smoothed in Cava now.
                }

                // Peak-hold: a transient that would be gone by the next frame
                // leaves a marker that sinks back down, which is what makes a
                // fast track read as loud rather than just busy.
                //
                // In the band's own colour, not white. A white dash hanging in
                // the air above a short bar reads as debris on the wallpaper;
                // the same mark in the same hue reads as part of the bar it
                // came off.
                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: bar.tint
                    opacity: bar.peak > bar.level + 0.04 ? 0.7 : 0
                    y: (parent.height - Math.max(bar.floorHeight, bar.peak * root.span)) / 2
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }
            }
        }
    }
}
