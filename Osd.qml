import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Effects
import Quickshell.Services.Pipewire

Item {
    id: root

    property real value: 0
    property string label: ""
    property string icon: Glyphs.volumeHigh
    property bool shown: false

    function iconFor(label_, value_) {
        if (label_ === "Brightness") return Glyphs.brightness;
        if (label_ === "Muted") return Glyphs.volumeMute;
        return Glyphs.volumeFor(value_, false);
    }

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // Reacts to volume changes regardless of who caused them (the bar's scroll
    // handler, or the existing wpctl keybinds) — no bind changes needed for the
    // volume OSD at all. Suppressed until the sink has settled: PipeWire emits
    // an initial volumeChanged as soon as the node is tracked, which popped the
    // OSD on every login before anything had been touched.
    property bool armed: false
    Timer {
        interval: 1200
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (!root.armed) return;
            root.show("Volume", Pipewire.defaultAudioSink.audio.volume);
        }
        function onMutedChanged() {
            if (!root.armed) return;
            const a = Pipewire.defaultAudioSink.audio;
            root.show(a.muted ? "Muted" : "Volume", a.muted ? 0 : a.volume);
        }
    }

    // Brightness lives in its own singleton so the control centre's slider and
    // this OSD read the same value; both used to run brightnessctl separately
    // and neither noticed the other's changes.
    Connections {
        target: Brightness
        function onRefreshed() { root.show("Brightness", Brightness.value); }
    }

    IpcHandler {
        target: "osd"
        function brightness() { Brightness.refresh(); }
    }

    // What the label says, as opposed to what it is called. The kind is an
    // internal key -- the icon is chosen by it -- so it stays English while
    // the caption does not; the rest of the shell is in Russian and this was
    // the one surface still announcing itself in another language.
    readonly property var _captions: ({
        "Volume": "Громкость",
        "Muted": "Звук выключен",
        "Brightness": "Яркость"
    })
    readonly property string caption: root._captions[root.label] || root.label

    function show(label_, value_) {
        root.label = label_;
        root.value = value_;
        root.icon = root.iconFor(label_, value_);
        root.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    PanelWindow {
        id: win
        // Explicit mapping bool — see ControlCenter.qml. Stays mapped through
        // the whole exit so the fade+scale can play instead of the window
        // unmapping the instant root.shown flips false.
        property bool mapped: false
        visible: mapped
        anchors.bottom: true
        // Lifts above the media OSD when that one is up, so a volume change
        // during playback doesn't land on top of the now-playing card.
        margins.bottom: Media.osdShown ? 60 + 96 + 12 : 60
        Behavior on margins.bottom {
            NumberAnimation { duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
        }
        implicitWidth: 240
        implicitHeight: 64
        color: "transparent"
        focusable: false
        exclusiveZone: 0

        Timer {
            id: hideDelay
            interval: Theme.animExit + 40
            onTriggered: win.mapped = false
        }
        Connections {
            target: root
            function onShownChanged() {
                if (root.shown) {
                    hideDelay.stop();
                    win.mapped = true;
                } else {
                    hideDelay.restart();
                }
            }
        }

        // The same object every raised thing in this shell is made of.
        Surface {
            id: card
            anchors.fill: parent
            radius: Theme.pill(height)
            elevation: "modal"
            screenX: (Screen.width - width) / 2
            screenY: Screen.height - win.margins.bottom - height
            tintOpacity: 0.78

            opacity: root.shown ? 1 : 0
            // Matches the panels' entrance language (bigger overshoot, slower
            // arrival) instead of the flat fade it used to have.
            scale: root.shown ? 1 : 0.8
            Behavior on opacity {
                NumberAnimation {
                    duration: root.shown ? Theme.animNormal : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.shown ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.shown ? Theme.easeSpringBig : Theme.easeExit
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    id: osdGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 20
                    color: Theme.accent

                    // Crossing into a different icon is the clearest signal
                    // that the value moved at all; without this the glyph
                    // changed silently mid-fade and read as a render glitch.
                    SequentialAnimation {
                        id: glyphPop
                        NumberAnimation { target: osdGlyph; property: "scale"; to: 1.3; duration: 100; easing.type: Easing.OutQuad }
                        NumberAnimation { target: osdGlyph; property: "scale"; to: 1.0; duration: 190; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                    }
                    onTextChanged: glyphPop.restart()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 160
                    spacing: Theme.spacing

                    Item {
                        width: parent.width
                        height: caption.implicitHeight

                        Text {
                            id: caption
                            anchors.left: parent.left
                            text: root.caption
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        // The number as well as the bar. A bar says "about
                        // here"; the value is what you are actually setting,
                        // and every other readout in the shell shows it.
                        Text {
                            anchors.right: parent.right
                            visible: root.label !== "Muted"
                            text: Math.round(root.value * 100) + "%"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.features: ({ "tnum": 1 })
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: Theme.radiusPip
                        color: Theme.surface0
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.value))
                            height: parent.height
                            radius: Theme.radiusPip
                            color: Theme.accent
                            Behavior on width {
                                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                            }
                        }
                    }
                }
            }
        }
    }
}
