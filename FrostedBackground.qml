import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Real frosted-glass backing for panels: samples the actual wallpaper at the
// panel's screen position and blurs it, rather than faking depth with a flat
// translucent fill. niri has no backdrop-blur protocol, so the wallpaper is
// re-rendered here and offset by the panel's own screen coords — swaybg draws
// the same image at the same scale, so the alignment is exact and the panel
// reads as genuinely see-through.
//
// Callers must pass their on-screen position (screenX/screenY); a panel that
// gets this wrong looks subtly "off" rather than broken, so it's worth
// keeping in sync with the window's anchors/margins.
ClippingRectangle {
    id: root

    property real screenX: 0
    property real screenY: 0
    // Higher than a typical CSS backdrop-filter — the wallpaper is busy anime
    // art, and anything less lets detail fight the foreground text.
    property real blurAmount: 1.0
    // Low enough that the blurred wallpaper is clearly visible through the
    // panel — past ~0.65 the glass reads as flat dark plastic and the whole
    // effect is wasted.
    property real tintOpacity: 0.52

    color: "transparent"
    radius: Theme.radius

    Item {
        id: wallSource
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Image {
            x: -root.screenX
            y: -root.screenY
            width: Screen.width
            height: Screen.height
            // Same source the wallpaper layer draws, so the blur behind a
            // panel matches what's actually on screen and recolours the
            // instant the wallpaper crossfades. For video wallpapers this
            // resolves to the extracted still frame instead: blurring live
            // video under six panels every vsync would cost real GPU time to
            // produce something already blurred past recognition.
            source: Wallpaper.blurSource
            // Decode at screen resolution, not the wallpaper's native size.
            // The source images are 7680x4320 (~130 MB decoded each); without
            // this cap every FrostedBackground kept a full-size copy and the
            // shell sat at ~600 MB, with a CPU spike each time one decoded.
            // The result is blurred anyway, so there's no visible quality loss.
            sourceSize.width: Screen.width
            sourceSize.height: Screen.height
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: wallSource
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 64
        autoPaddingEnabled: false
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
