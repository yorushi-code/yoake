pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Every network in range, and the means to get onto one.
//
// The shell could read a signal strength and flip the radio, which is enough to
// describe a link and not enough to change one: joining a network the machine
// had never seen meant a terminal. This is the missing half -- the list, the
// key, the forgetting -- and it is built on `nmcli` rather than on the
// Networking service because that service has no way to hand over a pre-shared
// key, which is the one step the whole task turns on.
//
// Nothing here runs in the background. NetworkManager's picture of the air is
// re-read only while something is looking at it, and the airwaves are only
// scanned when a person asks: this card has one radio, and scanning while
// associated stalls the association it is already holding -- which was this
// shell's "network keeps dropping" bug.
Singleton {
    id: root

    // {ssid, signal 0..100, security, freq, band, known, active}
    property var networks: []
    // {name, iface, connected} for every wired device NetworkManager can see.
    property var wired: []
    // Saved wireless profiles, in range or not: {ssid, uuid}.
    property var saved: []

    property string iface: ""
    property string activeSsid: ""
    property string activeIp: ""
    property string activeGateway: ""
    property bool wifiEnabled: true

    // True only while a scan process is actually running, because the panel
    // draws a moving mark from it and a permanent animation costs a slice of a
    // core for as long as it turns.
    property bool scanning: false
    // The SSID a connect is in flight for, so the row that asked can show the
    // wait rather than the whole panel going busy.
    property string connecting: ""
    // Set when NetworkManager came back asking for a key: the row that was
    // refused opens its field, instead of the panel guessing which networks
    // need one.
    property string needsPassword: ""
    property string lastError: ""

    readonly property var activeNetwork: {
        for (const n of root.networks) {
            if (n.active) return n;
        }
        return null;
    }
    // -1 rather than 0: no association at all and an associated link reporting
    // nothing are different states, and only one of them is worth an icon.
    readonly property int activeSignal: root.activeNetwork ? root.activeNetwork.signal : -1
    readonly property string activeBand: root.activeNetwork ? root.activeNetwork.band : ""
    readonly property string activeSecurity: root.activeNetwork ? root.activeNetwork.security : ""

    // Bytes per second, from the interface's own counters. NetworkManager
    // reports a negotiated link rate, which is what the radio could do rather
    // than what it is doing.
    property real rxRate: 0
    property real txRate: 0

    // ── Reading ──
    //
    // Watchers rather than a flag: the panel and the control-centre page can
    // both be up, and the second one closing must not stop the first one's
    // refresh.
    property int watchers: 0

    function hold() {
        root.watchers += 1;
        root.refresh();
    }

    function release() {
        root.watchers = Math.max(0, root.watchers - 1);
        if (root.watchers === 0) root._autoScanned = false;
    }

    function refresh() {
        pollProc.running = true;
    }

    // Asked for by a person, never by a timer. Blocking form on purpose: the
    // list nmcli prints when the scan ends is the result, so there is no window
    // where the indicator has stopped and the rows have not changed yet.
    function rescan() {
        if (root.scanning) return;
        root.scanning = true;
        scanProc.running = true;
    }

    // ── Changing ──
    //
    // Every function below is destructive to a live link, so all of them are
    // reached from a click and none from a binding or a timer.

    function connect(ssid, password) {
        if (!ssid) return;
        const key = password || "";
        root.lastError = "";
        root.connecting = ssid;
        root._request = ssid;
        root._requestHadKey = key !== "";
        if (root.isSaved(ssid)) {
            // A saved profile carries the key, the band preference and any
            // static address with it, and `device wifi connect` would build a
            // second profile beside it rather than use it. A key typed against
            // a profile that already exists is a correction, so it replaces the
            // stored one before the profile is raised.
            if (key !== "") {
                actProc.command = ["nmcli", "connection", "modify", "id", ssid,
                                   "wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", key];
                root._thenUp = ssid;
            } else {
                actProc.command = ["nmcli", "connection", "up", "id", ssid];
                root._thenUp = "";
            }
        } else {
            root._thenUp = "";
            actProc.command = key !== ""
                ? ["nmcli", "device", "wifi", "connect", ssid, "password", key]
                : ["nmcli", "device", "wifi", "connect", ssid];
        }
        actProc.running = true;
    }

    function disconnect() {
        if (root.iface === "") return;
        root._request = root.activeSsid;
        root._requestHadKey = false;
        root._thenUp = "";
        actProc.command = ["nmcli", "device", "disconnect", root.iface];
        actProc.running = true;
    }

    function forget(ssid) {
        if (!ssid || !root.isSaved(ssid)) return;
        root._request = ssid;
        root._requestHadKey = false;
        root._thenUp = "";
        if (root.needsPassword === ssid) root.needsPassword = "";
        actProc.command = ["nmcli", "connection", "delete", "id", ssid];
        actProc.running = true;
    }

    function setWifiEnabled(on) {
        // Optimistic, so the switch moves under the finger; the next poll
        // corrects it if NetworkManager refused.
        root.wifiEnabled = on;
        root._request = "";
        root._thenUp = "";
        actProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        actProc.running = true;
    }

    // ── Naming things ──

    function isSaved(ssid) {
        for (const s of root.saved) {
            if (s.ssid === ssid) return true;
        }
        return false;
    }

    // Which band you are on is the difference between "slow" and "far from the
    // router", and a dual-band router answers to one name on both.
    function bandOf(freq) {
        if (freq >= 5900) return "6 ГГц";
        if (freq >= 4900) return "5 ГГц";
        if (freq > 0) return "2,4 ГГц";
        return "";
    }

    function securityLabel(security) {
        return security === "" ? "Открытая" : security;
    }

    function rateText(bytesPerSecond) {
        const kb = bytesPerSecond / 1024;
        if (kb < 1) return "0 КБ/с";
        if (kb < 1024) return Math.round(kb) + " КБ/с";
        return (kb / 1024).toFixed(1) + " МБ/с";
    }

    // ── Parsing ──

    // `nmcli -t` escapes a literal colon inside a value as `\:` and a backslash
    // as `\\`. Splitting on every colon turns an SSID like "Cafe: free" into two
    // fields and shifts every column after it, so the signal of one network
    // ends up printed against the name of another.
    function _fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line.charAt(i);
            if (c === "\\" && i + 1 < line.length) {
                i += 1;
                cur += line.charAt(i);
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }
        out.push(cur);
        return out;
    }

    readonly property var _markers: ["#if", "#radio", "#dev", "#known", "#wifi", "#ip", "#rate"]

    // One process per refresh rather than six. These are six questions with one
    // answer between them, and six processes on a four-second tick is most of
    // what "do not poll in the background" was written about.
    //
    // `$1` is nmcli's rescan mode: `no` for the tick, `yes` for the button.
    readonly property string _script:
        "i=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}');"
        + "echo '#if'; echo \"$i\";"
        + "echo '#radio'; nmcli -t -f WIFI general status 2>/dev/null;"
        + "echo '#dev'; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null;"
        + "echo '#known'; nmcli -t -f NAME,UUID,TYPE connection show 2>/dev/null;"
        + "echo '#wifi'; [ -n \"$i\" ] && nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,FREQ device wifi list --rescan \"$1\" 2>/dev/null;"
        + "echo '#ip'; [ -n \"$i\" ] && nmcli -t -f IP4.ADDRESS,IP4.GATEWAY device show \"$i\" 2>/dev/null;"
        + "echo '#rate'; [ -n \"$i\" ] && cat /sys/class/net/\"$i\"/statistics/rx_bytes /sys/class/net/\"$i\"/statistics/tx_bytes 2>/dev/null;"
        + "exit 0"

    function _absorb(text) {
        const sections = ({});
        let key = "";
        for (const line of String(text).split("\n")) {
            // Matched whole, not by a leading hash: a connection profile is
            // free to be called "#work".
            if (root._markers.indexOf(line) >= 0) {
                key = line.substring(1);
                sections[key] = [];
                continue;
            }
            if (key === "" || line === "") continue;
            sections[key].push(line);
        }

        root.iface = (sections["if"] || [""])[0] || "";
        root.wifiEnabled = (sections["radio"] || [])[0] === "enabled";

        // The name of the profile that is up, which is what the machine is
        // actually on. The scan list's own in-use mark agrees with it, but only
        // once the scan is fresher than the connection.
        let ssid = "";
        const wired = [];
        for (const line of sections["dev"] || []) {
            const f = root._fields(line);
            if (f.length < 4) continue;
            const connected = f[2].indexOf("connected") === 0;
            if (f[1] === "wifi" && connected) ssid = f[3];
            if (f[1] === "ethernet") {
                wired.push({
                    name: f[3] !== "" ? f[3] : f[0],
                    iface: f[0],
                    connected: connected
                });
            }
        }
        root.activeSsid = ssid;
        root.wired = wired;

        // The profile's name, not its `802-11-wireless.ssid`. Reading the real
        // SSID costs one nmcli call per saved profile; every tool that creates
        // one -- nmcli, GNOME, this panel -- names it after the network, and a
        // profile renamed by hand costs a "known" badge rather than a
        // connection.
        const saved = [];
        for (const line of sections["known"] || []) {
            const f = root._fields(line);
            if (f.length < 3 || f[2] !== "802-11-wireless") continue;
            saved.push({ ssid: f[0], uuid: f[1] });
        }
        root.saved = saved;

        const nets = [];
        const seen = ({});
        for (const line of sections["wifi"] || []) {
            const f = root._fields(line);
            if (f.length < 5) continue;
            // A hidden network prints an empty name, and a row nobody can name
            // is a row nobody can click.
            if (f[1] === "") continue;
            const freq = parseInt(f[4]) || 0;
            const entry = {
                ssid: f[1],
                signal: parseInt(f[2]) || 0,
                security: f[3] || "",
                freq: freq,
                band: root.bandOf(freq),
                active: f[0].indexOf("*") >= 0,
                known: false
            };
            // A dual-band router answers on two radios under one name, and two
            // rows for one network is a list that lies about how many there
            // are. The band shown is the one being used, or the strongest.
            const had = seen[entry.ssid];
            if (!had) {
                seen[entry.ssid] = entry;
                nets.push(entry);
            } else if (entry.active || (!had.active && entry.signal > had.signal)) {
                had.active = had.active || entry.active;
                had.signal = entry.signal;
                had.freq = entry.freq;
                had.band = entry.band;
            }
        }
        for (const n of nets) {
            n.known = root.isSaved(n.ssid);
            if (n.ssid === root.activeSsid) n.active = true;
        }
        nets.sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) || b.signal - a.signal);
        root.networks = nets;

        let ip = "";
        let gw = "";
        for (const line of sections["ip"] || []) {
            const f = root._fields(line);
            if (f.length < 2) continue;
            // The mask belongs to the subnet, not to this machine, and the
            // header has one line to say where it is.
            if (f[0].indexOf("IP4.ADDRESS") === 0 && ip === "") ip = f[1].split("/")[0];
            if (f[0] === "IP4.GATEWAY") gw = f[1];
        }
        root.activeIp = ip;
        root.activeGateway = gw;

        root._sample(sections["rate"] || []);

        // The one scan that is not a person's doing. An empty list is useless,
        // and with nothing associated there is no association for the scan to
        // stall -- which is the whole of why scanning is otherwise refused.
        if (!root._autoScanned && root.watchers > 0 && root.wifiEnabled
                && root.activeSsid === "" && nets.length === 0) {
            root._autoScanned = true;
            root.rescan();
        }
    }

    property bool _autoScanned: false
    property real _rxBytes: -1
    property real _txBytes: -1
    property real _sampledAt: 0

    function _sample(lines) {
        const rx = parseFloat(lines[0]);
        const tx = parseFloat(lines[1]);
        const now = Date.now();
        if (isNaN(rx) || isNaN(tx)) {
            root._rxBytes = -1;
            root.rxRate = 0;
            root.txRate = 0;
            return;
        }
        // A counter reset -- the interface came back, or the panel was shut
        // long enough for the reading to mean nothing -- would otherwise print
        // as a burst of traffic that never happened.
        const dt = (now - root._sampledAt) / 1000;
        if (root._rxBytes >= 0 && dt > 0 && dt < 30 && rx >= root._rxBytes) {
            root.rxRate = (rx - root._rxBytes) / dt;
            root.txRate = Math.max(0, (tx - root._txBytes) / dt);
        }
        root._rxBytes = rx;
        root._txBytes = tx;
        root._sampledAt = now;
    }

    // What the last action was about, kept past the process that ran it: the
    // failure arrives on a different stream from the exit, and by then
    // `connecting` has already been cleared.
    property string _request: ""
    property bool _requestHadKey: false
    // The second half of a two-step connect: nmcli cannot change a key and
    // raise the profile in one call.
    property string _thenUp: ""

    function _fail(text) {
        // nmcli prefixes a real failure with "Error:" and prints warnings
        // without it, so anything else on this stream is not a failure.
        let line = "";
        for (const l of String(text).split("\n")) {
            if (l.indexOf("Error:") >= 0) { line = l; break; }
        }
        if (line === "") return;
        if (line.indexOf("Secrets were required") >= 0) {
            root.needsPassword = root._request;
            root.lastError = root._requestHadKey ? "Неверный пароль" : "Нужен пароль";
        } else if (line.indexOf("802-11-wireless-security.psk") >= 0) {
            root.lastError = "Пароль слишком короткий";
        } else if (line.indexOf("No network with SSID") >= 0) {
            root.lastError = "Сеть не найдена";
        } else {
            root.lastError = line.replace("Error: ", "").trim();
        }
    }

    property Process _pollProc: Process {
        id: pollProc
        command: ["sh", "-c", root._script, "net", "no"]
        stdout: StdioCollector {
            onStreamFinished: root._absorb(text)
        }
    }

    property Process _scanProc: Process {
        id: scanProc
        command: ["sh", "-c", root._script, "net", "yes"]
        stdout: StdioCollector {
            onStreamFinished: root._absorb(text)
        }
        onExited: root.scanning = false
    }

    property Process _actProc: Process {
        id: actProc
        stderr: StdioCollector {
            onStreamFinished: root._fail(text)
        }
        onExited: code => {
            if (code === 0 && root._thenUp !== "") {
                const ssid = root._thenUp;
                root._thenUp = "";
                actProc.command = ["nmcli", "connection", "up", "id", ssid];
                actProc.running = true;
                return;
            }
            root._thenUp = "";
            root.connecting = "";
            if (code === 0) {
                root.lastError = "";
                root.needsPassword = "";
            }
            root.refresh();
            // An address arrives after the link does, so the first reading
            // after a connect is of a network with no address on it.
            settle.restart();
        }
    }

    property Timer _settle: Timer {
        id: settle
        interval: 1600
        onTriggered: root.refresh()
    }

    property Timer _poll: Timer {
        // Slow on purpose. Nothing here changes on its own except the traffic
        // counters, and this is the rate at which those are read as well.
        interval: 4000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }
}
