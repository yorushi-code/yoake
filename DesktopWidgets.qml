pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Where the desktop widgets sit, and whether they can be moved.
//
// Positions are fractions of the free space on their screen, not pixels. A
// pixel position saved on a 1920x1080 laptop puts the clock off the edge of a
// smaller external display and leaves it huddled in a corner of a larger one;
// a fraction lands in the same place relative to the screen either way.
Singleton {
    id: root

    // Edit mode. Widgets are inert until this is on — the desktop should
    // behave like bare wallpaper, not like a board of things to knock over by
    // accident.
    property bool editing: false

    function toggleEditing() {
        root.editing = !root.editing;
    }

    function _key(name, screen) {
        return "widget." + name + "." + screen;
    }

    function positionFor(name, screen, fallbackX, fallbackY) {
        const saved = Prefs.get(root._key(name, screen), null);
        if (!saved) return { x: fallbackX, y: fallbackY };
        return {
            x: Math.max(0, Math.min(1, saved.x)),
            y: Math.max(0, Math.min(1, saved.y))
        };
    }

    function setPosition(name, screen, x, y) {
        Prefs.set(root._key(name, screen), {
            x: Math.round(Math.max(0, Math.min(1, x)) * 10000) / 10000,
            y: Math.round(Math.max(0, Math.min(1, y)) * 10000) / 10000
        });
    }

    // Snap to the edges and the centre line. Eyeballing a widget onto the
    // centre of a screen is impossible by hand, and a widget a few pixels off
    // an edge reads as a mistake rather than a choice.
    readonly property var snapPoints: [0.0, 0.5, 1.0]
    readonly property real snapPx: 26

    function snap(value, span) {
        if (span <= 0) return value;
        for (const point of root.snapPoints) {
            if (Math.abs(value - point) * span < root.snapPx) return point;
        }
        return value;
    }

    property IpcHandler handler: IpcHandler {
        target: "widgets"

        function edit(): void { root.toggleEditing(); }
        function reset(): void { root.resetAll(); }
    }

    readonly property var names: ["clock", "spectrum", "stats", "media"]

    function resetAll() {
        for (const screen of Quickshell.screens) {
            for (const name of root.names) {
                Prefs.set(root._key(name, screen.name), null);
            }
        }
    }
}
