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

    width: audioRow.width
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
        anchors.centerIn: parent
        spacing: 5

        BarIcon {
            anchors.verticalCenter: parent.verticalCenter
            glyph: Glyphs.volumeFor(root.volume, root.muted)
            color: root.muted ? Theme.subtext0 : Theme.accent
            // No ring while muted: a level readout under a muted icon is a
            // contradiction, and the ring is the loudest part of the widget.
            progress: root.muted ? -1 : root.volume
            hovered: ma.containsMouse
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.pixelSize: 11
            visible: !root.muted
            text: root.sink && root.sink.audio ? Math.round(root.volume * 100) + "%" : "--"
        }

        // Only present when the microphone is muted: an always-on mic glyph
        // would be noise, but a muted mic is something you want to find out
        // before talking for a minute.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.micMuted
            text: Glyphs.microphoneOff
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: Theme.red
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Menus.toggle(root.menuId);
                return;
            }
            if (root.sink && root.sink.audio) root.sink.audio.muted = !root.muted;
        }
        onWheel: wheel => {
            if (!root.sink || !root.sink.audio) return;
            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.volume + delta));
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

    Tooltip {
        anchorItem: root
        active: ma.containsMouse && !Menus.isOpen(root.menuId)
        text: root.sink ? root.nameFor(root.sink) : "Нет устройства вывода"
        subtext: "ЛКМ — звук вкл/выкл · колесо — громкость · ПКМ — устройство"
    }
}
