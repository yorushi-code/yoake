pragma Singleton
import Quickshell

// Registry of the one menu that may be open at a time.
//
// Menus are PopupWindows anchored to bar widgets. Quickshell's `grabFocus`
// does close a popup when its focus grab breaks, but a layer-shell bar under
// niri only holds keyboard focus while it is being interacted with, so the
// grab is not something correctness can rest on — it was observed dropping
// immediately for a popup opened without a preceding click.
//
// So dismissal is driven from here instead: opening any menu closes the
// previous one, and anything that should cancel a menu (a click elsewhere in
// the bar, Escape, a triggered item) calls closeAll(). The focus grab stays
// enabled on top of this as a bonus path for clicks on the desktop.
Singleton {
    id: root

    // Opaque token identifying the open menu — each menu passes its own `this`.
    property var current: null
    readonly property bool anyOpen: current !== null

    function open(token) {
        if (root.current === token) return;
        root.current = token;
    }

    function close(token) {
        if (root.current === token) root.current = null;
    }

    function closeAll() {
        root.current = null;
    }

    function isOpen(token) {
        return root.current === token;
    }
}
