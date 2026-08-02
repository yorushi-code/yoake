import QtQuick
import Quickshell.Widgets

// Album art with graceful degradation, shared by the media OSD and the
// desktop card. Players are unreliable about `mpris:artUrl` — Firefox omits
// it for most tracks and sometimes hands over a URL that fails to load — so
// every state has to look deliberate rather than leaving an empty hole.
ClippingRectangle {
    id: root

    property int size: 60
    property int glyphSize: Math.round(size * 0.4)

    width: size
    height: size
    radius: Math.round(size * 0.27)
    color: Qt.alpha(Theme.text, 0.08)

    Image {
        id: art
        anchors.fill: parent
        source: Media.cover
        fillMode: Image.PreserveAspectCrop
        // Cap decode size — cover art is displayed small, and this bounds the
        // per-image cost when tracks are switched rapidly.
        // 128 was sized for the 52px lock-screen slot alone; the same
        // component is used at larger sizes elsewhere.
        sourceSize.width: 256
        sourceSize.height: 256
        asynchronous: true
        // Qt 6.8+: holds the previous frame on screen while the next URL
        // loads, instead of blanking for the duration of the fetch. This is
        // what stops the art flickering on every track change.
        retainWhileLoading: true
    }

    Text {
        anchors.centerIn: parent
        // Only when there is genuinely nothing to draw. Deliberately not
        // shown for Loading: the retained previous frame is still up, and
        // covering it with the placeholder would reintroduce the flicker.
        // Error matters as much as Null here — a URL that fails to load used
        // to leave a blank square with no indication anything was wrong.
        visible: art.status === Image.Null || art.status === Image.Error
        text: Glyphs.music
        font.family: "Symbols Nerd Font"
        font.pixelSize: root.glyphSize
        color: Theme.subtext0
    }
}
