import QtQuick

// Now playing, on the desktop.
//
// Unlike the popup this one is not transient: it is where the transport lives
// while the desktop is visible, so it stays for as long as there is a player.
// The card itself is shared with the popup — one component, so the two cannot
// drift apart the way three separate copies of the same player did.
MediaCard {
    id: root

    // Where on screen the glass should sample the wallpaper. Set by the
    // surface, which is the only thing that knows where the widget ended up.
    width: 440
    height: 116
}
