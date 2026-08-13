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
        // onAnnounced, not onRefreshed: a re-read is not an event. The
        // control centre asks for one every time it opens, and that was
        // enough to slide this OSD over the panel that had just asked.
        function onAnnounced() { root.show("Brightness", Brightness.value); }
    }

    IpcHandler {
        target: "osd"
        // The keys change the backlight in another process, so this is the
        // one caller that knows a reading is worth announcing.
        function brightness() { Brightness.refresh(true); }
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

    // How lit the bar's leading edge is. Fires on the press rather than on the
    // card appearing, so holding a volume key reads as a series of taps and not
    // as one continuous slide -- which is what it is, and what the keyboard is
    // actually sending.
    property real impulse: 0
    SequentialAnimation {
        id: spark
        NumberAnimation { target: root; property: "impulse"; to: Theme.veilDense; duration: Theme.animFlick }
        NumberAnimation { target: root; property: "impulse"; to: 0; duration: Theme.animSlow; easing.type: Easing.InQuad }
    }

    function show(label_, value_) {
        root.label = label_;
        root.value = value_;
        root.icon = root.iconFor(label_, value_);
        root.shown = true;
        spark.restart();
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    PanelWindow {
        id: win
        // Overlay, not the default Top, for the reason `Launcher` gives: niri
        // draws a fullscreen window above the Top layer. This is the surface
        // that answers a key the user just pressed — turn the volume down inside
        // a fullscreen video or a game and the confirmation was drawn behind it,
        // so the key read as dead. Of every surface in this shell it is the one
        // that least tolerates being invisible.
        //
        // The media OSD stays on Top on purpose. It answers nothing: it
        // announces a track change nobody asked about, and it is now held back
        // during fullscreen anyway. The layer and the guard agree.
        WlrLayershell.layer: WlrLayer.Overlay
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
            // arrival) instead of the flat fade it used to have. It intended to
            // match and did not: it entered from 0.80 against the token's 0.90,
            // which is the largest pop in the shell spent on the surface that
            // should announce itself least.
            //
            // Every beat at zero, and that is deliberate rather than missing.
            // This is Direction's `acknowledge` type: on a volume key the accent
            // *is* the message and holding it back by a beat turns a keypress
            // into lag. It spells the motion out rather than going through
            // `Reveal` because `Surface` samples the backdrop from `screenX` and
            // `screenY`, and a scale transform on an ancestor moves the sampled
            // rectangle out from under the thing being frosted.
            scale: root.shown ? 1 : Theme.revealScale
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

                MaterialSymbol {
                    id: osdGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.icon
                    size: Theme.fontIcon
                    // Solid. This is not a status the eye has to weigh against
                    // its neighbours -- it is the subject of a card that exists
                    // for a second and a half because you just pressed a key.
                    fill: 1
                    color: Theme.accent

                    // Crossing into a different icon is the clearest signal
                    // that the value moved at all; without this the glyph
                    // changed silently mid-fade and read as a render glitch.
                    SequentialAnimation {
                        id: glyphPop
                        NumberAnimation { target: osdGlyph; property: "scale"; to: 1.3; duration: Theme.animFlick; easing.type: Easing.OutQuad }
                        NumberAnimation { target: osdGlyph; property: "scale"; to: 1.0; duration: Theme.animNormal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
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
                            font.pixelSize: Theme.fontSmall
                        }

                        // The number as well as the bar. A bar says "about
                        // here"; the value is what you are actually setting,
                        // and every other readout in the shell shows it.
                        //
                        // Rolling, because this is the number in the shell that
                        // changes most often and always because a key was just
                        // pressed. A digit that is replaced says the value is
                        // different; a digit that rolls says which way it went,
                        // which is the entire question a volume key asks.
                        Row {
                            anchors.right: parent.right
                            spacing: 0
                            visible: root.label !== "Muted"

                            RollNumber {
                                value: Math.round(root.value * 100)
                                pixelSize: Theme.fontSmall
                                family: Theme.fontFamily
                                weight: Font.Medium
                                ink: Theme.text
                            }

                            Text {
                                text: "%"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.Medium
                            }
                        }
                    }
                    Rectangle {
                        id: track
                        width: parent.width
                        height: 6
                        radius: Theme.radiusPip
                        color: Theme.surface0

                        Rectangle {
                            id: fill
                            width: track.width * Math.max(0, Math.min(1, root.value))
                            height: parent.height
                            radius: Theme.radiusPip
                            color: Theme.accent
                            // No overshoot here, deliberately, however much the
                            // rest of the shell springs. A bar *is* the value:
                            // one that sails past 70 and comes back has said
                            // the volume went somewhere it never went.
                            Behavior on width {
                                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized }
                            }
                        }

                        // The impulse goes here instead, where it costs the
                        // reading nothing: the leading edge lights on every
                        // press and fades over the next moment, so a key held
                        // down leaves a spark riding the end of the bar.
                        Glow {
                            anchors.verticalCenter: fill.verticalCenter
                            x: fill.width - width / 2
                            width: 14
                            height: 14
                            radius: width / 2
                            tint: Theme.accent
                            reach: 16
                            amount: root.impulse
                        }
                    }
                }
            }
        }
    }
}
