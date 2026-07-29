import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

// Full-screen wallpaper on the background layer, replacing swaybg so the
// switch can crossfade instead of hard-cutting.
//
// base always shows the settled wallpaper; overlay loads the incoming one on
// top at opacity 0 and fades in. Only once the fade is done AND base has
// re-loaded the same image underneath does overlay drop back to 0 — so there
// is never a frame showing a half-loaded texture or the old wallpaper
// flashing back. Explicit animations (not bound-opacity Behaviors) because
// the flip-flop-two-images approach hard-cut instead of tweening.
//
// Video wallpapers ride on the same machinery: the VideoOutput sits under the
// image pair, and a still frame extracted at set-wallpaper time stands in for
// the crossfade, so switching to a video looks identical to switching images.
PanelWindow {
    id: win

    // One per output; a single instance left a second monitor with no
    // wallpaper at all.
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"
    focusable: false
    // Behind everything, including normal windows — this IS the desktop
    // background now.
    WlrLayershell.layer: WlrLayer.Background
    // Fill the whole output including the strip the bar reserves. exclusive
    // zone -1 tells the compositor to span the full anchored area and ignore
    // other surfaces' zones; 0 would respect them and get shrunk, leaving that
    // strip as niri's grey clear colour under/around the bar islands.
    exclusiveZone: -1
    // Nothing here is clickable, but a full-output surface with no mask claims
    // the whole input region and silently ate every click on bare desktop —
    // which is why menus could not be dismissed by clicking away from them.
    // DesktopLayer handles desktop clicks instead.
    mask: Region {}

    // Publishing this lets the singleton decide whether playback is worth
    // paying for, without it having to know about screens.
    readonly property bool desktopVisible: Niri.desktopVisibleOn(win.modelData.name)
    onDesktopVisibleChanged: Wallpaper.desktopVisible = win.desktopVisible
    Component.onCompleted: Wallpaper.desktopVisible = win.desktopVisible

    // ── Video layer ──
    // Below the images: while a still is crossfading in on top, the video is
    // hidden behind it, which is what makes an image↔video switch look like
    // every other transition.
    MediaPlayer {
        id: player
        source: Wallpaper.isVideo ? Wallpaper.path : ""
        loops: MediaPlayer.Infinite
        // Wallpapers are decoration, never a sound source.
        audioOutput: AudioOutput { muted: true; volume: 0 }
        videoOutput: videoOut

        // Playback is gated rather than the source being cleared: clearing it
        // would force a full re-open, and a visible black frame, every time a
        // window covered the desktop.
        readonly property bool shouldPlay: Wallpaper.isVideo && !Wallpaper.videoPaused
        onShouldPlayChanged: shouldPlay ? play() : pause()
        onSourceChanged: if (shouldPlay) play()
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: Wallpaper.isVideo
    }

    // Decode at output resolution (see FrostedBackground): the native
    // wallpapers are 7680x4320 and two full-size copies here alone were
    // ~260 MB.
    Image {
        id: base
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Screen.width
        sourceSize.height: Screen.height
        cache: false
        asynchronous: true
        transformOrigin: Item.Center
        Component.onCompleted: source = Wallpaper.isVideo ? Wallpaper.stillPath : Wallpaper.path
    }

    Image {
        id: overlay
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Screen.width
        sourceSize.height: Screen.height
        cache: false
        asynchronous: true
        opacity: 0
        transformOrigin: Item.Center
    }

    // Accent burst flashed across the whole screen at the peak of the punch —
    // the single most "wow" beat of the transition, and it reads as the shell
    // reacting to the new palette (which is fading in at the same time).
    Rectangle {
        id: flash
        anchors.fill: parent
        opacity: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.accent, 0.5) }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.blue, 0.35) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.accent, 0.5) }
        }
    }

    // The image the base should adopt once the reveal has finished.
    property string pendingCommit: ""
    // For video the reveal plays against the extracted still, then the still is
    // faded away to expose the live video underneath.
    property bool revealingVideo: false

    Connections {
        target: Wallpaper
        function onPathChanged() {
            win.revealingVideo = Wallpaper.isVideo;
            // Never bind the source: a binding reloads the visible image
            // immediately and kills the fade. Sources are set imperatively.
            overlay.source = Wallpaper.isVideo ? Wallpaper.stillPath : Wallpaper.path;
            // A video with no still frame has nothing to crossfade against, so
            // it comes up directly rather than freezing on the old wallpaper.
            if (Wallpaper.isVideo && Wallpaper.stillPath === "") {
                base.opacity = 0;
                overlay.opacity = 0;
                win.revealingVideo = false;
            }
        }
    }

    // The still is not only a transition device: it is what the desktop shows
    // whenever a video wallpaper is stopped, so pausing reads as a freeze
    // frame rather than as the wallpaper being switched off.
    NumberAnimation {
        id: stillFade
        target: base
        property: "opacity"
        duration: Theme.animNormal
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasized
    }

    Connections {
        target: Wallpaper
        function onVideoPausedChanged() {
            if (!Wallpaper.isVideo || Wallpaper.stillPath === "") return;
            if (win.revealingVideo || reveal.running) return;
            if (base.source != Wallpaper.stillPath) base.source = Wallpaper.stillPath;
            stillFade.to = Wallpaper.videoPaused ? 1 : 0;
            stillFade.restart();
        }
    }

    Connections {
        target: overlay
        function onStatusChanged() {
            if (overlay.status === Image.Ready && overlay.opacity === 0) {
                reveal.restart();
            }
        }
    }

    // The wow transition: the incoming wallpaper punches in from an overscale
    // while the outgoing one sinks back, with an accent flash cresting in the
    // middle. Explicit multi-track animation rather than a single opacity tween.
    ParallelAnimation {
        id: reveal
        onFinished: {
            if (win.revealingVideo) {
                // Only hand over to live video if it is actually running. A
                // video paused before it ever decoded a frame — which is the
                // normal case, since playback is gated on the desktop being
                // visible and a window is usually covering it — leaves
                // VideoOutput with nothing to draw, and the desktop came up
                // black. The extracted still stands in until playback starts.
                if (Wallpaper.videoPaused) {
                    win.pendingCommit = overlay.source;
                    base.source = overlay.source;
                    win.revealingVideo = false;
                    return;
                }
                // The still has done its job; drop both images to reveal the
                // video that has been playing underneath all along.
                stillHandoff.restart();
                return;
            }
            // Commit the settled image into base underneath, then hide the
            // overlay once base has it (handled below) so the swap is unseen.
            win.pendingCommit = overlay.source;
            base.source = overlay.source;
        }

        NumberAnimation {
            target: overlay; property: "opacity"
            from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: overlay; property: "scale"
            from: 1.24; to: 1.0; duration: 900; easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: base; property: "scale"
            from: 1.0; to: 1.09; duration: 900; easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.42; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 520; easing.type: Easing.InQuad }
        }
    }

    // Short cross-dissolve from the frozen still to the live video, so playback
    // doesn't begin with a visible jump.
    ParallelAnimation {
        id: stillHandoff
        onFinished: {
            base.scale = 1.0;
            overlay.scale = 1.24;
            win.revealingVideo = false;
        }
        NumberAnimation { target: overlay; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
        NumberAnimation { target: base; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutQuad }
    }

    Connections {
        target: base
        function onStatusChanged() {
            if (base.status === Image.Ready && win.pendingCommit !== "" && base.source == win.pendingCommit) {
                win.pendingCommit = "";
                overlay.opacity = 0;
                // Reset transforms for the next transition; overlay now hidden
                // and base shows the settled image, so these are invisible.
                base.opacity = 1;
                base.scale = 1.0;
                overlay.scale = 1.24;
            }
        }
    }
}
