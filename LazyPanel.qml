import QtQuick
import Quickshell

// A panel that only exists while it is being used.
//
// Instantiated eagerly, the four popup panels cost about 41 MB of the shell's
// resident set — measured by removing them from shell.qml — and in a typical
// session most are never opened at all. Loading is asynchronous so opening one
// does not stutter the frame it was asked for.
//
// The linger is the point of the wrapper: destroying the panel on the falling
// edge of `shown` cut its own exit animation off after two frames, so the
// close read as a snap. The loader outlives the request by long enough for the
// panel to finish leaving.
//
// Panels must animate against their own "created and settled" state rather
// than the toggle directly — see `armed` in ControlCenter and friends. A
// lazily created panel is born with its toggle already true, which gives an
// entry animation nothing to animate from.
LazyLoader {
    id: root

    property bool shown: false
    // Comfortably past the longest exit animation plus the unmap delay the
    // panels use, so the window is already gone when the object is destroyed.
    property int lingerMs: Theme.animSlow + 200

    activeAsync: root.shown || linger.running

    onShownChanged: {
        if (root.shown) linger.stop();
        else linger.restart();
    }

    property Timer _linger: Timer {
        id: linger
        interval: root.lingerMs
    }
}
