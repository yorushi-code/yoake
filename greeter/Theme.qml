pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The greeter's colours and type.
//
// A trimmed copy of the session's Theme rather than an import of it: the
// greeter runs as its own unprivileged user and the home directory it would
// have to read is 700. What it gets instead is a snapshot, written to
// /var/lib/yoake-greeter by yoake-greeter-sync whenever the wallpaper
// changes, so the login screen keeps wearing the same palette as the desktop
// without ever reading the desktop's files.
//
// The literals below are the fallback for a machine where that snapshot has
// never been taken. They are what the greeter looks like on a fresh install,
// not a second source of truth.
Singleton {
    id: root

    readonly property string assetDir: "/var/lib/yoake-greeter"

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
    // Installed to /usr/share/fonts/yoake by bin/yoake-greeter-install: the
    // shell's own copy lives under a home directory the greeter account cannot
    // read, and a missing icon font here draws the icon's *name*, not a box.
    readonly property string fontIconFamily: "Material Symbols Rounded"

    readonly property int fontLabel: 10
    readonly property int fontSmall: 11
    readonly property int fontBody: 12
    readonly property int fontLead: 13
    readonly property int fontTitle: 15
    readonly property int fontHeadline: 30

    // ── The shape ladder ──
    //
    // The same four steps the session uses, for the same reason: a family of
    // shapes is what makes surfaces read as relatives. The greeter had none and
    // was rounding by eye, which is how a login screen ends up looking like a
    // near-miss of the desktop it leads to.
    readonly property int radiusPip: 4
    readonly property int radiusChip: 10
    readonly property int radiusCard: 16
    readonly property int radiusPanel: 24

    function pill(height) {
        return height / 2;
    }

    // ── The surface, veil and ink ladders ──
    //
    // The session's, at the same values. Only the rungs this screen actually
    // stands on: a copy that carries rungs nothing here uses is a second source
    // of truth waiting to disagree with the first.
    readonly property real fillSubtle: 0.06
    readonly property real fillMuted: 0.10
    readonly property real fillHover: 0.14
    readonly property real strokeSoft: 0.10
    readonly property real strokeFirm: 0.18
    readonly property real veilSoft: 0.45
    readonly property real veilFirm: 0.60
    readonly property real veilSolid: 0.88
    readonly property real inkStrong: 0.80
    readonly property real inkGhost: 0.28

    // ── Motion ──
    //
    // The session's vocabulary, minus the scaling. Perception does not run
    // here and must not: a login screen that is slower at three in the morning
    // is a login screen that looks broken to somebody who has just woken up.
    readonly property int animFlick: 90
    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animSlow: 420
    readonly property int animBusy: 520
    readonly property int animTick: 55
    readonly property int animEnter: 620
    readonly property int animArrive: 900
    readonly property int animDrift: 1500
    readonly property int animDoze: 2400

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
