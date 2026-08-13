import QtQuick
import Quickshell
import Quickshell.Wayland

// The mixer, which this shell did not have.
//
// Clicking the volume chip used to open a panel with one slider on it: the
// default sink, at whatever level it was. That answers a question nobody asks.
// The question people actually ask is "why is the sound coming out of the
// laptop", and answering it needs every output, every input and every
// application stream visible at once, each with its own level and its own way
// of being changed.
//
// Nothing here spawns a process. PipeWire is a live object graph and the shell
// is bound to it; the previous panel shelled out to read a number that was
// already in memory.
PanelWindow {
    id: win

    // Overlay, not the default Top: niri draws a fullscreen window above the
    // Top layer, so a panel the user just asked for would open behind the video
    // they were watching and read as a dead keystroke.
    WlrLayershell.layer: WlrLayer.Overlay

    // Animations bind to this rather than to the toggle. The panel is created
    // lazily, so it is born with its toggle already true, and an entrance bound
    // straight to the toggle has nothing to animate from.
    readonly property bool open: Toggles.audioPanelOpen && win.armed
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
    // Exclusive rather than merely focusable: `focusable` alone asks for
    // on-demand interactivity, which means the compositor hands over the
    // keyboard only once the surface is clicked -- so a panel opened from the
    // bar ignored Escape until you had clicked it first.
    focusable: Toggles.audioPanelOpen
    WlrLayershell.keyboardFocus: Toggles.audioPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        // Past the sheet's own exit, so the window is still mapped while it
        // dissolves.
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onAudioPanelOpenChanged() {
            if (Toggles.audioPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: win.mapped = Toggles.audioPanelOpen

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.audioPanelOpen = false
    }

    Item {
        id: keyHost
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.audioPanelOpen = false
        Timer { interval: 700; running: true; onTriggered: console.warn("YOAKE-FOCUS open=" + win.open + " focus=" + keyHost.focus + " active=" + keyHost.activeFocus) }

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.rightMargin: Theme.barMargin
            width: Theme.sheetList
            height: Math.min(700, column.implicitHeight + Theme.sheetPad * 2)
            align: "right"
            accent: Theme.tone("audio")
            shown: win.open
            onCloseRequested: Toggles.audioPanelOpen = false

            // Swallows clicks so the backdrop does not treat a click on the
            // panel itself as "outside".
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            // Which list is showing. The three are not three panels: they are
            // three answers to "what is making or taking sound", and switching
            // between them is one control changing its subject.
            property int page: 0
            readonly property var pages: [Audio.sinks, Audio.sources, Audio.streams]
            readonly property var current: sheet.pages[sheet.page] || []

            readonly property var subject: sheet.page === 1 ? Audio.defaultSource : Audio.defaultSink

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                // ── What the sound is going through right now ──
                Row {
                    width: parent.width
                    spacing: Theme.gapCard

                    LevelTile {
                        id: tile
                        anchors.verticalCenter: parent.verticalCenter
                        value: sheet.subject && sheet.subject.audio ? sheet.subject.audio.volume : 0
                        tone: "audio"
                        // Only while the panel is on screen. The wave is a
                        // permanently running animation, and one of those costs
                        // about a fifth of a core for as long as it runs.
                        active: win.open
                        overrideLabel: (sheet.subject && sheet.subject.audio && sheet.subject.audio.muted)
                            ? "—" : ""
                    }

                    Column {
                        width: parent.width - tile.width - Theme.gapCard
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        SheetHeader {
                            width: parent.width
                            title: Audio.label(sheet.subject) || "Нет устройства"
                            // The node name, which is the only thing that tells
                            // two outputs called "Analog Stereo" apart.
                            subtitle: Audio.technical(sheet.subject)
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.gapWide

                            Rectangle {
                                id: muteButton
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                radius: Theme.pill(height)
                                color: muteHit.containsMouse
                                    ? Qt.alpha(Theme.text, Theme.fillHover)
                                    : Qt.alpha(Theme.text, Theme.fillMuted)
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    icon: (sheet.subject && sheet.subject.audio && sheet.subject.audio.muted)
                                        ? Glyphs.volumeMute : Glyphs.volumeHigh
                                    size: Theme.fontIconSmall
                                    fill: 1
                                    color: (sheet.subject && sheet.subject.audio && sheet.subject.audio.muted)
                                        ? Theme.subtext0 : Theme.text
                                }

                                MouseArea {
                                    id: muteHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Audio.toggleMute(sheet.subject)
                                }
                            }

                            HSlider {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - muteButton.width - headValue.width - Theme.gapWide * 2
                                value: sheet.subject && sheet.subject.audio ? sheet.subject.audio.volume : 0
                                muted: sheet.subject && sheet.subject.audio ? sheet.subject.audio.muted : false
                                tint: Theme.tone("audio")
                                onMoved: v => Audio.setVolume(sheet.subject, v)
                            }

                            Text {
                                id: headValue
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round((sheet.subject && sheet.subject.audio
                                    ? sheet.subject.audio.volume : 0) * 100) + "%"
                                color: Theme.subtext0
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.features: ({ "tnum": 1 })
                            }
                        }
                    }
                }

                Segmented {
                    width: parent.width
                    tone: "audio"
                    model: ["Выходы", "Входы", "Потоки"]
                    current: sheet.page
                    onPicked: i => sheet.page = i
                }

                // ── Everything that can make or take sound ──
                Column {
                    width: parent.width
                    spacing: Theme.spacing

                    Repeater {
                        model: sheet.current

                        delegate: DeviceRow {
                            id: row
                            required property var modelData
                            required property int index

                            width: parent.width
                            tone: "audio"
                            glyph: sheet.page === 2
                                ? Glyphs.stream
                                : Audio.iconFor(row.modelData)
                            name: sheet.page === 2
                                ? Audio.streamLabel(row.modelData)
                                : Audio.label(row.modelData)
                            subtitle: row.active ? "Активное по умолчанию" : Audio.technical(row.modelData)
                            // A stream is never "the default" -- there is no
                            // such thing -- so it always keeps its own control.
                            active: sheet.page !== 2 && row.modelData === sheet.subject
                            hasControl: !row.active
                            muted: row.modelData.audio ? row.modelData.audio.muted : false
                            value: row.modelData.audio ? row.modelData.audio.volume : 0

                            onActivated: {
                                if (sheet.page === 0) Audio.setDefaultSink(row.modelData);
                                else if (sheet.page === 1) Audio.setDefaultSource(row.modelData);
                            }
                            onToggledMute: Audio.toggleMute(row.modelData)
                            onMoved: v => Audio.setVolume(row.modelData, v)

                            // Rule 8: the list re-reads itself along its own
                            // length rather than repainting all at once.
                            opacity: 0
                            Component.onCompleted: intro.restart()
                            SequentialAnimation {
                                id: intro
                                PauseAnimation { duration: Direction.stagger(row.index) }
                                NumberAnimation {
                                    target: row; property: "opacity"; to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasized
                                }
                            }
                        }
                    }

                    EmptyRow {
                        width: parent.width
                        visible: sheet.current.length === 0
                        glyph: sheet.page === 1 ? Glyphs.microphoneOff : Glyphs.volumeMute
                        text: sheet.page === 2
                            ? "Ничего не играет"
                            : (sheet.page === 1 ? "Нет источников" : "Нет выходов")
                    }
                }
            }
        }
    }
}
