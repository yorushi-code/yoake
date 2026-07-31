pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The greeter's colours and type.
//
// A trimmed copy of the session's Theme rather than an import of it: the
// greeter runs as its own unprivileged user and the home directory it would
// have to read is 700. What it gets instead is a snapshot, written to
// /var/lib/yshell-greeter by yshell-greeter-sync whenever the wallpaper
// changes, so the login screen keeps wearing the same palette as the desktop
// without ever reading the desktop's files.
//
// The literals below are the fallback for a machine where that snapshot has
// never been taken. They are what the greeter looks like on a fresh install,
// not a second source of truth.
Singleton {
    id: root

    readonly property string assetDir: "/var/lib/yshell-greeter"

    property color background: "#16131E"
    property color foreground: "#E2E1E8"
    property color subtext1: "#B5B4BA"
    property color subtext0: "#8A898D"
    property color accent: "#BBA8FF"
    property color red: "#F38BA8"

    readonly property color crust: Qt.darker(root.background, 1.15)
    readonly property color text: root.foreground

    readonly property string fontFamily: "Inter"
    readonly property string fontDisplayFamily: "Inter Display"
    readonly property string fontIconFamily: "Symbols Nerd Font"

    readonly property int fontLabel: 10
    readonly property int fontSmall: 11
    readonly property int fontBody: 12
    readonly property int fontLead: 13
    readonly property int fontTitle: 15

    readonly property int animFast: 120
    readonly property int animNormal: 220

    // Matches Theme.easeSpring: the digit overshoots a little and settles.
    readonly property var easeSpring: [0.34, 1.70, 0.60, 1.0, 1, 1]

    FileView {
        path: root.assetDir + "/colors.json"
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.background) root.background = c.background;
                if (c.foreground) root.foreground = c.foreground;
                if (c.subtext1) root.subtext1 = c.subtext1;
                if (c.subtext0) root.subtext0 = c.subtext0;
                if (c.accent) root.accent = c.accent;
                if (c.red) root.red = c.red;
            } catch (e) {
                // A half-written snapshot must not take the login screen with
                // it; the fallback palette above is already correct.
            }
        }
    }
}
