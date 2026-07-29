import QtQuick
import Quickshell.Widgets

// Real frosted-glass backing for panels: samples the actual wallpaper at the
// panel's screen position, rather than faking depth with a flat translucent
// fill. niri has no backdrop-blur protocol, so the wallpaper is re-drawn here
// and offset by the panel's own screen coords — the wallpaper layer draws the
// same image at the same scale, so the alignment is exact and the panel reads
// as genuinely see-through.
//
// The blur itself is not done here. It used to be: an Item with layer.enabled
// (one offscreen render target) feeding a MultiEffect at blurMax 64 (a
// multi-pass downsample/upsample chain), per panel, about twenty of them — all
// computing the same image, which only ever changes when the wallpaper does.
// set-wallpaper.sh now blurs once to disk and this became four plain draws
// over one small shared texture.
//
// Callers must pass their on-screen position (screenX/screenY); a panel that
// gets this wrong looks subtly "off" rather than broken, so it's worth
// keeping in sync with the window's anchors/margins.
ClippingRectangle {
    id: root

    property real screenX: 0
    property real screenY: 0
    // Low enough that the blurred wallpaper is clearly visible through the
    // panel — past ~0.65 the glass reads as flat dark plastic and the whole
    // effect is wasted.
    property real tintOpacity: 0.52

    color: "transparent"
    radius: Theme.radius

    Image {
        x: -root.screenX
        y: -root.screenY
        width: Screen.width
        height: Screen.height
        // Already blurred, and small: one texture shared by every panel via the
        // pixmap cache, since they all name the same source at the same size.
        source: Wallpaper.blurSource
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        // Upscaling a 512px blur is itself a smooth, which is what lets the
        // stored copy be this small without a visible quality difference.
        smooth: true
    }

    // Tint keeps contrast usable over bright wallpaper regions; the accent
    // gradient on top is what stops the glass from reading as plain grey.
    Rectangle {
        anchors.fill: parent
        color: Theme.mantle
        opacity: root.tintOpacity
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, 0.20) }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.accent, 0.05) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.blue, 0.10) }
        }
    }

    // Hairline top highlight — the cue that sells "pane of glass" rather than
    // "blurred rectangle", since real glass catches light on its top edge.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.radius * 0.6
        height: 1
        color: Qt.alpha(Theme.text, 0.10)
    }
}
