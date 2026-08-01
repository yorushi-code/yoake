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

    // Decided per screen and published, rather than read back from a shared
    // flag: there is one of these windows per output, and they all used to
    // write the same singleton property, so covering one monitor stopped the
    // wallpaper on the other.
    readonly property bool occluded: Niri.desktopOccludedOn(win.modelData.name)
    onOccludedChanged: Wallpaper.setOccluded(win.modelData.name, win.occluded)
    Component.onCompleted: Wallpaper.setOccluded(win.modelData.name, win.occluded)
    Component.onDestruction: Wallpaper.forgetOccluded(win.modelData.name)

    // ── Video layer ──
    // Below the images: while a still is crossfading in on top, the video is
    // hidden behind it, which is what makes an image↔video switch look like
    // every other transition.
    MediaPlayer {
        id: player
        source: Wallpaper.isVideo ? Wallpaper.playSource : ""
        loops: MediaPlayer.Infinite
        // No audioOutput at all, rather than a muted one. A muted sink still
        // opens the stream: Qt kept a QFFmpeg audio renderer thread and a
        // PipeWire data loop running to produce silence, which measured 3.0
        // points of a core for a wallpaper that is decoration by definition.
        videoOutput: videoOut

        // Playback is gated rather than the source being cleared: clearing it
        // would force a full re-open, and a visible black frame, every time a
        // window covered the desktop.
        //
        // Pausing is deliberately invisible. VideoOutput keeps the last decoded
        // frame, so a pause behind a fullscreen window changes nothing anyone
        // can see, and coming back does not jump.
        readonly property bool shouldPlay: Wallpaper.isVideo && !win.occluded
            && !Wallpaper.batteryPaused && !Wallpaper.previewingVideo
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

    // The still stops standing in for the video the moment the video has
    // something of its own to show. Watched rather than assumed: playback is
    // gated on the screen being visible, so a video wallpaper set while a
    // fullscreen window is up decodes nothing at all, and dropping the still
    // then would leave a black desktop until the window closed.
    //
    // There used to be the mirror of this — a cross-fade back to the still
    // whenever playback paused. That was the freeze: the still is the frame one
    // second into the video, so every time a window covered the desktop the
    // visible strip of wallpaper jumped to a different frame and stopped, and
    // every time one closed it jumped back. Pausing now changes nothing on
    // screen at all.
    Connections {
        target: player
        function onPositionChanged() {
            if (!Wallpaper.isVideo || player.position <= 0) return;
            if (win.revealingVideo || reveal.running || stillHandoff.running) return;
            if (base.opacity === 0 && overlay.opacity === 0) return;
            stillHandoff.restart();
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
                // video paused before it ever decoded a frame — which happens
                // whenever the wallpaper is set behind a fullscreen window —
                // leaves VideoOutput with nothing to draw, and the desktop came
                // up black. The extracted still stands in until playback
                // starts, and the position watcher above hands over then.
                if (!player.shouldPlay) {
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

    // A reveal that never starts is a wallpaper that never moves.
    //
    // Every exit from `revealingVideo` runs inside some animation's onFinished,
    // and an animation that was never started has no onFinished to run -- which
    // is precisely how the still of the previous video ended up sitting on top
    // of the new one for good. The cache-busted still path fixes the cause;
    // this makes the state machine unable to hang whatever else goes wrong with
    // it, by asking once a second whether the video is plainly playing while a
    // still is still covering it.
    Timer {
        interval: 1000
        repeat: true
        running: win.revealingVideo && Wallpaper.isVideo
        onTriggered: {
            if (reveal.running || stillHandoff.running) return;
            if (!player.shouldPlay || player.position <= 0) return;
            stillHandoff.restart();
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
