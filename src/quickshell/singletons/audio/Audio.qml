pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../"

Singleton {
    id: root

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // Списки собираются императивно, а не биндингом, и это здесь главное.
    //
    // Биндинг читал свойства узлов внутри себя (application.id, device.class),
    // а чтение свойства в биндинге создаёт на него зависимость. В результате
    // любое изменение у любого узла -- сдвинутая громкость соседнего потока,
    // сменившееся название трека -- пересобирало весь массив. Модель получала
    // новый объект, делегаты уничтожались и создавались заново, и ползунок,
    // который в этот момент тянули, исчезал из-под курсора.
    //
    // Вызов из обработчика сигнала зависимостей не заводит, поэтому список
    // меняется только когда действительно меняется набор узлов.
    property var outputs: []
    property var inputs: []
    property var apps: []

    // Порядок перечисления в PipeWire ничем не гарантирован: он разный между
    // сессиями и меняется при появлении узла. Без устойчивого ключа строки
    // менялись местами на каждом обновлении.
    function _key(n) {
        var id = String(n.id !== undefined ? n.id : 0);
        while (id.length < 10) id = "0" + id;
        return (root.getNodeName(n) || "").toLowerCase() + " " + id;
    }

    function _collect(pred) {
        var arr = [];
        for (const n of Pipewire.nodes.values) {
            if (pred(n)) arr.push(n);
        }
        var keys = new Map();
        for (const n of arr) keys.set(n, root._key(n));
        arr.sort(function (a, b) {
            var ka = keys.get(a), kb = keys.get(b);
            return ka < kb ? -1 : (ka > kb ? 1 : 0);
        });
        return arr;
    }

    function _same(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false;
        }
        return true;
    }

    // The equaliser is a smart filter: WirePlumber puts it in front of
    // whichever device is chosen. Its sink is not a device to choose, and its
    // playback side is plumbing, not an application.
    function _isEffect(n) {
        var name = n.name || "";
        return name.startsWith("effect_input.") || name.startsWith("effect_output.");
    }

    function rebuild() {
        var o = root._collect(function (n) { return !n.isStream && n.isSink && n.audio && !root._isEffect(n); });
        var i = root._collect(function (n) {
            return !n.isStream && !n.isSink && n.audio
                && n.properties?.["device.class"] !== "monitor"
                && !n.name?.endsWith(".monitor");
        });
        var a = root._collect(function (n) {
            return n.isStream && n.audio && !root._isEffect(n)
                && n.properties?.["application.id"] !== "org.PulseAudio.pavucontrol"
                && n.properties?.["application.name"] !== Sounds.streamName;
        });

        // Присваиваем только при смене состава: иначе модель сбрасывается
        // на ровном месте, и мы возвращаемся ровно к той беде, от которой ушли.
        if (!root._same(o, root.outputs)) root.outputs = o;
        if (!root._same(i, root.inputs)) root.inputs = i;
        if (!root._same(a, root.apps)) root.apps = a;
    }

    // Узлы появляются пачками -- устройство приносит с собой сток, источник и
    // монитор разом. Короткая задержка склеивает их в одну пересборку.
    Timer {
        id: settle
        interval: 60
        onTriggered: root.rebuild()
    }

    Connections {
        target: Pipewire.nodes
        ignoreUnknownSignals: true
        function onValuesChanged() { settle.restart(); }
    }

    Component.onCompleted: root.rebuild()

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

    function setDefaultOutput(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultInput(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    function toggleMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted;
    }

    function setVolume(node, pct) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1.5, pct / 100.0));
    }

    function getNodeName(node) {
        if (!node) return "";
        return node.properties?.["device.description"] || node.description || node.name || "Unknown Device";
    }

    function getNodeSubDesc(node) {
        if (!node) return "";
        if (node.isStream) {
            return node.properties?.["media.name"] || node.properties?.["window.title"] || node.properties?.["media.role"] || "Audio Stream";
        }
        return node.name || "Unknown";
    }

    function getNodeAppName(node) {
        if (!node) return "";
        return node.properties?.["application.name"] || node.properties?.["application.process.binary"] || node.description || "Unknown App";
    }
}
