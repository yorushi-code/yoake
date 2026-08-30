pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
// MihomoApi is registered in the root qmldir, which a subdirectory is not
// part of. Same line as Palette.qml.
import "../"

// VPN state for the shell.
//
// Split along the only line that matters: live control goes straight to the
// controller over HTTP (see MihomoApi), and Python is left with the work that
// has no business being rewritten in QML — subscription fetching, the
// user-agent probing that is the only way to get a provider's real node list,
// share-link parsing, config assembly, and owning the process. That code is
// the most fragile in the project and reimplementing it here would have been
// the largest possible mistake; putting a node switch behind it would have
// been a smaller one, but still a mistake.
//
// Every CLI call returns one JSON object and exits 0, errors included, so
// there is no exit code to interpret separately from the payload.
Singleton {
    id: root

    readonly property string cliDir: Quickshell.env("HOME") + "/yworld"

    // ── process state, from Python ──
    property bool running: false
    property string active: ""
    property string lastError: ""
    // Which of the three cores is carrying this, and whether that core can
    // take over system routing at all. Xray cannot: it tunnels only what is
    // pointed at its listener port, and a panel that showed it as a tunnel
    // like the other two would be lying about where the traffic goes.
    property string core: "mihomo"
    property bool tunCapable: true
    property bool tunActive: false
    // Another TUN client owning the default route. The worst failure mode
    // there is: both tunnels stay up and look healthy, and the one that lost
    // simply carries nothing.
    property string conflict: ""
    property bool conflictCanStop: false
    // A start blocks for up to about 7.5s while the controller is polled, so
    // the UI has to be able to say so.
    property bool busy: false
    property var subscriptions: []

    // ── live state, from the controller ──
    readonly property bool controllerUp: MihomoApi.reachable
    // Every proxy's type by name, groups and nodes alike. A group's member list
    // mixes real servers with the built-ins, and only the type tells them apart.
    property var proxyTypes: ({})

    // A member of a group that is not a server: DIRECT, REJECT and the nested
    // groups. These are always usable and never measured, so counting them
    // among the nodes that might be down is counting the wrong thing.
    function isSelectable(name) {
        const t = root.proxyTypes[name] || "";
        return t === "Selector" || t === "URLTest" || t === "Fallback"
            || t === "Direct" || t === "Reject" || t === "Compatible"
            || t === "LoadBalance" || t === "Pass";
    }

    // [{ name, type, now, nodes }] for every selectable group.
    property var groups: []
    readonly property string primaryGroup: "PROXY"
    // node name -> delay in ms, or null when the probe failed.
    property var delays: ({})
    property bool probing: false

    // Bytes per second, from the controller's streaming endpoint.
    property real upSpeed: 0
    property real downSpeed: 0

    // Where traffic actually comes out, and whether it comes out through the
    // tunnel at all. Deliberately not part of start: the probe costs up to
    // twelve seconds and needs the rule-providers mihomo is still downloading
    // in its first moments, so asking then was both slow and wrong.
    property var egress: null
    property var egressDirect: null
    property bool leaking: false
    property bool checking: false

    // Set by the panel while it is on screen. The egress probe costs up to
    // twelve seconds and exists to answer a question nobody is asking when
    // nothing is displaying the answer, so it stays behind this. The shell
    // this came from read the same intent off its Toggles singleton.
    property bool watched: false

    // Switching node without this leaves every established connection on the
    // old one, which reads as the switch not having worked.
    property bool resetOnSwitch: true

    function groupNamed(name) {
        for (const g of root.groups) {
            if (g.name === name) return g;
        }
        return null;
    }

    // Members that are not nodes: the two built-ins, and any nested group.
    // A group has no latency of its own, and recording the probe's silence as a
    // failure painted AUTO red — the one row worth picking when every node
    // beside it is red.
    function measurable(name) {
        return name !== "DIRECT" && name !== "REJECT" && !root.groupNamed(name);
    }

    readonly property var primary: root.groupNamed(root.primaryGroup)
    readonly property string currentNode: root.primary ? (root.primary.now || "") : ""
    readonly property var currentDelay: root.delays[root.currentNode]

    function formatSpeed(bytes) {
        if (bytes < 1024) return Math.round(bytes) + " Б/с";
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + " КБ/с";
        return (bytes / 1048576).toFixed(1) + " МБ/с";
    }

    function formatBytes(bytes) {
        if (!bytes) return "0 Б";
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + " КБ";
        if (bytes < 1024 * 1024 * 1024) return (bytes / 1048576).toFixed(0) + " МБ";
        return (bytes / 1073741824).toFixed(1) + " ГБ";
    }

    // ── controller-driven ──

    function refreshNodes() {
        MihomoApi.proxies((data, err) => {
            if (err || !data || !data.proxies) {
                root.groups = [];
                return;
            }
            const out = [];
            const types = {};
            for (const name in data.proxies) {
                const entry = data.proxies[name];
                types[name] = entry.type || "";
                // Only groups the user can act on. Every individual node is in
                // this map too, and GLOBAL lists all of them a second time.
                if (entry.type !== "Selector" && entry.type !== "URLTest"
                    && entry.type !== "Fallback") continue;
                out.push({
                    name: name,
                    type: entry.type,
                    now: entry.now || "",
                    nodes: entry.all || []
                });
            }
            // Primary first, then alphabetically: the panel opens on the group
            // that actually carries traffic.
            out.sort((a, b) => {
                if (a.name === root.primaryGroup) return -1;
                if (b.name === root.primaryGroup) return 1;
                return a.name.localeCompare(b.name);
            });
            root.proxyTypes = types;
            root.groups = out;
        });
    }

    function select(group, node) {
        // Applied optimistically: the controller switch is immediate, and a
        // round trip before the checkmark moves reads as an unresponsive list.
        root.groups = root.groups.map(g =>
            g.name === group ? Object.assign({}, g, { now: node }) : g);

        MihomoApi.select(group, node, (data, err) => {
            if (err) {
                root.lastError = err;
                root.refreshNodes();
                return;
            }
            if (root.resetOnSwitch) MihomoApi.closeConnections(null);
            // The old reading belongs to the old node's route, and the panel is
            // now showing it as this node's latency.
            root.egress = null;
        });
    }

    function probeDelays(group) {
        if (root.probing) return;
        const name = group || root.primaryGroup;
        const target = root.groupNamed(name);
        if (!target) return;

        root.probing = true;
        // Generous, because the group is probed in parallel: this is one 5s
        // wait for the slowest node, not five seconds per node. At 3s several
        // perfectly usable nodes were coming back as dead.
        MihomoApi.groupDelay(name, 5000, (data, err) => {
            if (err) {
                root.probing = false;
                root.lastError = err;
                return;
            }
            // Nodes that failed the probe are absent from the reply rather than
            // reported as zero, so a miss has to be written down explicitly or
            // the previous reading would silently stand in for it.
            const next = Object.assign({}, root.delays);
            const missing = [];
            for (const node of target.nodes) {
                if (!root.measurable(node)) continue;
                if (data && data[node] !== undefined) next[node] = data[node];
                else missing.push(node);
            }
            root.delays = next;
            if (missing.length === 0) {
                root.probing = false;
                return;
            }
            root._probeEach(missing);
        });
    }

    // What a group probe left out, asked for one node at a time.
    //
    // sing-box answers a group probe for the group's own members — AUTO,
    // DIRECT — and leaves the nodes themselves out of it, so on that core
    // every row stayed blank. A node the group did report as missing is worth
    // asking about individually anyway: absent from a group reply means "no
    // measurement", which is not the same as "dead".
    function _probeEach(names) {
        const next = Object.assign({}, root.delays);
        let pending = names.length;
        for (const node of names) {
            MihomoApi.nodeDelay(node, 5000, (data, err) => {
                next[node] = (!err && data && data.delay !== undefined) ? data.delay : null;
                pending -= 1;
                if (pending > 0) return;
                root.delays = next;
                root.probing = false;
            });
        }
    }

    // Probes only what has never been measured. Opening the panel should show
    // latencies without being asked, but re-probing a list the user is already
    // looking at costs three seconds of controller work to redraw the same
    // numbers.
    function probeDelaysIfStale(group) {
        const target = root.groupNamed(group || root.primaryGroup);
        if (!target) return;
        for (const node of target.nodes) {
            if (!root.measurable(node)) continue;
            if (root.delays[node] === undefined) {
                root.probeDelays(group);
                return;
            }
        }
    }

    function resetConnections() {
        MihomoApi.closeConnections(null);
    }

    // ── process-driven ──
    // One Process per concern rather than a queue: these are independent, and
    // a slow `start` must not hold up a `status` refresh behind it.

    function _run(proc, args) {
        proc.command = ["python3", "-m", "yworld.cli"].concat(args);
        proc.workingDirectory = root.cliDir;
        proc.running = true;
    }

    function refresh() {
        root._run(statusProc, ["status"]);
        root._run(subsProc, ["subs"]);
    }

    function start(name) {
        root.busy = true;
        root.lastError = "";
        root._run(startProc, name ? ["start", name] : ["start"]);
    }

    function stop() {
        root.busy = true;
        root._run(stopProc, ["stop"]);
    }

    // Proof rather than inference: the request is forced through mihomo's own
    // listener, so it cannot succeed unless mihomo carried it.
    function check() {
        if (root.checking || !root.running) return;
        root.checking = true;
        root._run(checkProc, ["check"]);
    }

    function stopRival() {
        root.busy = true;
        root._run(actionProc, ["rival-stop"]);
    }

    function addSubscription(name, url, userAgent) {
        root.busy = true;
        root.lastError = "";
        root._run(actionProc, userAgent
            ? ["sub-add", name, url, userAgent]
            : ["sub-add", name, url]);
    }

    function removeSubscription(name) {
        root.busy = true;
        root._run(actionProc, ["sub-del", name]);
    }

    // Which core a subscription runs on. Recorded, not applied: the config for
    // the new core is built on the next connect, so a subscription that is
    // running is reconnected here and one that is not is left alone.
    function setCore(name, core) {
        root.busy = true;
        root.lastError = "";
        root._pendingRestart = (name === root.active && root.running) ? name : "";
        root._run(coreProc, ["core", name, core]);
    }

    property string _pendingRestart: ""

    function refreshSubscription(name) {
        root.busy = true;
        root.lastError = "";
        root._run(actionProc, ["sub-refresh", name]);
    }

    function _parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return { error: "cli returned unparseable output" };
        }
    }

    property Process statusProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text);
                root.running = j.running === true;
                root.active = j.active || "";
                root.core = j.core || "mihomo";
                root.tunCapable = j.tun_capable !== false;
                root.tunActive = j.tun === true;
                root.conflict = j.conflict || "";
                root.conflictCanStop = j.conflict_can_stop === true;
                if (j.error) root.lastError = j.error;
                // A running tunnel is the only case where asking the controller
                // anything can succeed.
                if (root.running) root.refreshNodes();
                else root.groups = [];
                // Opening the panel is usually too early to ask: the tunnel's
                // state is only known once this reply lands.
                if (root.running && root.watched && root.egress === null) root.check();
            }
        }
    }

    property Process subsProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text);
                if (j.subscriptions) root.subscriptions = j.subscriptions;
            }
        }
    }

    // Recording the core is a settings change, and the tunnel only picks it up
    // on the next connect — so the one that was running is brought back here.
    property Process coreProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text);
                root.busy = false;
                root.lastError = j.error || "";
                const restart = root._pendingRestart;
                root._pendingRestart = "";
                if (!j.error && restart !== "") root.start(restart);
                else root.refresh();
            }
        }
    }

    property Process startProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text);
                root.busy = false;
                root.lastError = j.error || "";
                // A provider having a bad day answers with one placeholder node
                // and the config is rebuilt around it. Silent, this looks like
                // the node list broke by itself.
                if (!j.error && j.previous_nodes > 1 && j.nodes < j.previous_nodes / 2) {
                    root.lastError = "У «" + j.active + "» было " + j.previous_nodes
                        + " нод, провайдер отдал " + j.nodes;
                }
                // The other way a node list shrinks, and the one the provider
                // has nothing to do with: this core cannot carry those nodes.
                if (!j.error && (j.dropped || []).length > 0) {
                    const names = j.dropped.map(d => d.name).join(", ");
                    root.lastError = j.core + " не умеет " + j.dropped.length
                        + " нод из этой подписки: " + names;
                }
                root.egress = null;
                root.refresh();
            }
        }
    }

    property Process stopProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.lastError = "";
                root.groups = [];
                root.delays = ({});
                root.egress = null;
                root.egressDirect = null;
                root.leaking = false;
                MihomoApi.reachable = false;
                root.refresh();
            }
        }
    }

    property Process checkProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text);
                root.checking = false;
                if (j.error) return;
                root.egress = j.egress || null;
                root.egressDirect = j.direct || null;
                root.leaking = j.leaking === true;
            }
        }
    }

    // Anything that changes state and then wants the whole picture re-read.
    property Process actionProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root._parse(text);
                root.busy = false;
                root.lastError = j.error || "";
                root.refresh();
            }
        }
    }

    // ── traffic ──
    // The controller streams a line of JSON per second. A subscription rather
    // than a poll: nothing is asked for and nothing is spent while the tunnel
    // is down. curl rather than XMLHttpRequest because this is the one endpoint
    // that never completes, and SplitParser already handles line-delimited
    // streams for the niri event feed.
    //
    // Gated on this as well as on the tunnel, because the stream has to be
    // restartable. Assigning to `running` directly would replace the binding,
    // and the stream would then never stop when the tunnel does.
    property bool trafficWanted: true

    property Process trafficProc: Process {
        running: root.running && root.controllerUp && root.trafficWanted
        command: ["curl", "-sN", "--max-time", "0", MihomoApi.base + "/traffic"]
        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                try {
                    const j = JSON.parse(line);
                    root.upSpeed = j.up || 0;
                    root.downSpeed = j.down || 0;
                } catch (e) {
                    // A partial line at stream start is not worth reporting.
                }
            }
        }
        onExited: {
            root.upSpeed = 0;
            root.downSpeed = 0;
            if (!root.running) return;
            // This stream ends when mihomo does, and nothing else here notices a
            // daemon that died on its own — without this the shell went on
            // reporting a tunnel that had been gone for hours.
            root.trafficWanted = false;
            root.refresh();
            trafficRetry.restart();
        }
    }

    property Timer _trafficRetry: Timer {
        id: trafficRetry
        interval: 2000
        onTriggered: root.trafficWanted = true
    }

    // Refreshed when something could plausibly have changed rather than on a
    // timer: a poll would keep spawning a Python interpreter forever to learn
    // that nothing moved.
    Component.onCompleted: root.refresh()

    // The shell this came from had a Toggles singleton that announced which
    // panel was open, and this listened for its own. There is no equivalent
    // here, and inventing one to hold a single subscription would be worse
    // than the alternative: VpnPopup calls refresh() and check() itself when
    // it opens. Same moment, one less thing that has to exist.
}
