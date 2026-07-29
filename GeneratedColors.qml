pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallust-derived palette, read from a JSON data file rather than being a
// generated .qml. Two reasons:
//   1. Rewriting a .qml in the config dir triggers a full quickshell reload
//      (every window destroyed and recreated) — a hard visual reset on every
//      wallpaper change. A .json is picked up live by FileView instead.
//   2. Because the values update in place, `Behavior on color` lets the whole
//      DE fade to the new palette in sync with the wallpaper crossfade,
//      rather than snapping.
// Values fall back to the last-shipped palette if the file is missing or
// caught mid-write (JSON.parse throws → we keep what we had).
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

    // Status colors stay fixed rather than wallpaper-derived: color10/color2
    // aren't guaranteed to actually read as green/red for a given image (a
    // charging-battery indicator turning reddish because the wallpaper
    // happens to lack green content would be a real usability regression).
    readonly property color red: "#f38ba8"
    readonly property color green: "#a6e3a1"

    function _apply() {
        let j;
        try {
            j = JSON.parse(colorFile.text());
        } catch (e) {
            return; // mid-write or malformed — keep current values
        }
        if (j.background) root.background = j.background;
        if (j.foreground) root.foreground = j.foreground;
        if (j.surface0) root.surface0 = j.surface0;
        if (j.surface1) root.surface1 = j.surface1;
        if (j.surface2) root.surface2 = j.surface2;
        if (j.accent) root.accent = j.accent;
        if (j.accentAlt) root.accentAlt = j.accentAlt;
        if (j.blue) root.blue = j.blue;
        if (j.yellow) root.yellow = j.yellow;
        if (j.subtext1) root.subtext1 = j.subtext1;
        if (j.subtext0) root.subtext0 = j.subtext0;
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
}
