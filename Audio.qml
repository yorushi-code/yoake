pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Everything the machine can make or take sound with.
//
// The shell knew about exactly one node -- the default sink -- because that is
// all a volume percentage needs. It is not what a person needs: the question
// that actually gets asked is "why is the sound coming out of the laptop", and
// answering it means seeing every output, every input and every application
// stream at once, each with its own level.
//
// Nothing here spawns a process. PipeWire is already a live object graph and
// Quickshell binds to it directly; shelling out to wpctl to read a number that
// is sitting in memory is how the old panel got its one slider.
Singleton {
    id: root

    // Tracking is not automatic: an untracked node reports no volume at all,
    // which is what made a device list look like a list of muted devices.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: root.sinks.concat(root.sources).concat(root.streams)
    }

    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

    readonly property var sinks: root.nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: root.nodes.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var streams: root.nodes.filter(n => n.isStream && n.isSink)

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    readonly property real volume: root.defaultSink && root.defaultSink.audio
        ? root.defaultSink.audio.volume : 0
    readonly property bool muted: root.defaultSink && root.defaultSink.audio
        ? root.defaultSink.audio.muted : false

    // What to call a node on screen. The description is what a person would
    // recognise; the name is what tells two of them apart.
    function label(node) {
        if (!node) return "";
        return node.description || node.nickname || node.name || "";
    }

    function technical(node) {
        return node ? (node.name || "") : "";
    }

    // An application stream is named by its application, not by its node.
    function streamLabel(node) {
        if (!node) return "";
        const p = node.properties || ({});
        return p["application.name"] || p["media.name"] || root.label(node);
    }

    function streamIcon(node) {
        const p = node && node.properties ? node.properties : ({});
        return p["application.icon-name"] || p["application.name"] || "";
    }

    // Chosen by what the node says it is rather than by parsing its name: a
    // bluetooth headset and a pair of USB speakers are both "output" until you
    // read the bus, and the bus is in the properties.
    function iconFor(node) {
        if (!node) return Glyphs.volumeHigh;
        const p = node.properties || ({});
        const form = (p["device.form-factor"] || "").toLowerCase();
        const bus = (p["device.bus"] || "").toLowerCase();
        if (!node.isSink) return Glyphs.microphone;
        if (form === "headset" || form === "headphone") return Glyphs.headphones;
        if (bus === "bluetooth") return Glyphs.bluetooth;
        return Glyphs.speaker;
    }

    function setVolume(node, value) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setMuted(node, value) {
        if (node && node.audio) node.audio.muted = value;
    }

    function toggleMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted;
    }

    // Preferred, not forced: PipeWire keeps the choice and re-applies it when
    // the device comes back, which is the difference between switching output
    // and switching output until the headphones reconnect.
    function setDefaultSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }
}
