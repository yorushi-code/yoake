import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Everything raised in this shell is one of these.
//
// There were three separate readings of the same idea: the bar islands had
// frosted glass, a specular wash and an outer hairline; the panels had glass
// and a hairline but no wash; the dashboard cards had a flat fill and neither.
// Each was defensible alone, and together they were the reason the shell read
// as a set of neighbours rather than one object. Depth, edge and highlight are
// not per-widget decisions -- they are what tells the eye which surfaces belong
// to the same thing.
//
// The elevation names say where a surface sits, not how much blur to use: the
// bar sits on the desktop, panels sit above the bar, modal things sit above
// those, and a `flat` surface sits *inside* another one and must not repeat
// its depth -- a dashboard full of shadowed cards is a pile of boxes.
Item {
    id: root

    property int radius: Theme.radiusCard
    // "flat" | "bar" | "panel" | "modal"
    property string elevation: "panel"
    // Frosted glass samples the wallpaper, which costs a blur; a card sitting
    // on a panel that is already glass wants a plain tint instead.
    // Whether this surface *wants* glass. Whether it gets it is also the
    // mood's call: under load the shell drops the frost everywhere at once,
    // which is both the cheapest thing it can do for the machine and the most
    // visible way of saying it noticed.
    property bool glass: true
    readonly property bool _frosted: root.glass && Theme.frost
    property bool specular: true
    // Panels carry small body text over arbitrary wallpaper detail and need a
    // denser frost than the bar, which only has to keep glyphs legible.
    property real tintOpacity: 0.52
    property bool stroke: true

    // The fill under a non-glass surface, and the tint over a glass one.
    //
    // This was one value for both jobs, and its default -- six per cent ink --
    // is right for a card sitting on a panel and is not a surface at all for a
    // panel sitting on a wallpaper. So turning the frost off did not give a
    // plainly-coloured shell, it gave a transparent one: the dashboard was
    // legible only because of the blur behind it, and there is nothing under
    // the blur holding it up.
    //
    // That matters beyond taste, because `Theme.frost` is a switch Perception
    // throws by itself when the machine is short of frames -- so the one moment
    // the shell most needs to be readable was the moment it dissolved. Nobody
    // saw it because nobody had run the shell with the frost off.
    //
    // A raised surface therefore has a ground of its own, and the ground is
    // *opaque*. Not a high veil rung: at 0.88 a panel laid over a terminal
    // still shows the terminal, which is the one thing a painted surface exists
    // to stop, and the result is glass without the blur — the worse half of
    // both materials.
    //
    // What keeps an opaque panel from reading as a foreign strip laid on the
    // desktop is that `crust` is derived from the wallpaper's own palette. The
    // belonging comes from the colour, not from being able to see through it.
    // That is the whole argument for this mode: transparency is one way to look
    // like part of the picture and it is the expensive one.
    //
    // A flat surface keeps the tint: it is sitting on something already.
    property color fill: root._raised
        ? Theme.crust
        : Qt.alpha(Theme.text, Theme.fillSubtle)

    // Where on screen the glass should sample from. Only the surface's owner
    // knows where it ended up.
    property real screenX: 0
    property real screenY: 0

    default property alias content: body.data

    readonly property bool _raised: root.elevation !== "flat"
    readonly property real _blur: root.elevation === "bar" ? Theme.elevBarBlur
        : root.elevation === "modal" ? Theme.elevModalBlur : Theme.elevPanelBlur
    readonly property real _spread: root.elevation === "bar" ? Theme.elevBarSpread
        : root.elevation === "modal" ? Theme.elevModalSpread : Theme.elevPanelSpread

    RectangularShadow {
        anchors.fill: parent
        visible: root._raised
        radius: root.radius
        color: Theme.shadowColor
        blur: root._blur
        spread: root._spread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    FrostedBackground {
        anchors.fill: parent
        visible: root._frosted
        radius: root.radius
        screenX: root.screenX
        screenY: root.screenY
        tintOpacity: root.tintOpacity
    }

    Rectangle {
        anchors.fill: parent
        visible: !root._frosted
        radius: root.radius
        color: root.fill
    }

    // The light falls from above, on every surface, at the same angle -- on
    // every *glass* surface. Without the blur underneath it there is nothing
    // for the light to be catching on, and a wash laid over a painted fill is
    // not a highlight, it is a lighter patch: the gradient's far end shows as a
    // visible band across the middle of every island, because eight bits of
    // white fading to nothing over 34 pixels cannot help doing that.
    //
    // The flat material draws its edge with the stroke below instead, which is
    // what a painted surface has always used and does not depend on there being
    // a light source the shell cannot actually simulate.
    ClippingRectangle {
        anchors.fill: parent
        visible: root.specular && root._frosted
        radius: root.radius
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

    // Outside the backing, so the stroke is not cut in half by its own clip.
    // Without it a glass surface dissolves into a bright wallpaper: the frost
    // is a tint over whatever is behind it, and over a pale video frame there
    // is nothing left to separate the shell from the desktop.
    Rectangle {
        anchors.fill: parent
        visible: root.stroke
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, root._raised ? Theme.strokeFirm : Theme.strokeSoft)
    }

    Item {
        id: body
        anchors.fill: parent
    }
}
