import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // Kept inline so the overlay still runs when config.json is missing or malformed.
    readonly property var defaults: ({
        "enabled": true,
        "type": "snow",
        "count": 55,
        "speed": 1.0,
        "size": 1.0,
        "opacity": 0.85,
        "sway": true,
        "spin": true,
        "onlyOverAyuGram": true,
        "appId": "com.ayugram.desktop",
        "layer": "top"
    })
    property var cfg: defaults

    readonly property var presets: ({
        "snow": {
            "glyphs": ["❄", "❅", "❆", "•"],
            "tint": "#ffffff", "px": 18, "fall": 11000,
            "sway": 26, "spin": 14000, "tilt": 0, "mono": false
        },
        "sakura": {
            "glyphs": ["🌸", "✿", "❀"],
            "tint": "#ffb3cd", "px": 24, "fall": 9000,
            "sway": 46, "spin": 5000, "tilt": 0, "mono": false
        },
        "matrix": {
            "glyphs": [],
            "tint": "#3cff78", "px": 15, "fall": 3200,
            "sway": 0, "spin": 0, "tilt": 0, "mono": true
        },
        "rain": {
            "glyphs": ["│"],
            "tint": "#dceaff", "px": 26, "fall": 800,
            "sway": 0, "spin": 0, "tilt": 11, "mono": false
        },
        "leaves": {
            "glyphs": ["🍁", "🍂", "🍃"],
            "tint": "#ffbe78", "px": 24, "fall": 8000,
            "sway": 55, "spin": 4000, "tilt": 0, "mono": false
        }
    })

    readonly property var preset: presets[cfg.type] !== undefined ? presets[cfg.type] : presets["snow"]

    // Qt.resolvedUrl(".") comes back without a trailing slash here, so it cannot be
    // concatenated blindly.
    readonly property string configPath: {
        var dir = Qt.resolvedUrl(".").toString().replace("file://", "")
        if (!dir.endsWith("/"))
            dir += "/"
        return dir + "config.json"
    }

    function applyConfig(raw) {
        var merged = {}
        for (var k in defaults)
            merged[k] = defaults[k]
        try {
            var parsed = JSON.parse(raw)
            for (var key in parsed)
                merged[key] = parsed[key]
        } catch (e) {
            console.warn("snow: config.json is not valid JSON, using defaults:", e)
        }
        cfg = merged
    }

    // Matrix columns are generated per particle instead of picked from a list so
    // every stream is a different run of characters.
    function matrixColumn() {
        var n = 3 + Math.floor(Math.random() * 5)
        var out = []
        for (var i = 0; i < n; i++) {
            out.push(Math.random() < 0.25
                     ? String.fromCharCode(0x30 + Math.floor(Math.random() * 10))
                     : String.fromCharCode(0x30a2 + Math.floor(Math.random() * 80)))
        }
        return out.join("\n")
    }

    // Resolves the preset itself instead of reading root.preset: during a type
    // switch cfg.type updates before the preset binding does, and the stale pair
    // yields an undefined glyph.
    function pickGlyph() {
        var p = presets[cfg.type] !== undefined ? presets[cfg.type] : presets["snow"]
        if (!p.glyphs || p.glyphs.length === 0)
            return matrixColumn()
        return p.glyphs[Math.floor(Math.random() * p.glyphs.length)]
    }

    function layerOf(name) {
        if (name === "overlay")
            return WlrLayer.Overlay
        if (name === "bottom")
            return WlrLayer.Bottom
        return WlrLayer.Top
    }

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.applyConfig(text())
        onLoadFailed: root.cfg = root.defaults
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: root.layerOf(root.cfg.layer)
            WlrLayershell.namespace: "snow-overlay"
            anchors { top: true; bottom: true; left: true; right: true }

            // An empty input region is what makes the overlay click-through.
            mask: Region {}

            readonly property bool appFocused: {
                if (!root.cfg.onlyOverAyuGram)
                    return true
                var t = ToplevelManager.activeToplevel
                return t !== null && String(t.appId) === String(root.cfg.appId)
            }

            visible: root.cfg.enabled && appFocused

            Repeater {
                model: win.visible ? Math.max(1, Math.round(root.cfg.count)) : 0

                delegate: Item {
                    id: part
                    required property int index

                    readonly property bool isRain: root.cfg.type === "rain"
                    // Depth: smaller, fainter particles read as further away.
                    readonly property real depth: 0.65 + Math.random() * 0.6
                    // Rain carries its own, much wider depth range - with the glyph
                    // range every drop sits at the same distance and the sheet reads
                    // as one flat layer of sticks.
                    readonly property real rdepth: 0.3 + Math.random() * 1.0
                    readonly property real span: win.height + 100
                    readonly property int fallDur: isRain
                        ? Math.round(root.preset.fall / (0.35 + rdepth)
                                     / Math.max(0.1, root.cfg.speed) * (0.85 + Math.random() * 0.3))
                        : Math.round(root.preset.fall / Math.max(0.1, root.cfg.speed)
                                     * (0.75 + Math.random() * 0.6))
                    readonly property real amp: root.cfg.sway
                        ? root.preset.sway * (0.4 + Math.random() * 0.6) : 0
                    readonly property int swayDur: Math.round(fallDur * (0.18 + Math.random() * 0.22))
                    readonly property int spinDur: root.cfg.spin && root.preset.spin > 0
                        ? Math.round(root.preset.spin * (0.7 + Math.random() * 0.7)) : 0
                    readonly property real spinTo: Math.random() < 0.5 ? -360 : 360
                    // Wind is never perfectly even, so each drop leans slightly
                    // differently. Only for types that lean at all - a tilted matrix
                    // column would be plain wrong.
                    readonly property real tiltJitter: root.preset.tilt !== 0
                        ? (Math.random() - 0.5) * 5 : 0
                    // Tilted particles have to travel along their own axis, otherwise
                    // a leaning drop falls straight down and reads as a stray glyph.
                    readonly property real drift:
                        Math.tan((root.preset.tilt + tiltJitter) * Math.PI / 180) * span
                    // Drift moves every particle sideways on the way down, so spawning
                    // across the bare window width leaves a wedge at the bottom corner
                    // that nothing can ever reach.
                    readonly property real margin: Math.abs(drift) + amp
                    readonly property real baseX:
                        Math.random() * (win.width + margin) - Math.max(0, drift) - amp
                    readonly property real startProg: Math.random()
                    // Length and speed both follow depth: a near drop is long and fast,
                    // a far one short and slow, which is what sells the parallax.
                    readonly property real streak: (10 + 44 * rdepth) * root.cfg.size

                    // Animated through plain properties so x, y and rotation stay
                    // bindings and pick up live config changes.
                    property real prog: 0
                    property real swayOffset: 0
                    property real spinAngle: 0

                    x: baseX + drift * prog + swayOffset
                    y: -60 + span * prog
                    rotation: root.preset.tilt + tiltJitter + spinAngle
                    opacity: root.cfg.opacity * (isRain
                        ? 0.2 + 0.55 * rdepth
                        : 0.55 + Math.random() * 0.45)
                    width: 0
                    height: 0

                    Text {
                        visible: !part.isRain
                        anchors.centerIn: parent
                        text: root.pickGlyph()
                        color: root.preset.tint
                        font.pixelSize: Math.max(4, Math.round(root.preset.px * root.cfg.size * part.depth))
                        // Naming the fallback explicitly: binding font.family to itself
                        // is a self-reference, not a "leave it alone".
                        font.family: root.preset.mono ? "monospace" : Qt.application.font.family
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 0.85
                    }

                    Rectangle {
                        id: drop
                        visible: part.isRain
                        anchors.centerIn: parent
                        width: Math.max(1, Math.round((0.8 + 1.3 * part.rdepth) * root.cfg.size))
                        height: part.streak
                        radius: width / 2

                        readonly property color tint: root.preset.tint

                        // A flat bar reads as a stick. Real falling water smears out
                        // behind itself, so the streak fades towards the trailing end
                        // and stays solid at the leading one.
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(drop.tint.r, drop.tint.g, drop.tint.b, 0.0)
                            }
                            GradientStop {
                                position: 0.45
                                color: Qt.rgba(drop.tint.r, drop.tint.g, drop.tint.b, 0.3)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.rgba(drop.tint.r, drop.tint.g, drop.tint.b, 1.0)
                            }
                        }
                    }

                    SequentialAnimation on prog {
                        running: true
                        // First pass starts mid-fall so the effect fills the screen
                        // instantly instead of arriving as one wave from the top.
                        NumberAnimation {
                            from: part.startProg
                            to: 1
                            duration: Math.max(200, Math.round(part.fallDur * (1 - part.startProg)))
                        }
                        NumberAnimation {
                            from: 0
                            to: 1
                            duration: part.fallDur
                            loops: Animation.Infinite
                        }
                    }

                    SequentialAnimation on swayOffset {
                        running: part.amp > 0
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -part.amp
                            to: part.amp
                            duration: part.swayDur
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: part.amp
                            to: -part.amp
                            duration: part.swayDur
                            easing.type: Easing.InOutSine
                        }
                    }

                    NumberAnimation on spinAngle {
                        running: part.spinDur > 0
                        loops: Animation.Infinite
                        from: 0
                        to: part.spinTo
                        duration: part.spinDur
                    }
                }
            }
        }
    }
}
