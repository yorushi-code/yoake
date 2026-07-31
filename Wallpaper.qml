pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Current wallpaper, shared by the wallpaper layer and every panel's frosted
// glass so they all sample the same image and crossfade together.
//
// The path is read from a tiny trigger file rather than the current-wallpaper
// symlink directly: the symlink's *path* never changes (only its target), so
// binding an Image to it would never reload. set-wallpaper.sh writes the
// resolved path here, and swapping that string is what drives the crossfade.
Singleton {
    id: root

    // Empty until the trigger file is read. It used to default to the
    // current-wallpaper symlink, which has no extension — so isVideo was false
    // for it and every panel tried to decode an mp4 as an image on the first
    // frame after a video wallpaper was set.
    property string path: ""

    readonly property var videoExtensions: ["mp4", "mkv", "webm", "mov", "m4v", "avi"]
    readonly property bool isVideo: {
        const clean = root.path.split("?")[0];
        const dot = clean.lastIndexOf(".");
        if (dot < 0) return false;
        return root.videoExtensions.indexOf(clean.slice(dot + 1).toLowerCase()) >= 0;
    }

    // A still frame extracted from the video by set-wallpaper.sh. The frosted
    // glass under every panel samples this instead of the live video: blurring
    // a moving frame under six surfaces every vsync costs a great deal of GPU
    // for something that is, by definition, blurred past recognition.
    property string stillPath: ""

    // The frosted glass under every panel samples this. It is blurred once, on
    // disk, by set-wallpaper.sh: doing it on the GPU meant one offscreen render
    // target and one multi-pass blur per panel, about twenty of each, all
    // producing the same image that only changes when the wallpaper does.
    property string blurPath: ""

    // Falls back to the sharp image so a shell started before the blur exists
    // (first run after this change, or a hand-edited trigger file) still draws
    // something rather than empty panels.
    readonly property string blurSource: root.blurPath !== ""
        ? root.blurPath
        : ((root.isVideo && root.stillPath !== "") ? root.stillPath : root.path)

    // What the player opens, as opposed to what the user picked. set-wallpaper
    // caps a video's frame rate to what the screen and the CPU budget can
    // carry, and `path` stays the source so the picker still highlights the
    // file that was chosen.
    property string playPath: ""
    readonly property string playSource: root.playPath !== "" ? root.playPath : root.path

    // ── Video playback policy ──
    property bool pauseOnBattery: true

    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery
        && UPower.displayDevice.state === UPowerDeviceState.Discharging

    readonly property bool batteryPaused: root.pauseOnBattery && root.onBattery

    // Set while the wallpaper picker is previewing a video. Its preview is a
    // second decoder for a second full-screen video, running on top of the one
    // underneath it -- and the desktop's copy is completely hidden behind the
    // picker anyway. Two decoders at once is what made the wallpaper stutter
    // exactly while somebody was choosing one.
    property bool previewingVideo: false

    // Which outputs are certainly covered, by name. A map rather than one bool
    // because there is one WallpaperView per screen and they all used to assign
    // to the same flag: on two monitors the last one to change decided for
    // both, so covering one screen froze the wallpaper on the other.
    //
    // Each view still makes its own playback decision; this exists so the
    // control centre and the desktop widgets can ask about the whole desk
    // without reaching into a per-screen window.
    property var occluded: ({})

    function setOccluded(output, value) {
        if (root.occluded[output] === value) return;
        const next = Object.assign({}, root.occluded);
        next[output] = value;
        root.occluded = next;
    }

    readonly property bool desktopVisible: {
        const names = Object.keys(root.occluded);
        if (names.length === 0) return true;
        for (const name of names) {
            if (!root.occluded[name]) return true;
        }
        return false;
    }

    // Reported, not obeyed: what actually gates a player is the state of the
    // screen it is drawn on. This is the summary the control centre shows.
    readonly property bool videoPaused: !root.desktopVisible || root.batteryPaused
        || root.previewingVideo

    FileView {
        id: trigger
        path: Quickshell.env("HOME") + "/.config/quickshell/.wallpaper-path"
        watchChanges: true
        onLoaded: {
            // Line 1 is the wallpaper; line 2, for video, is the still frame
            // set-wallpaper.sh extracted for the palette; line 3 the pre-blurred
            // copy the panels sample.
            const lines = trigger.text().trim().split("\n");
            const p = (lines[0] || "").trim();
            const still = (lines[1] || "").trim();
            const blur = (lines[2] || "").trim();
            const play = (lines[3] || "").trim();
            root.playPath = play !== "" ? "file://" + play : "";
            // The still is assigned first on purpose: blurSource falls back to
            // `path` while stillPath is empty, so setting path first hands every
            // panel's Image the raw video file for one evaluation and each logs
            // an "unsupported image format" decode error before correcting.
            root.stillPath = still !== "" ? "file://" + still : "";
            // Cache-busted: the path is constant across wallpaper changes, so
            // without this the panels keep showing the previous blur.
            root.blurPath = blur !== ""
                ? "file://" + blur + "?v=" + Date.now()
                : "";
            if (p !== "") root.path = "file://" + p;
        }
        onFileChanged: reload()
        // Only reachable if the trigger file was never written; the symlink is
        // the one thing guaranteed to exist, extension or not.
        onLoadFailed: if (root.path === "") {
            root.path = "file://" + Quickshell.env("HOME") + "/.config/current-wallpaper";
        }
    }
}
