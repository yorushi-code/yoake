pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper-derived palette, read from a JSON data file rather than being a
// generated .qml. Two reasons:
//   1. Rewriting a .qml in the config dir triggers a full quickshell reload
//      (every window destroyed and recreated) — a hard visual reset on every
//      wallpaper change. A .json is picked up live by FileView instead.
//   2. Because the values update in place, `Behavior on color` lets the whole
//      DE fade to the new palette in sync with the wallpaper crossfade,
//      rather than snapping.
// Values fall back to the last-shipped palette if the file is missing or
// caught mid-write (JSON.parse throws → we keep what we had).
//
// Two sources, in priority order: a pin the user placed by clicking a swatch,
// then the palette derived from the wallpaper. Both are written by
// ~/.local/bin/wallpaper-palette.py, which drops the pin whenever the
// wallpaper changes — a pin belongs to the image it was chosen against.
Singleton {
    id: root

    // Duration hardcoded rather than pulled from Theme: Theme depends on this
    // singleton, and referencing it back here risks a circular init.
    readonly property int _fade: 500

    property color background: "#16030D"
    property color foreground: "#B3B3B5"
    property color surface0: "#4D3C44"
    property color surface1: "#616063"
    property color surface2: "#747376"
    property color accent: "#A2628B"
    property color accentAlt: "#885577"
    property color blue: "#648096"
    property color yellow: "#CF4C8A"
    property color subtext1: "#98989A"
    property color subtext0: "#818182"

    Behavior on background { ColorAnimation { duration: root._fade } }
    Behavior on foreground { ColorAnimation { duration: root._fade } }
    Behavior on surface0 { ColorAnimation { duration: root._fade } }
    Behavior on surface1 { ColorAnimation { duration: root._fade } }
    Behavior on surface2 { ColorAnimation { duration: root._fade } }
    Behavior on accent { ColorAnimation { duration: root._fade } }
    Behavior on accentAlt { ColorAnimation { duration: root._fade } }
    Behavior on blue { ColorAnimation { duration: root._fade } }
    Behavior on yellow { ColorAnimation { duration: root._fade } }
    Behavior on subtext1 { ColorAnimation { duration: root._fade } }
    Behavior on subtext0 { ColorAnimation { duration: root._fade } }

    // Status colors stay fixed rather than wallpaper-derived: a hue that
    // happens to be absent from one image isn't a reason for a charging
    // indicator to stop reading as "good".
    readonly property color red: "#f38ba8"
    readonly property color green: "#a6e3a1"

    // ── analysis, for the palette picker ──
    // What the extractor measured, so the UI can explain where the colour came
    // from instead of leaving the user to guess — which was the complaint.
    property real hue: 0
    property real chroma: 0
    property real confidence: 0
    // Mean lightness of the wallpaper, 0..1. The palette generator already
    // measures it; nothing read it, so anything drawn straight onto the
    // wallpaper had no way to know whether it was drawing on black or on snow.
    property real meanL: 0.5
    property bool muted: false
    property bool pinned: false
    // [{ hex, hue, chroma }] — candidate accents found in the image.
    property var swatches: []

    readonly property string _keys: "background foreground surface0 surface1 surface2"
        + " accent accentAlt blue yellow subtext1 subtext0"

    // Tracked separately from FileView.loaded, which is already true while an
    // async read is still in flight.
    property bool hasPin: false

    function _apply() {
        // The pin wins outright; it is a full palette, not a patch.
        const text = root.hasPin ? pinFile.text() : colorFile.text();
        let j;
        try {
            j = JSON.parse(text);
        } catch (e) {
            return; // mid-write or malformed — keep current values
        }
        for (const key of root._keys.split(" ")) {
            if (j[key]) root[key] = j[key];
        }
        const meta = j.meta || {};
        root.hue = meta.hue || 0;
        root.chroma = meta.chroma || 0;
        root.confidence = meta.confidence || 0;
        root.meanL = meta.meanL === undefined ? 0.5 : meta.meanL;
        root.muted = meta.muted === true;
        root.pinned = meta.pinned === true;
        root.swatches = meta.swatches || [];
    }

    // ── pinning ──
    property Process pinProc: Process {}

    function pin(hue, chroma) {
        pinProc.command = [Quickshell.env("HOME") + "/.local/bin/wallpaper-palette.py",
                           "--pin", String(hue), String(chroma)];
        pinProc.running = true;
    }

    function unpin() {
        pinProc.command = [Quickshell.env("HOME") + "/.local/bin/wallpaper-palette.py", "--unpin"];
        pinProc.running = true;
    }

    FileView {
        id: colorFile
        // Resolved against the shell's own directory rather than hardcoded, so
        // the config isn't tied to one home directory.
        path: Quickshell.shellPath("generated-colors.json")
        watchChanges: true
        onLoaded: root._apply()
        onFileChanged: reload()
    }

    FileView {
        id: pinFile
        path: Quickshell.shellPath("palette-override.json")
        watchChanges: true
        // Absent most of the time — that is the unpinned state, not an error
        // worth logging on every start.
        printErrors: false
        // Its disappearance is how unpinning takes effect, so both directions
        // have to re-run the apply.
        onLoaded: { root.hasPin = true; root._apply(); }
        onLoadFailed: { root.hasPin = false; root._apply(); }
        onFileChanged: reload()
    }
}
