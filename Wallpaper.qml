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

    property string path: "file://" + Quickshell.env("HOME") + "/.config/current-wallpaper"

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

    // What panels should blur — the video's still frame, or the image itself.
    readonly property string blurSource: (root.isVideo && root.stillPath !== "")
        ? root.stillPath
        : root.path

    // ── Video playback policy ──
    property bool pauseOnBattery: true
    // Set by WallpaperView from Niri.desktopVisibleOn(); kept here so the
    // control centre can report the state without reaching into a per-screen
    // window.
    property bool desktopVisible: true

    readonly property bool onBattery: UPower.displayDevice.isLaptopBattery
        && UPower.displayDevice.state === UPowerDeviceState.Discharging

    // Playback stops whenever nobody can see it: niri is a scrolling tiler, so
    // any window on the active workspace covers the background layer
    // completely. Decoding video behind an opaque window is the single biggest
    // cost this feature could add for no benefit at all.
    readonly property bool videoPaused: !root.desktopVisible
        || (root.pauseOnBattery && root.onBattery)

    FileView {
        id: trigger
        path: Quickshell.env("HOME") + "/.config/quickshell/.wallpaper-path"
        watchChanges: true
        onLoaded: {
            // Line 1 is the wallpaper; line 2, for video, is the still frame
            // set-wallpaper.sh extracted for the palette and the panel blur.
            const lines = trigger.text().trim().split("\n");
            const p = (lines[0] || "").trim();
            const still = (lines[1] || "").trim();
            // The still is assigned first on purpose: blurSource falls back to
            // `path` while stillPath is empty, so setting path first hands every
            // panel's Image the raw video file for one evaluation and each logs
            // an "unsupported image format" decode error before correcting.
            root.stillPath = still !== "" ? "file://" + still : "";
            if (p !== "") root.path = "file://" + p;
        }
        onFileChanged: reload()
    }
}
