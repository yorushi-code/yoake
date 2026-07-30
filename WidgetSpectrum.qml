import QtQuick
import QtQuick.Effects

// Audio spectrum, mirrored around the vertical centre so the shape reads as a
// waveform rather than a bar chart.
Row {
    id: root

    // Kept at a fixed size even when the delegates are gone, so the widget does
    // not collapse under the drag handle the moment the music stops.
    readonly property bool live: Cava.active && Wallpaper.desktopVisible

    width: Math.max(1, Cava.barCount * 7 + (Cava.barCount - 1) * 4)
    height: 76
    spacing: 4

    opacity: root.live ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

    Repeater {
        // Zero rows, not just an invisible Row: occlusion does not stop Qt from
        // re-evaluating bindings, so twenty-eight delegates kept recomputing
        // their heights off every cava frame behind an opaque window — about
        // half the shell's idle CPU, spent on something nobody could see.
        // Dropping the delegates is what actually stops the work.
        model: root.live ? Cava.barCount : 0

        delegate: Item {
            required property int index
            readonly property real level: Cava.values[index] || 0
            readonly property real peak: Cava.peaks[index] || 0
            width: 7
            height: 76

            // Glow scales with the band's own level, so loud bands bloom and
            // quiet ones stay clean. Gated on being visible at all: below this
            // the glow is under 0.17 opacity and indistinguishable from
            // nothing, but all 28 were still drawn every frame.
            RectangularShadow {
                anchors.fill: barRect
                radius: barRect.radius
                visible: level > 0.25
                color: Theme.accent
                blur: 18
                spread: 1
                opacity: level * 0.7
                offset: Qt.vector2d(0, 0)
            }

            Rectangle {
                id: barRect
                width: parent.width
                height: Math.max(4, level * 76)
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accent }
                    GradientStop { position: 1.0; color: Theme.blue }
                }
                opacity: 0.5 + level * 0.5
                // See BarMedia: the fall is smoothed in Cava now.
            }

            // Peak-hold: a transient that would be gone by the next frame
            // leaves a marker that sinks back down, which is what makes a fast
            // track read as loud rather than just busy.
            Rectangle {
                width: parent.width
                height: 2
                radius: 1
                color: Theme.text
                opacity: peak > level + 0.04 ? 0.8 : 0
                y: (parent.height - Math.max(4, peak * 76)) / 2
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }
        }
    }
}
