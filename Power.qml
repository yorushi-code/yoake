pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Power profiles, session actions, and what the pack knows about itself, in one
// place, so the control centre, the bar's menus and the power panel can't drift
// apart on what "Sleep" runs.
//
// The profile list is read from power-profiles-daemon rather than hardcoded:
// which profiles exist depends on the platform driver, and on this machine the
// driver is `placeholder`, which offers only balanced and power-saver — a
// hardcoded "performance" entry would be a button that silently fails.
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

    // What picking it actually costs. Three words in a row are three words; a
    // panel has the width to say which one makes the fan audible, and that is
    // the only thing anyone wants to know before choosing.
    function detailFor(profile) {
        if (profile === "power-saver") return "Частоты ниже, батарея дольше";
        if (profile === "performance") return "Полная частота, шум и нагрев";
        if (profile === "balanced") return "Разгоняется под нагрузкой";
        return "";
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

    // ── What the pack knows about itself ──
    //
    // UPower publishes charge and an estimate and stops there. The numbers that
    // say whether a battery is *worn out* — what it is drawing at this instant,
    // how much of its design capacity it still holds, how many cycles it has
    // been through — never reach the bus, so they are read where the kernel
    // puts them.
    //
    // Read on demand rather than polled. A panel that is shut is not looking at
    // any of this, and a timer that keeps asking anyway is the same mistake as
    // an animation that keeps running.
    readonly property string batteryDir: "/sys/class/power_supply/BAT0/"

    // Microwatts, as the kernel reports them. Negative until a reading lands,
    // because "not read yet" and "genuinely zero" are different states and the
    // second is the normal one for a full battery on mains.
    property real drawMicrowatts: -1
    // Microwatt-hours. The pair is the whole of the health figure.
    property real energyFull: 0
    property real energyFullDesign: 0
    property int cycleCount: -1
    // Percent the firmware stops charging at. -1 where the platform has no such
    // knob, which is most of them.
    property int chargeLimit: -1

    readonly property bool drawKnown: root.drawMicrowatts >= 0
    readonly property real drawWatts: root.drawMicrowatts / 1000000
    readonly property real health: root.energyFullDesign > 0
        ? root.energyFull / root.energyFullDesign
        : 0
    readonly property bool healthKnown: root.energyFullDesign > 0

    // Wh, for a line that has to say what the percentage is a percentage *of*.
    readonly property real capacityWh: root.energyFull / 1000000
    readonly property real designWh: root.energyFullDesign / 1000000

    function _number(raw) {
        const n = parseInt(String(raw).trim());
        return isNaN(n) ? -1 : n;
    }

    // Packs that report charge rather than energy have no power_now at all and
    // expose current_now instead; that is a shape of battery, not a fault, so
    // none of these log when they are missing.
    FileView {
        id: drawFile
        path: root.batteryDir + "power_now"
        printErrors: false
        onLoaded: root.drawMicrowatts = root._number(drawFile.text())
        onLoadFailed: root.drawMicrowatts = -1
    }

    FileView {
        id: fullFile
        path: root.batteryDir + "energy_full"
        printErrors: false
        onLoaded: root.energyFull = Math.max(0, root._number(fullFile.text()))
        onLoadFailed: root.energyFull = 0
    }

    FileView {
        id: designFile
        path: root.batteryDir + "energy_full_design"
        printErrors: false
        onLoaded: root.energyFullDesign = Math.max(0, root._number(designFile.text()))
        onLoadFailed: root.energyFullDesign = 0
    }

    FileView {
        id: cyclesFile
        path: root.batteryDir + "cycle_count"
        printErrors: false
        onLoaded: root.cycleCount = root._number(cyclesFile.text())
        onLoadFailed: root.cycleCount = -1
    }

    FileView {
        id: limitFile
        path: root.batteryDir + "charge_control_end_threshold"
        printErrors: false
        onLoaded: root.chargeLimit = root._number(limitFile.text())
        onLoadFailed: root.chargeLimit = -1
    }

    // All five rather than only the two that move. Each is four bytes out of
    // the page cache, and splitting them into "static" and "live" would be a
    // claim about firmware that the next laptop breaks — a charge limit set
    // from a BIOS menu is exactly the kind of thing that changes behind us.
    function refreshBattery() {
        drawFile.reload();
        fullFile.reload();
        designFile.reload();
        cyclesFile.reload();
        limitFile.reload();
    }

    // One spelling of "2 ч 15 мин". The bar chip, its hover card and the panel
    // each grew their own, and the three disagreed about whether to print a
    // zero hour.
    function duration(seconds) {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? h + " ч " + m + " мин" : m + " мин";
    }

    function run(cmd) {
        sessionProc.command = cmd;
        sessionProc.running = true;
    }

    // The shell has its own lock surface, and it is already what the idle chain
    // reaches for. Spawning swaylock here meant the same session locked to two
    // different screens depending on which control asked for it.
    function lock() { LockState.lock(); }
    function suspend() { root.run(["systemctl", "suspend"]); }
    function reboot() { root.run(["systemctl", "reboot"]); }
    function powerOff() { root.run(["systemctl", "poweroff"]); }
    function logOut() { Niri.action("quit", "--skip-confirmation"); }

    Component.onCompleted: {
        root.refresh();
        root.refreshBattery();
    }
}
