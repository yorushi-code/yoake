pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// No official Quickshell module exists for niri (unlike Hyprland), so we
// shell out to `niri msg --json event-stream` and parse its line-delimited
// JSON ourselves. WorkspacesChanged carries the full list (sent once at
// startup, and again if workspaces are added/removed); WorkspaceActivated
// is the lightweight per-focus-change event and only carries {id, focused}
// - the sibling is_active/is_focused flags have to be patched by hand.
Singleton {
    id: root

    property var workspaces: []
    property var windows: []
    property bool overviewOpen: false

    function workspacesFor(output) {
        return root.workspaces
            .filter(w => w.output === output)
            .sort((a, b) => a.idx - b.idx);
    }

    function focusedWorkspaceOn(output) {
        return root.workspaces.find(w => w.output === output && w.is_active) || null;
    }

    // How much of this output the active workspace's tiles cover, 0..1.
    //
    // Mere window presence used to be the signal, and it was wrong in the one
    // way that matters: niri's default column is half the output width, so a
    // single terminal froze the video wallpaper across the other half of the
    // screen. This build reports no tile position (tile_pos_in_workspace_view
    // is null even for the visible workspace), so summed tile area is the
    // honest measure available — overlapping tiles only ever push the estimate
    // up, which errs towards pausing rather than towards decoding unseen video.
    function desktopCoverageOn(output) {
        if (root.overviewOpen) return 0;
        const ws = root.focusedWorkspaceOn(output);
        if (!ws) return 0;
        let area = 0;
        for (const s of Quickshell.screens) {
            if (s.name === output) {
                area = s.width * s.height;
                break;
            }
        }
        if (area <= 0) return 1;
        let covered = 0;
        for (const w of root.windows) {
            if (w.workspace_id !== ws.id) continue;
            const size = w.layout ? (w.layout.tile_size || w.layout.window_size) : null;
            // A window we cannot measure is still a window; assuming it fills
            // the output is the safe direction.
            if (!size) return 1;
            covered += size[0] * size[1];
        }
        return Math.min(1, covered / area);
    }

    // Not 1.0: gaps and rounding leave a few unlit pixels around a genuinely
    // full column, and a sliver of wallpaper is not worth playing video for.
    readonly property real coverageLimit: 0.85

    function desktopVisibleOn(output) {
        return root.desktopCoverageOn(output) < root.coverageLimit;
    }

    // Anything that moves the user's attention elsewhere. A menu left hanging
    // after the user has alt-tabbed away reads as the shell being stuck, and
    // the popup has no focus of its own to lose under niri.
    signal attentionMoved()

    property var focusedWindowId: null

    readonly property var focusedWindow: {
        if (root.focusedWindowId === null) return null;
        return root.windows.find(w => w.id === root.focusedWindowId) || null;
    }

    // Focus *leaving* every window is exactly what happens when the bar grabs
    // keyboard focus to open a menu, so a null id must not count as attention
    // moving — otherwise every menu would close on the frame it opened.
    function _applyWindowFocusChanged(payload) {
        const id = (payload && payload.id !== undefined) ? payload.id : null;
        if (id === null) return;
        if (id === root.focusedWindowId) return;
        root.focusedWindowId = id;
        root.attentionMoved();
    }

    function _applyWorkspacesChanged(payload) {
        root.workspaces = payload.workspaces;
    }

    function _applyWorkspaceActivated(payload) {
        const target = root.workspaces.find(w => w.id === payload.id);
        if (!target) return;
        root.attentionMoved();
        const output = target.output;
        // Copies rather than in-place edits, and only for rows that actually
        // change. ScriptModel diffs this list to decide which delegates to
        // update, and a mutated object compares equal to itself, so the pill
        // would keep rendering the old focus state.
        root.workspaces = root.workspaces.map(w => {
            const active = (w.output === output) ? (w.id === payload.id) : w.is_active;
            const focused = payload.focused ? (w.id === payload.id) : w.is_focused;
            if (active === w.is_active && focused === w.is_focused) return w;
            return Object.assign({}, w, { is_active: active, is_focused: focused });
        });
    }

    function _applyWindowOpenedOrChanged(payload) {
        const win = payload.window;
        const idx = root.windows.findIndex(w => w.id === win.id);
        if (idx >= 0) {
            const next = root.windows.slice();
            next[idx] = win;
            root.windows = next;
        } else {
            root.windows = [...root.windows, win];
        }
    }

    // Tiles resize with no window opening, closing or changing focus — dragging
    // a column edge is exactly the case where desktop coverage moves and
    // nothing else does.
    function _applyWindowLayoutsChanged(payload) {
        const changes = (payload && payload.changes) || [];
        if (changes.length === 0) return;
        const byId = {};
        for (const c of changes) byId[c[0]] = c[1];
        root.windows = root.windows.map(w =>
            byId[w.id] ? Object.assign({}, w, { layout: byId[w.id] }) : w);
    }

    // Supervised because losing this stream is silent and unrecoverable: the
    // workspace pills would keep rendering the last state forever with no hint
    // that they had stopped updating. niri replays WorkspacesChanged and
    // WindowsChanged on every new connection, so a reconnect resyncs by itself
    // without an extra `niri msg` query.
    property ManagedProcess eventStream: ManagedProcess {
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                if (!line) return;
                let evt;
                try {
                    evt = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (evt.WorkspacesChanged) root._applyWorkspacesChanged(evt.WorkspacesChanged);
                else if (evt.WorkspaceActivated) root._applyWorkspaceActivated(evt.WorkspaceActivated);
                else if (evt.WindowsChanged) root.windows = evt.WindowsChanged.windows;
                else if (evt.WindowOpenedOrChanged) root._applyWindowOpenedOrChanged(evt.WindowOpenedOrChanged);
                else if (evt.WindowClosed) root.windows = root.windows.filter(w => w.id !== evt.WindowClosed.id);
                else if (evt.WindowFocusChanged) root._applyWindowFocusChanged(evt.WindowFocusChanged);
                else if (evt.WindowLayoutsChanged) root._applyWindowLayoutsChanged(evt.WindowLayoutsChanged);
                else if (evt.OverviewOpenedOrClosed) root.overviewOpen = evt.OverviewOpenedOrClosed.is_open;
            }
        }
    }

    property Process actionRunner: Process {}

    function action(...args) {
        actionRunner.command = ["niri", "msg", "action", ...args];
        actionRunner.running = true;
    }

    function focusWorkspace(idx) {
        root.action("focus-workspace", String(idx));
    }
}
