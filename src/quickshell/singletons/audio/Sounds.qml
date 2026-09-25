pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string soundsDir: Caching.qsDir + "/../assets/sounds/"

    // Every effect is played as its own short-lived pw-play stream. Naming the
    // streams lets the volume panel leave them out of the app list (they would
    // flash in and out) and show one permanent "Interface sounds" row instead.
    readonly property string streamName: "Yoake interface sounds"
    readonly property var pwPlayProps: ["-P", "{ application.name = \"" + streamName + "\" media.role = \"Event\" }"]

    property var activeHandles: ({})
    property int nextHandleId: 1

    property var _pendingQueue: []

    property var generalSettings: Config.getSetting("general", { "muteSfx": false, "sfxVolume": 100 })
    readonly property bool isMuted: generalSettings && generalSettings.muteSfx === true
    readonly property real masterVolume: {
        let v = (generalSettings && generalSettings.sfxVolume !== undefined) ? Number(generalSettings.sfxVolume) : 100;
        return Math.max(0.0, Math.min(1.0, v / 100.0));
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.generalSettings = Config.getSetting("general", { "muteSfx": false, "sfxVolume": 100 });
        }
    }

    readonly property int volumePercent: Math.round(root.masterVolume * 100)

    // persist=false only previews (while a slider is being dragged); the
    // settings file is written once, when the drag ends.
    function setVolumePercent(pct, persist) {
        let v = Math.max(0, Math.min(100, Math.round(pct)));
        root.generalSettings = Object.assign({}, root.generalSettings || {}, { "sfxVolume": v });
        if (persist !== false) Config.setSetting("general.sfxVolume", v);
    }

    function setMuted(muted) {
        root.generalSettings = Object.assign({}, root.generalSettings || {}, { "muteSfx": muted === true });
        Config.setSetting("general.muteSfx", muted === true);
    }

    function play(filePath, volume, duration, overrideSfxBlock) {
        if ((root.isMuted || root.masterVolume <= 0.0) && overrideSfxBlock !== true) return;
        if (!filePath || filePath.trim() === "") return;
        let vol = volume === undefined ? 1.0 : Math.max(0.0, Math.min(2.0, volume));
        let finalVol = overrideSfxBlock === true ? vol : (vol * root.masterVolume);
        let dur = duration === undefined ? 0 : duration;
        root._pendingQueue.push({ filePath: filePath, volume: finalVol, duration: dur });
        Qt.callLater(root._drainQueue);
    }

    function playSfx(filename, volume, duration, overrideSfxBlock) {
        root.play(root.soundsDir + filename, volume, duration, overrideSfxBlock);
    }

    function _drainQueue() {
        let q = root._pendingQueue;
        root._pendingQueue = [];
        for (let i = 0; i < q.length; i++) {
            root._reallyPlay(q[i].filePath, q[i].volume, q[i].duration);
        }
    }

    function _reallyPlay(filePath, vol, dur) {
        let cleanPath = filePath.startsWith("file://") ? filePath.substring(7) : filePath;
        let cmd = ["pw-play", "--volume=" + vol.toString()].concat(root.pwPlayProps, [cleanPath]);
        try {
            Quickshell.execDetached(dur > 0 ? ["timeout", String(dur)].concat(cmd) : cmd);
        } catch(e) {}
    }

    Component {
        id: stoppableProcess
        Process {
            property int handleId: -1
            stdinEnabled: false
        }
    }

    function playUntilStopped(filenameOrPath, volume, loop, overrideSfxBlock) {
        if ((root.isMuted || root.masterVolume <= 0.0) && overrideSfxBlock !== true) return -1;
        let vol = Math.max(0.0, Math.min(2.0, volume === undefined ? 1.0 : volume));
        let finalVol = overrideSfxBlock === true ? vol : (vol * root.masterVolume);
        let doLoop = loop === true;
        let cleanPath = (filenameOrPath.startsWith("/") || filenameOrPath.startsWith("file://")) ?
            (filenameOrPath.startsWith("file://") ? filenameOrPath.substring(7) : filenameOrPath) :
            (root.soundsDir + filenameOrPath);
        let playCmd = ["pw-play", "--volume=" + finalVol].concat(root.pwPlayProps, [cleanPath]);

        let id = root.nextHandleId++;

        // The loop needs a shell; the command reaches it as positional
        // arguments ("$@"), so no path or property string is re-quoted.
        let command = doLoop
            ? ["sh", "-c", "trap 'kill $CPID 2>/dev/null; exit' TERM; while :; do \"$@\" & CPID=$!; wait $CPID; done", "sh"].concat(playCmd)
            : playCmd;

        let proc = stoppableProcess.createObject(root, {
            "command": command,
            "handleId": id
        });
        proc.running = true;

        proc.exited.connect(function() {
            delete root.activeHandles[id];
            proc.destroy();
        });

        root.activeHandles[id] = proc;
        return id;
    }

    function stopSfx(handleId) {
        let entry = root.activeHandles[handleId];
        if (!entry) return;
        entry.running = false;
        delete root.activeHandles[handleId];
    }

    function stopAllSfx() {
        for (let id in root.activeHandles) {
            root.activeHandles[id].running = false;
        }
        root.activeHandles = ({});
    }
}
