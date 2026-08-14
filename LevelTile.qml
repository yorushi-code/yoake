import QtQuick
import Quickshell.Widgets

// A quantity, as a square with liquid in it and the number on the waterline.
//
// The number is drawn twice: once in the panel's ink, and once in the ink that
// belongs *on* the liquid, with the second copy clipped to the liquid itself.
// The digit is therefore dark below the surface and light above it, and the
// waterline crosses it. That is the detail that makes the tile read as a
// physical gauge rather than as a percentage in a box -- and it costs a second
// Text and a clip.
ClippingRectangle {
    id: root

    property real value: 0
    property string tone: "audio"
    property bool active: false
    property real pixelSize: Theme.fontHeadline
    // Shown instead of the percentage when there is nothing to show a level
    // for -- a muted sink, a missing battery.
    property string overrideLabel: ""

    implicitWidth: 96
    implicitHeight: 96
    radius: Theme.radiusRow
    color: Qt.alpha(Theme.text, Theme.fillSubtle)

    readonly property string caption: root.overrideLabel !== ""
        ? root.overrideLabel
        : Math.round(root.value * 100) + "%"

    // Above the liquid: the copy that shows wherever the tank is empty.
    Text {
        anchors.centerIn: parent
        text: root.caption
        color: Theme.text
        font.family: Theme.fontMonoFamily
        font.pixelSize: root.pixelSize
        font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
    }

    Liquid {
        id: tank
        anchors.fill: parent
        value: root.value
        tint: Theme.tone(root.tone)
        active: root.active

        // Below the surface. Clipped by the Liquid it lives in, so it appears
        // exactly as far as the liquid has risen.
        Text {
            // Positioned against the tile rather than the tank so the two
            // copies sit on the same baseline to the pixel; a half-pixel of
            // disagreement here reads as a double-struck digit.
            x: Math.round((root.width - implicitWidth) / 2)
            y: Math.round((root.height - implicitHeight) / 2)
            text: root.caption
            color: Theme.onTone(root.tone)
            font.family: Theme.fontMonoFamily
            font.pixelSize: root.pixelSize
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }
}
