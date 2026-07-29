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
// previous one, and anything that should cancel a menu (a click on the
// desktop, Escape, a triggered item, focus moving to a window) calls
// closeAll(). The focus grab stays enabled on top of this as a bonus path.
//
// Keys are strings, not object identities. A menu behind a LazyLoader is a
// different object every time it is shown, and `current === theObject` cannot
// survive that — worse, the loader's `active` is driven *by* isOpen(), so the
// object does not exist at the moment the answer is needed.
Singleton {
    id: root

    property string current: ""
    readonly property bool anyOpen: root.current !== ""

    function open(id) {
        if (id) root.current = id;
    }

    function close(id) {
        if (root.current === id) root.current = "";
    }

    function closeAll() {
        root.current = "";
    }

    function isOpen(id) {
        return id !== "" && root.current === id;
    }

    // Every call site spelled this out as if/else; a menu that toggles itself
    // is the only behaviour any of them wanted.
    function toggle(id) {
        root.current = (root.current === id) ? "" : id;
    }

    // Scopes a name to the output whose bar owns it. Without this the same
    // widget on two monitors shares one key and both menus open together.
    function idFor(barWindow, name) {
        const output = (barWindow && barWindow.barScreen) ? barWindow.barScreen.name : "?";
        return output + "/" + name;
    }
}
