import QtQuick
import Quickshell.Widgets

// One of the bar's floating glass islands.
//
// Also the single place the frosted backing's sample position is worked out.
// That used to be spelled out per-island, and the centre one had it wrong:
// `bar.width / 2 - width / 2` forgets that the bar window is itself inset by
// barMargin, so the blur behind the clock was sampled 8px to the left of where
// the island actually sat. Deriving it from the island's own x removes the
// chance of getting it wrong again.
Item {
    id: root

    default property alias content: inner.data
    // Right-click on the island's own surface (not on a widget inside it).
    property var menuModel: ShellActions.shellMenu
    // Distinguishes the three islands on this output from each other and from
    // the same islands on another monitor.
    property string islandName: ""
    property var barWindow: null
    readonly property string menuId: Menus.idFor(root.barWindow, "island/" + root.islandName)
    property real padding: 14
    // Centre island only: the accent glow breathes with the bass. Implemented
    // here rather than passed in as a child, since a glow anchored to the
    // island cannot live in the content item — that one is sized *by* its
    // children, and an anchors.fill child would make the width depend on
    // itself.
    property bool pulseWithAudio: false

    height: Theme.barHeight
    // Driven by the content's natural size. `inner` must therefore never be
    // anchored to this item's width, or the two define each other and Qt
    // reports a binding loop (and picks an arbitrary width).
    implicitWidth: inner.width + root.padding * 2

    readonly property real bass: (root.pulseWithAudio && Cava.active) ? Cava.bass : 0

    // Always-on accent glow marks the clock as the bar's focal point, and
    // pulses with the music: the three lowest cava bands (bass) drive its
    // intensity and spread, so the island visibly breathes to the beat.
    // The measurement that produced Glow's fixed spread was taken here: 4.4
    // points of a core for one island pulsing on geometry instead of opacity.
    //
    // No Behaviors. Two 90ms animations restarting on every cava frame never
    // finished, and each restart re-rendered the blur. Cava.bass is already
    // damped on its falling edge.
    Glow {
        anchors.fill: glass
        radius: glass.radius
        reach: 28
        // Scaled by hierarchy: this glow is decoration, and decoration is the
        // first thing that should step back when someone has been sitting in
        // one window for a while. It stays a beat -- the bass still drives it
        // -- but a quieter one.
        amount: root.pulseWithAudio
            ? Math.min(0.85, 0.18 + root.bass * 0.62) * Theme.chromeEmphasis
            : 0
    }

    // The same object the panels and the cards are made of. It also puts the
    // bar on its own rung of the elevation ladder, which Theme has described
    // since the ladder was written and nothing had ever used: the bar was
    // casting a panel-sized shadow, so it sat as far off the desktop as the
    // sheets that open above it.
    Surface {
        id: glass
        anchors.fill: parent
        radius: Theme.pill(height)
        elevation: "bar"
        screenX: Theme.barMargin + root.x
        screenY: Theme.barMargin
    }

    // Behind the content, so widgets inside keep their own right-click
    // handlers and only bare glass falls through to the shell menu.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        enabled: root.menuModel.length > 0
        onClicked: Menus.toggle(root.menuId)
    }

    Item {
        id: inner
        x: root.padding
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: parent.height
    }

    ActionMenu {
        menuId: root.menuId
        anchorItem: root
        model: Menus.isOpen(root.menuId) ? root.menuModel : []
        open: Menus.isOpen(root.menuId)
    }
}
