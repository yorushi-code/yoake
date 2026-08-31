pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
// The singletons this reads -- Config, ThemeBackend, Caching -- are declared in
// the root qmldir, which a subdirectory is not part of. Same line as Cava.qml.
import "../"

// The yoake layer's first seam into the base shell.
//
// ThemeBackend is a flat vocabulary of twenty-one Catppuccin-shaped colours
// that every widget in the tree reads by name. That makes it the one place
// worth touching: derive those twenty-one from the wallpaper and the whole
// shell follows, without a single widget knowing a layer exists.
//
// The palette itself comes from scripts/wallpaper-palette.py, which measures
// the wallpaper's dominant hue as a chroma-weighted circular mean in OKLCh and
// synthesizes an accent on it. Matugen is not wrong so much as differently
// opinionated; this one carries a confidence value, so a near-monochrome image
// yields a muted accent rather than an invented one.
//
// It applies through ThemeBackend.applyColorObject() rather than by binding
// over the properties. Binding would fight the assignments that function
// already makes, and losing that fight is silent.
Singleton {
    id: root

    readonly property string _home: Quickshell.env("HOME") ?? ""
    readonly property string _stateDir: (typeof Caching !== "undefined" && Caching.stateDir)
        ? Caching.stateDir
        : (_home + "/.local/state/yoake")

    // Off by one setting, so the base shell can be seen unaltered without
    // editing QML -- which is the only honest way to tell whether a difference
    // came from the layer or from upstream.
    readonly property bool active: {
        const t = Config.getSetting("theme", {});
        return t.yoake !== false;
    }

    // -- what the extractor hands over --
    property color background: "#14121D"
    property color foreground: "#E1E0E7"
    property color surface0: "#292635"
    property color surface1: "#3E3A4B"
    property color surface2: "#534F62"
    property color accent: "#BBA8FF"
    property color accentAlt: "#6979CC"
    property color blue: "#8298EF"
    property color yellow: "#F8AA5F"
    property color subtext1: "#B4B3B9"
    property color subtext0: "#89888C"

    // Status colours stay fixed rather than wallpaper-derived: a hue that
    // happens to be absent from one image is not a reason for a charging
    // indicator to stop reading as good.
    readonly property color red: "#f38ba8"
    readonly property color green: "#a6e3a1"

    readonly property string _keys: "background foreground surface0 surface1 surface2"
        + " accent accentAlt blue yellow subtext1 subtext0"

    property real meanL: 0.5
    property bool muted: false
    property bool pinned: false
    property bool hasPin: false

    // Rotate a colour's hue while keeping how light and how saturated it is.
    // The rare slots are filled this way so they stay relatives of the common
    // ones rather than strangers that happen to sit in the same object.
    function _shift(c, degrees) {
        let h = c.hslHue + degrees / 360.0;
        while (h < 0) h += 1;
        while (h > 1) h -= 1;
        return Qt.hsla(h, c.hslSaturation, c.hslLightness, 1);
    }

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1);
    }

    // Eleven measured colours into twenty-one named ones.
    //
    // The mapping is taken from how the tree actually spends them, not from
    // what they are called. `mauve` is read 269 times across src/ -- it is not
    // "the purple one", it is this shell's accent, so it gets the accent.
    // `red` and `green` are spent on alarm and on health, so they keep the
    // fixed pair. The rare slots each hang off whichever common slot they are
    // a shade of.
    //
    // Note what this deliberately does not attempt: the shell this palette
    // came from had a fixed hue per domain -- network mint, bluetooth rose,
    // vpn violet -- so the eye sorted a chip before reading it. That cannot be
    // ported by filling slots, because here one accent serves every domain.
    // Carrying it across means teaching widgets to ask for a domain instead of
    // a colour, which is a change to widgets, not to a palette.
    function derived() {
        const bg = root.background;
        const fg = root.foreground;
        return {
            "base":     bg,
            "mantle":   Qt.darker(bg, 1.20),
            "crust":    Qt.darker(bg, 1.45),

            "surface0": root.surface0,
            "surface1": root.surface1,
            "surface2": root.surface2,

            // The rungs between the last surface and the quietest ink. Nothing
            // measures these; they are the gap, evenly walked.
            "overlay0": _mix(root.surface2, root.subtext0, 0.33),
            "overlay1": _mix(root.surface2, root.subtext0, 0.66),
            "overlay2": root.subtext0,

            "text":     fg,
            "subtext1": root.subtext1,
            "subtext0": root.subtext0,

            // The shifts are measured off the palette these slots are named
            // after, not guessed: hue of each rare slot minus hue of the
            // common one it is a shade of. Guessing put teal 12 degrees off
            // green instead of 55, which made the VPN chip and the battery
            // chip the same colour on the bar, and had sapphire and maroon
            // rotating the wrong way entirely.
            "mauve":    root.accent,
            "pink":     _shift(root.accent, 49),
            "blue":     root.blue,
            "sapphire": _shift(root.blue, -19),
            "teal":     _shift(root.green, 55),
            "green":    root.green,
            "yellow":   root.yellow,
            "peach":    _shift(root.yellow, -18),
            "red":      root.red,
            "maroon":   _shift(root.red, 7)
        };
    }

    readonly property string _scriptsDir: (typeof Caching !== "undefined" && Caching.yoakeDir)
        ? Caching.yoakeDir + "/scripts" : ""

    property Process _gen: Process {}

    // Перемерить обои. Вызывается из Matugen.generate(), потому что туда уже
    // приходят все, кто меняет картинку -- и подборщик обоев, и вкладка темы.
    // Результат ложится в generated-colors.json, а его слушает FileView ниже,
    // так что перекраска случается сама.
    function regenerate(imagePath) {
        if (!root.active || root._scriptsDir === "") return false;
        const clean = imagePath.startsWith("file://") ? imagePath.substring(7) : imagePath;
        _gen.command = [root._scriptsDir + "/wallpaper-palette.py", clean];
        _gen.running = true;
        return true;
    }

    function apply() {
        if (!root.active) return;
        if (typeof ThemeBackend === "undefined") return;
        ThemeBackend.applyColorObject(root.derived());
    }

    function _read() {
        // The pin wins outright; it is a whole palette, not a patch.
        const txt = root.hasPin ? pinFile.text() : colorFile.text();
        let j;
        try {
            j = JSON.parse(txt);
        } catch (e) {
            return; // caught mid-write, or malformed -- keep what we had
        }
        for (const key of root._keys.split(" ")) {
            if (j[key]) root[key] = j[key];
        }
        const meta = j.meta || {};
        root.meanL = meta.meanL === undefined ? 0.5 : meta.meanL;
        root.muted = meta.muted === true;
        root.pinned = meta.pinned === true;
        root.apply();
    }

    FileView {
        id: colorFile
        path: root._stateDir + "/generated-colors.json"
        watchChanges: true
        // Absent until the wallpaper has been through the extractor once,
        // which is an ordinary first-run state, not a fault.
        printErrors: false
        onLoaded: root._read()
        onFileChanged: reload()
    }

    FileView {
        id: pinFile
        path: root._stateDir + "/palette-override.json"
        watchChanges: true
        printErrors: false
        // Its disappearance is how unpinning takes effect, so both directions
        // have to re-run the read.
        onLoaded: { root.hasPin = true; root._read(); }
        onLoadFailed: { root.hasPin = false; root._read(); }
        onFileChanged: reload()
    }

    // A preset switch or a settings reload runs ThemeBackend.updateColors(),
    // which can assign over what we put there. Re-apply after it settles.
    Connections {
        target: typeof Config !== "undefined" ? Config : null
        ignoreUnknownSignals: true
        function onSettingsLoaded() { reapply.restart() }
    }

    Timer {
        id: reapply
        interval: 60
        onTriggered: root.apply()
    }

    Component.onCompleted: root.apply()
}
