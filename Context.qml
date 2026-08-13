pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// What the machine is being used for, in one word.
//
// Every input the shell already watches -- the player, the microphone, the
// focused window, the load, the clock -- answers a narrow question. None of
// them answers the question the shell actually needs to act on, which is what
// is going on right now. That was left to each surface to guess at, so the
// notification stack had its own idea of "busy" and nothing else had one.
//
// Only states that can be observed are derived, and the standard is high: a
// shell that goes quiet because it *thinks* you are busy is a shell that
// swallows a message while you work.
//
// This paragraph used to end "there is no `gaming`, because niri does not
// report fullscreen in its window list". That was true when it was written and
// is not true now. `Niri.desktopOccludedOn` was added later, for the wallpaper,
// and it carries the proof: niri gives a fullscreen window a tile the size of
// the whole output, gaps and bar strip included, and nothing else gets one.
// Confirmed against this machine — tiled windows report 942x1005 and 1896x1005
// against a 1920x1080 output, because the bar's 46px exclusive zone means a
// window that is not fullscreen can never reach the full height.
//
// So the observation exists, and it is `fullscreen` below. The old sentence
// survived long enough to cost a feature: two files knew half of this each and
// never met.
Singleton {
    id: root

    // ── Raw inputs, named once so nothing downstream reaches past this ──

    readonly property bool musicPlaying: Media.playing

    // A capture stream that is not the shell's own.
    //
    // The first version of this asked only whether any capture stream existed
    // and was therefore true always: cava reads the speakers' monitor to draw
    // the spectrum, so the shell is itself listening every second it runs.
    // Excluding our own analyser is precise rather than fragile -- the shell
    // spawns it and knows its name.
    //
    // Anything else that captures counts, including a screen recorder taking
    // desktop audio. That is not a false positive: a toast sliding across a
    // recording is exactly as unwelcome as one across a call.
    //
    // PwNode.properties comes back empty here, so there is no way to ask
    // whether a stream reads a microphone or a monitor. Named for what it can
    // actually tell: something is capturing.
    readonly property var ownStreams: ["cava"]
    readonly property bool capturing: {
        for (const node of Pipewire.nodes.values) {
            if (!node || !node.isStream || node.isSink) continue;
            if (root.ownStreams.indexOf(String(node.name || "")) >= 0) continue;
            return true;
        }
        return false;
    }

    // A window that has taken a whole output.
    //
    // The strongest statement about attention the machine can observe without
    // guessing: a person who gives one application the entire screen has said
    // what they want covered. Deliberately *not* in the `mode` word below — that
    // word feeds Perception's mood, and this is about interruption rather than
    // about how the shell should look.
    readonly property bool fullscreen: {
        const win = Niri.focusedWindow;
        if (!win) return false;
        const ws = Niri.workspaces.find(w => w.id === win.workspace_id);
        if (!ws) return false;
        return Niri.desktopOccludedOn(ws.output);
    }

    readonly property string focusedApp: Niri.focusedWindow && Niri.focusedWindow.app_id
        ? String(Niri.focusedWindow.app_id).toLowerCase() : ""

    // A heuristic, and named as one: matching an app id against a list is a
    // guess about intent. It is only allowed to affect what the shell shows,
    // never what it silences.
    readonly property var codingApps: [
        "kitty", "alacritty", "foot", "wezterm", "org.wezfurlong.wezterm",
        "code", "code-oss", "dev.zed.zed", "jetbrains", "neovide"
    ]
    readonly property bool coding: root.codingApps.some(a => root.focusedApp.indexOf(a) >= 0)

    // Sustained rather than instantaneous. A single sample above the line is a
    // page load; the shell should not have a mood about it.
    property bool loaded: false
    property int _hotSamples: 0

    readonly property int hour: clock.date.getHours()
    readonly property string partOfDay: {
        const h = root.hour;
        if (h < 5) return "night";
        if (h < 11) return "morning";
        if (h < 18) return "day";
        if (h < 23) return "evening";
        return "night";
    }

    // ── The one word ──
    //
    // Ordered by what should win when two are true at once: being listened to
    // outranks everything, because interrupting a call is the costliest thing
    // the shell can do.
    readonly property string mode: {
        if (LockState.locked) return "locked";
        if (root.capturing) return "meeting";
        if (root.loaded) return "loaded";
        if (root.musicPlaying) return "music";
        if (root.coding) return "coding";
        return "idle";
    }

    readonly property var modeNames: ({
        "locked": "заблокировано",
        "meeting": "идёт запись звука",
        "loaded": "машина занята",
        "music": "играет музыка",
        "coding": "работа в редакторе",
        "idle": "покой"
    })
    readonly property string modeName: root.modeNames[root.mode] || root.mode

    // Inspectable from outside, the same way idle, lock and wallpaper are.
    // A derived mode that cannot be read back is a mode nobody can debug when
    // it silences something.
    property IpcHandler handler: IpcHandler {
        target: "context"

        function state(): string {
            return "mode=" + root.mode
                + "\nmusic=" + root.musicPlaying
                + "\ncapturing=" + root.capturing
                + "\nloaded=" + root.loaded
                + "\ncoding=" + root.coding
                + "\nfullscreen=" + root.fullscreen
                + "\nfocus=" + root.focusedApp
                + "\npart=" + root.partOfDay;
        }

        function events(): string {
            return root === null ? "" : Bus.recent.map(e => e.name).join("\n");
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── Everything above is state; below is where it becomes events ──

    onModeChanged: Bus.emit("ModeChanged", { mode: root.mode })
    onPartOfDayChanged: Bus.emit("PartOfDayChanged", { part: root.partOfDay })
    onCapturingChanged: Bus.emit(root.capturing ? "CaptureStarted" : "CaptureStopped", {})

    Connections {
        target: Media
        function onPlayingChanged() {
            Bus.emit(Media.playing ? "MusicStarted" : "MusicPaused", { title: Media.title });
        }
    }

    // Three samples over the line before the shell believes it, and one under
    // to stop believing it: rising slowly and falling quickly is what keeps a
    // mode from flickering around its own threshold.
    Connections {
        target: SysInfo
        function onCpuChanged() {
            if (SysInfo.cpu > 0.75) {
                root._hotSamples = Math.min(3, root._hotSamples + 1);
            } else {
                root._hotSamples = 0;
            }
            const hot = root._hotSamples >= 3;
            if (hot !== root.loaded) {
                root.loaded = hot;
                if (hot) Bus.emit("CpuSpike", { cpu: SysInfo.cpu });
            }
        }
    }

    Connections {
        target: Notifs
        function onArrived() { Bus.emit("NotificationReceived", {}); }
    }
}
