import QtQuick

// Now playing, on the desktop.
//
// Unlike the popup this one is not transient: it is where the transport lives
// while the desktop is visible, so it stays for as long as there is a player.
// The card itself is shared with the popup — one component, so the two cannot
// drift apart the way three separate copies of the same player did.
MediaCard {
    id: root

    // The rail's measure, which this card is the widest member of.
    property int railWidth: 440

    width: root.railWidth
    height: 116
}
