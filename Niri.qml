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

    // Whether the wallpaper is actually being looked at on this output. niri is
    // a scrolling tiler, so any window on the active workspace covers the
    // background layer completely — this shell already assumes as much (the
    // desktop clock sits below windows and only shows on empty space). Used to
    // stop paying for video wallpaper playback nobody can see; this build of
    // niri reports no is_fullscreen flag, so window presence is the signal.
    function desktopVisibleOn(output) {
        if (root.overviewOpen) return true;
        const ws = root.focusedWorkspaceOn(output);
        if (!ws) return true;
        return !root.windows.some(w => w.workspace_id === ws.id);
    }

    // Anything that moves the user's attention elsewhere. A menu left hanging
    // after the user has alt-tabbed away reads as the shell being stuck, and
    // the popup has no focus of its own to lose under niri.
    signal attentionMoved()

    property var focusedWindowId: null

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
