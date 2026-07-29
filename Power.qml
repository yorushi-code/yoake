pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Power profiles and session actions in one place, so the control centre and
// the bar's right-click menus can't drift apart on what "Sleep" runs.
//
// The profile list is read from power-profiles-daemon rather than hardcoded:
// which profiles exist depends on the platform driver, and on this machine the
// driver is `placeholder`, which offers only balanced and power-saver — a
// hardcoded "performance" entry would be an button that silently fails.
Singleton {
    id: root

    property var profiles: []
    property string activeProfile: ""
    readonly property bool available: profiles.length > 0

    function glyphFor(profile) {
        if (profile === "power-saver") return Glyphs.leaf;
        if (profile === "performance") return Glyphs.flash;
        return Glyphs.speedometer;
    }

    function labelFor(profile) {
        if (profile === "power-saver") return "Экономия энергии";
        if (profile === "performance") return "Производительность";
        if (profile === "balanced") return "Сбалансированный";
        return profile;
    }

    // `powerprofilesctl list` marks the active profile with a leading asterisk
    // and indents each name as `<name>:`; anything else in the block is a
    // driver detail line we don't care about.
    Process {
        id: listProc
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                let active = "";
                for (const raw of text.split("\n")) {
                    const m = raw.match(/^\s*(\*?)\s*([a-z-]+):\s*$/);
                    if (!m) continue;
                    names.push(m[2]);
                    if (m[1] === "*") active = m[2];
                }
                root.profiles = names;
                root.activeProfile = active;
            }
        }
    }

    Process { id: setProc }
    Process { id: sessionProc }

    function refresh() {
        listProc.running = true;
    }

    function setProfile(profile) {
        if (profile === root.activeProfile) return;
        setProc.command = ["powerprofilesctl", "set", profile];
        setProc.running = true;
        // Optimistic so the menu's check mark moves immediately; refresh()
        // below corrects it if the daemon refused.
        root.activeProfile = profile;
        confirm.restart();
    }

    Timer {
        id: confirm
        interval: 400
        onTriggered: root.refresh()
    }

    function run(cmd) {
        sessionProc.command = cmd;
        sessionProc.running = true;
    }

    function lock() { root.run(["swaylock"]); }
    function suspend() { root.run(["systemctl", "suspend"]); }
    function reboot() { root.run(["systemctl", "reboot"]); }
    function powerOff() { root.run(["systemctl", "poweroff"]); }
    function logOut() { Niri.action("quit", "--skip-confirmation"); }

    Component.onCompleted: root.refresh()
}
