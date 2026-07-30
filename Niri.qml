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

    // Whether the background layer on this output is certainly hidden.
    //
    // Two things this build of niri does not report make the obvious approaches
    // impossible: `tile_pos_in_workspace_view` is null even for the focused
    // workspace, so where a column sits in the viewport is unknowable, and
    // there is no `is_fullscreen` flag on a window at all.
    //
    // The previous answer summed every tile's area on the workspace and called
    // 85% covered. That counts columns scrolled far off screen, so four open
    // columns saturated it: the wallpaper froze on any busy workspace and
    // started again the moment you switched to an emptier one — which is
    // exactly how it looked from the outside, and it was this, not a decoder
    // fault.
    //
    // What is left is one certain signal: a tile whose size is the whole
    // output. niri gives a fullscreen window exactly that, gaps and bar strip
    // included, and nothing else gets it. Everything short of fullscreen keeps
    // playing, because niri's gaps and screen-edge padding leave real wallpaper
    // showing under even a maximised column, and a frozen strip there is a far
    // worse bug than the few percent of CPU that decoding costs.
    function desktopOccludedOn(output) {
        if (root.overviewOpen) return false;
        const ws = root.focusedWorkspaceOn(output);
        if (!ws) return false;
        let width = 0;
        let height = 0;
        for (const s of Quickshell.screens) {
            if (s.name === output) {
                width = s.width;
                height = s.height;
                break;
            }
        }
        if (width <= 0 || height <= 0) return false;
        for (const w of root.windows) {
            if (w.workspace_id !== ws.id) continue;
            const size = w.layout ? (w.layout.tile_size || w.layout.window_size) : null;
            if (!size) continue;
            // A pixel of slack: these are floats and the compositor rounds.
            if (size[0] >= width - 1 && size[1] >= height - 1) return true;
        }
        return false;
    }

    function desktopVisibleOn(output) {
        return !root.desktopOccludedOn(output);
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
