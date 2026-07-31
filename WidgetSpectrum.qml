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

    // Kept at a fixed size even when the delegates are gone, so the widget does
    // not collapse under the drag handle the moment the music stops.
    readonly property bool live: Cava.active && Wallpaper.desktopVisible

    readonly property int barWidth: 9
    readonly property int barGap: 5
    readonly property int span: 96

    implicitWidth: Math.max(1, Cava.barCount * root.barWidth + (Cava.barCount - 1) * root.barGap)
    implicitHeight: root.span

    opacity: root.live ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

    Row {
        anchors.centerIn: parent
        spacing: root.barGap

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
                readonly property real floorHeight: 4 + bar.arch * 9

                // Hue walks along the row rather than up each bar. A vertical
                // ramp is invisible on a bar four pixels tall; a horizontal one
                // is legible whatever the music is doing, and it makes the low
                // end and the high end tell themselves apart at a glance.
                readonly property color tint: Qt.tint(
                    Theme.accent,
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
