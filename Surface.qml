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
    property bool glass: true
    property bool specular: true
    // Panels carry small body text over arbitrary wallpaper detail and need a
    // denser frost than the bar, which only has to keep glyphs legible.
    property real tintOpacity: 0.52
    property bool stroke: true
    // The fill under a non-glass surface, and the tint over a glass one.
    property color fill: Qt.alpha(Theme.text, Theme.fillSubtle)

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
        visible: root.glass
        radius: root.radius
        screenX: root.screenX
        screenY: root.screenY
        tintOpacity: root.tintOpacity
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.glass
        radius: root.radius
        color: root.fill
    }

    // The light falls from above, on every surface, at the same angle. This is
    // the single detail that does most of the work: without it a rounded fill
    // is a shape, and with it the same shape is an object with a lit edge.
    ClippingRectangle {
        anchors.fill: parent
        visible: root.specular
        radius: root.radius
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.55
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha("white", root.glass ? 0.13 : 0.07) }
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
