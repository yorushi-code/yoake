pragma Singleton
import QtQuick
import Quickshell

// mihomo's RESTful controller, spoken to directly.
//
// Everything here is plain HTTP against a loopback port and needs no help from
// Python. Routing it through yworld's CLI meant spawning an interpreter —
// 150-250ms — for a request that completes in under a millisecond, so the node
// list visibly lagged every click. Python keeps only what genuinely cannot be
// done from QML: subscription download with the user-agent probing that is the
// only way to get a provider's real node list, share-link parsing, YAML
// assembly, and starting or stopping the process.
//
// No secret is configured on the controller and it binds to 127.0.0.1 only, so
// there is no authentication header to carry. Loopback is not by itself an
// access control — mihomo accepts any Origin unless told otherwise, so the
// generated config refuses them all (see config_build.py). None of the requests
// below send an Origin header, so that costs this file nothing.
Singleton {
    id: root

    readonly property string base: "http://127.0.0.1:9090"

    // Whether the last request got an answer at all. The panel binds its
    // "tunnel is up" state to this instead of polling for it.
    property bool reachable: false

    // Where latency is measured from. A generate_204 endpoint rather than a
    // real page: the response is empty, so the number is round-trip time and
    // not the size of somebody's homepage.
    readonly property string probeUrl: "http://www.gstatic.com/generate_204"

    function _request(method, path, body, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;

            // Status 0 is "nothing answered", which is the ordinary state of a
            // tunnel that is down — not a failure worth surfacing as text.
            if (xhr.status === 0) {
                root.reachable = false;
                if (done) done(null, "controller unreachable");
                return;
            }
            root.reachable = true;

            let parsed = null;
            if (xhr.responseText) {
                try {
                    parsed = JSON.parse(xhr.responseText);
                } catch (e) {
                    parsed = null;
                }
            }
            if (xhr.status >= 400) {
                if (done) done(parsed, (parsed && parsed.message) || ("HTTP " + xhr.status));
                return;
            }
            if (done) done(parsed, "");
        };
        xhr.open(method, root.base + path);
        if (body === null || body === undefined) {
            xhr.send();
            return;
        }
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(body));
    }

    function version(done) {
        root._request("GET", "/version", null, done);
    }

    function proxies(done) {
        root._request("GET", "/proxies", null, done);
    }

    function select(group, node, done) {
        root._request("PUT", "/proxies/" + encodeURIComponent(group), { name: node }, done);
    }

    // The whole group in one request. Probing node by node is fifty round trips
    // that each hold a socket open for the timeout, and mihomo already
    // parallelises this internally.
    function groupDelay(group, timeout, done) {
        root._request("GET", "/group/" + encodeURIComponent(group) + "/delay"
            + "?timeout=" + timeout + "&url=" + encodeURIComponent(root.probeUrl),
            null, done);
    }

    function nodeDelay(node, timeout, done) {
        root._request("GET", "/proxies/" + encodeURIComponent(node) + "/delay"
            + "?timeout=" + timeout + "&url=" + encodeURIComponent(root.probeUrl),
            null, done);
    }

    // Established connections keep flowing through whichever node they were
    // opened on, so without this a switch looks like it did not take.
    function closeConnections(done) {
        root._request("DELETE", "/connections", null, done);
    }

    // Режим правил живёт в running config, отдельной точки под него нет.
    function configs(done) {
        root._request("GET", "/configs", null, done);
    }

    function setMode(mode, done) {
        root._request("PATCH", "/configs", { mode: mode }, done);
    }
}
