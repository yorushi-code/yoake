import QtQuick

// The grace a panel's entrance waits for its surface to reach the screen.
//
// Every panel in this shell wrote this out itself, and every one of them wrote
// the same bug into it. The shape was: a panel is built lazily, so it is born
// with its toggle already true and an entrance bound straight to the toggle has
// no `false` to animate from — hence a flag that turns on a frame later, and
// animations bound to `toggle && armed` instead.
//
// That flag was set once, at construction, and never cleared. `LazyPanel`
// lingers after a close so the exit can finish, which means **every open after
// the first** reused a live object whose flag was already true. `open` went
// true on the same frame the window was asked to map, and the entire arrival
// played into a surface the compositor had not put on screen yet.
//
// Measured at 60fps on the dashboard: a cold open showed four frames of fade, a
// warm reopen showed none — one frame from bare desktop to fully painted panel.
// The cold open only looked better by accident, because building the panel took
// long enough to cover the map. Thirteen panels, one bug, thirteen copies.
//
// So it re-arms on every request, and it is one object rather than a pattern to
// be re-typed correctly. A caller writes:
//
//     PanelArm { id: arm; requested: Toggles.audioPanelOpen }
//     readonly property bool open: arm.open
//
// and binds its entrance to `open` as before.
QtObject {
    id: root

    // The toggle that asks for the panel.
    property bool requested: false

    // What entrances bind to: asked for, *and* on screen.
    readonly property bool open: root.requested && root.armed

    property bool armed: false

    onRequestedChanged: {
        if (root.requested) {
            // Disarm first. A reopen that skips this is the original bug: the
            // flag is still true from last time and there is nothing to
            // animate from.
            root.armed = false;
            tick.restart();
        } else {
            // The exit plays from `open` going false on its own. Disarming
            // underneath it would cut it off.
            tick.stop();
        }
    }

    // A panel built while its toggle is already true never sees the change
    // above, because the binding was evaluated before this object existed.
    Component.onCompleted: if (root.requested) tick.restart()

    property Timer _tick: Timer {
        id: tick
        interval: Theme.animMap
        onTriggered: root.armed = true
    }
}
