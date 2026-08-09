import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Volume readout. Click mutes, scroll adjusts, right-click picks the output
// device — the last of which is the difference between "shows the volume" and
// "is where you go when you plug in headphones".
Item {
    id: root

    property var barWindow: null
    // Scoped to the output so the same widget on a second monitor
    // does not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "audio")

        // implicitWidth off the row's *implicit* width, and the row anchored
    // rather than centred: reading .width here while the row centres itself
    // in that same width is a cycle, and Qt resolves it in no fixed order.
    // Whenever the content changed width -- VPN going from "вкл" to a speed,
    // volume from 50%% to 100%% -- the row sat off-centre inside the old width
    // for a frame, which is the clipped percentage at the island's edge.
    implicitWidth: audioRow.implicitWidth
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    // Every node whose volume or name the menu reads has to be tracked, or
    // PipeWire never sends its properties and the list comes back blank.
    PwObjectTracker {
        objects: {
            const list = Pipewire.nodes.values.filter(n => n.isSink && !n.isStream);
            if (root.source) list.push(root.source);
            return list;
        }
    }

    function nameFor(node) {
        return node.description || node.nickname || node.name || "?";
    }

    Row {
        id: audioRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.chipGap

        // A live value, so it gets its domain's colour. The ring is gone with
        // it: the glyph already steps through five levels, and drawing the same
        // number twice was the loudest thing in the bar for the state the
        // machine is in most of the day.
        Chip {
            id: volumeChip
            anchors.verticalCenter: parent.verticalCenter
            tone: "audio"
            glyph: Glyphs.volumeFor(root.volume, root.muted)
            value: root.muted ? "—" : Math.round(root.volume * 100) + "%"
            live: !root.muted
            onClicked: Toggles.toggleSheet("audio")
            onRightClicked: Menus.toggle(root.menuId)
            onScrolled: delta => {
                if (!root.sink || !root.sink.audio) return;
                const step = delta > 0 ? 0.05 : -0.05;
                root.sink.audio.volume = Math.max(0, Math.min(1, root.volume + step));
            }
        }

        // Only present when the microphone is muted. An always-on mic glyph is
        // noise; a muted one is what you want to learn before talking for a
        // minute, so it is an alert rather than a reading.
        Chip {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.micMuted
            tone: "audio"
            alert: true
            glyph: Glyphs.microphoneOff
            onClicked: {
                if (root.source && root.source.audio) root.source.audio.muted = false;
            }
        }
    }

    // Middle click still mutes, which the chip has no gesture for.
    MouseArea {
        id: ma
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.MiddleButton
        onClicked: {
            if (root.sink && root.sink.audio) root.sink.audio.muted = !root.muted;
        }
    }

    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        // Rebuilt on each open so hot-plugged devices appear without a reload.
        model: {
            if (!Menus.isOpen(root.menuId)) return [];
            const out = [];
            const sinks = Pipewire.nodes.values.filter(n => n.isSink && !n.isStream);
            for (const node of sinks) {
                out.push({
                    text: root.nameFor(node),
                    checkable: true,
                    checked: root.sink === node,
                    action: () => Pipewire.preferredDefaultAudioSink = node
                });
            }
            if (sinks.length > 0) out.push({ separator: true });
            out.push({
                text: root.micMuted ? "Включить микрофон" : "Заглушить микрофон",
                glyph: root.micMuted ? Glyphs.microphone : Glyphs.microphoneOff,
                enabled: root.source !== null && root.source.audio !== null,
                action: () => { if (root.source && root.source.audio) root.source.audio.muted = !root.micMuted; }
            });
            out.push({
                text: "Настройки звука",
                glyph: Glyphs.tune,
                action: () => Quickshell.execDetached(["pavucontrol"])
            });
            return out;
        }
    }

    // A tooltip could name the sink; this can also set the level and mute the
    // microphone, which is what people actually reach for.
    Popover {
        anchorItem: root
        hovered: ma.containsMouse && !Menus.isOpen(root.menuId)
        minWidth: 244

        Column {
            spacing: Theme.gapWide

            Row {
                spacing: Theme.gapWide

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Glyphs.volumeFor(root.volume, root.muted)
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIcon
                    color: root.muted ? Theme.subtext0 : Theme.accent
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: root.muted ? "Звук выключен"
                                         : Math.round(root.volume * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }

                    Text {
                        width: 176
                        text: root.sink ? root.nameFor(root.sink) : "Нет устройства вывода"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        elide: Text.ElideRight
                    }
                }
            }

            // Draggable, so the card is a control and not a readout. The step
            // matches the volume keys so keyboard and pointer agree.
            Item {
                width: 218
                height: 16

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: levelArea.containsMouse || levelArea.pressed ? 7 : 4
                    radius: height / 2
                    color: Qt.alpha(Theme.text, Theme.fillHover)
                    Behavior on height { NumberAnimation { duration: Theme.animFast } }

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, root.volume))
                        color: root.muted ? Theme.subtext0 : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }

                MouseArea {
                    id: levelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function apply(x) {
                        if (!root.sink || !root.sink.audio) return;
                        root.sink.audio.volume = Math.max(0, Math.min(1, x / width));
                        root.sink.audio.muted = false;
                    }
                    onPressed: mouse => apply(mouse.x)
                    onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                }
            }

            Rectangle {
                width: 218
                height: 1
                color: Qt.alpha(Theme.text, Theme.fillHover)
            }

            // The hit area is a sibling of the row rather than a child of it:
            // a MouseArea inside a Row is laid out as another column of it,
            // which both breaks the row and puts the target in the wrong place.
            Item {
                width: 218
                height: 22

                Row {
                    id: micRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: root.micMuted ? Glyphs.microphoneOff : Glyphs.microphone
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIconMicro
                        color: root.micMuted ? Theme.red : Theme.subtext1
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: root.micMuted ? "Микрофон выключен" : "Микрофон включён"
                        color: micHit.containsMouse ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }
                }

                MouseArea {
                    id: micHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.source && root.source.audio) {
                            root.source.audio.muted = !root.source.audio.muted;
                        }
                    }
                }
            }
        }
    }
}
