import QtQuick
import QtQuick.Effects
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

    RectangularShadow {
        anchors.fill: glass
        radius: glass.radius
        color: Theme.shadowColor
        blur: Theme.shadowBlur
        spread: Theme.shadowSpread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    // Always-on accent glow marks the clock as the bar's focal point, and
    // pulses with the music: the three lowest cava bands (bass) drive its
    // intensity and spread, so the island visibly breathes to the beat.
    RectangularShadow {
        anchors.fill: glass
        radius: glass.radius
        visible: root.pulseWithAudio
        color: Theme.accent
        blur: 28
        // Fixed. Spread is geometry, and changing it re-rasterises a blur-28
        // shadow -- thirty times a second, in the always-visible bar. Measured
        // at 4.4 points of a core against the same glow pulsing on opacity
        // alone, which the scene graph changes for free and which carries the
        // beat just as visibly.
        spread: 1
        opacity: Math.min(0.85, 0.18 + root.bass * 0.62)
        offset: Qt.vector2d(0, 0)
        // No Behaviors. Two 90ms animations restarting on every cava frame
        // never finished, and each restart re-rendered a blur-28 shadow.
        // Cava.bass is already damped on its falling edge.
    }

    FrostedBackground {
        id: glass
        anchors.fill: parent
        radius: height / 2
        screenX: Theme.barMargin + root.x
        screenY: Theme.barMargin
    }

    // A specular band along the top curve, the way light catches the lip of a
    // real piece of glass. It is what stops the island reading as a flat
    // rounded rectangle laid on the wallpaper — and it is clipped by a
    // ClippingRectangle rather than a plain `clip: true`, which is a
    // rectangular scissor and would cut the band square across the rounded ends.
    ClippingRectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.55
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha("white", 0.13) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Drawn outside the backing so the stroke is not cut in half. Without it
    // the islands dissolve into a bright wallpaper: the frosted glass is a tint
    // over whatever is behind it, and over a pale frame of a video there is
    // nothing left to separate shell from desktop.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.14)
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
