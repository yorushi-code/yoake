import QtQuick
import Quickshell
import Quickshell.Wayland

// The player, with the equaliser under it.
//
// The album art is a record here rather than a square, and it turns while the
// music does. That is not styling: it answers "is this actually playing" from
// across the room, which is the question a transport button can only answer by
// being read.
//
// The equaliser shares this sheet rather than getting its own, because it is
// not a separate subject -- it is how what is playing sounds, and putting it
// one more click away is how it ends up never being used.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay

    // Seconds as a time, which nothing in the shell owned: MediaCard had its
    // own copy of this arithmetic and so did the bar.
    function clock(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property bool open: Toggles.mediaPanelOpen && win.armed
    property bool armed: false
    property Timer _armTick: Timer {
        interval: 16
        running: true
        onTriggered: win.armed = true
    }

    property bool mapped: false
    visible: mapped

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    focusable: Toggles.mediaPanelOpen
    WlrLayershell.keyboardFocus: Toggles.mediaPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onMediaPanelOpenChanged() {
            if (Toggles.mediaPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: win.mapped = Toggles.mediaPanelOpen

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.mediaPanelOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.mediaPanelOpen = false

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.leftMargin: Theme.barMargin
            width: Theme.sheetWide
            height: Math.min(760, column.implicitHeight + Theme.sheetPad * 2)
            align: "left"
            accent: Theme.accent
            // The panel belongs to what is playing. Blurred and pushed under a
            // veil by Sheet itself, so it is a ground and never something
            // anyone tries to look at -- the art is already on the panel at
            // full size a few pixels away.
            backdrop: Media.cover
            shown: win.open
            onCloseRequested: Toggles.mediaPanelOpen = false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                Row {
                    width: parent.width
                    spacing: Theme.gapSection

                    Vinyl {
                        id: disc
                        anchors.verticalCenter: parent.verticalCenter
                        width: 190
                        height: 190
                        source: Media.cover
                        spinning: Media.playing && win.open
                        ring: Theme.accent
                    }

                    Column {
                        width: parent.width - disc.width - Theme.gapSection
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        Marquee {
                            width: parent.width
                            height: implicitHeight
                            text: Media.title !== "" ? Media.title : "Ничего не играет"
                            color: Theme.text
                            pixelSize: Theme.fontDisplay
                            weight: Font.Medium
                            paused: !win.open
                        }

                        Text {
                            width: parent.width
                            visible: Media.artist !== ""
                            text: "BY " + Media.artist
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: Theme.spacing

                            Chip {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Audio.defaultSink !== null
                                tone: "bt"
                                live: false
                                glyph: Audio.iconFor(Audio.defaultSink)
                                label: Audio.label(Audio.defaultSink)
                                labelCap: 160
                                onClicked: Toggles.toggleSheet("audio")
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Media.player !== null
                                text: "VIA " + (Media.player ? Media.player.identity : "")
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                font.italic: true
                            }
                        }

                        // Mint on a sheet whose accent comes from the cover.
                        // A value must not be painted in the colour of the
                        // content it belongs to, or "how far through" and "what
                        // is playing" become the same signal.
                        HSlider {
                            width: parent.width
                            visible: Media.length > 0
                            value: Media.progress
                            tint: Theme.tone("net")
                            onCommitted: v => Media.seek(v)
                        }

                        Item {
                            width: parent.width
                            height: elapsed.implicitHeight
                            visible: Media.length > 0

                            Text {
                                id: elapsed
                                anchors.left: parent.left
                                text: win.clock(Media.position)
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                font.features: ({ "tnum": 1 })
                            }

                            Text {
                                anchors.right: parent.right
                                text: win.clock(Media.length)
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                font.features: ({ "tnum": 1 })
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.gapWide

                            Repeater {
                                model: [
                                    { glyph: Glyphs.skipPrevious, big: false },
                                    { glyph: Media.playing ? Glyphs.pause : Glyphs.play, big: true },
                                    { glyph: Glyphs.skipNext, big: false }
                                ]

                                delegate: Rectangle {
                                    id: button
                                    required property var modelData
                                    required property int index

                                    width: button.modelData.big ? 42 : 34
                                    height: width
                                    radius: Theme.radiusChip
                                    color: buttonHit.containsMouse
                                        ? Qt.alpha(Theme.text, Theme.fillHover)
                                        : Qt.alpha(Theme.text, Theme.fillMuted)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    scale: buttonHit.pressed ? 0.9 : 1
                                    Behavior on scale {
                                        NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpringBig }
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        icon: button.modelData.glyph
                                        size: button.modelData.big ? Theme.fontIcon : Theme.fontIconSmall
                                        // A transport control is a button, not
                                        // a reading: it is always solid.
                                        fill: 1
                                        color: Theme.text
                                    }

                                    MouseArea {
                                        id: buttonHit
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (button.index === 0) Media.previous();
                                            else if (button.index === 1) Media.togglePlay();
                                            else Media.next();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.text, Theme.fillMuted)
                }

                Equalizer {
                    width: parent.width
                }
            }
        }
    }
}
