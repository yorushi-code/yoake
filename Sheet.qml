import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// The panel a bar chip opens.
//
// Two things here are not in any other surface of this shell, and both were
// measured off the reference rather than invented.
//
// **It resolves rather than arrives.** For the whole of its entrance the
// content is blurred and pulls into focus, while the sheet grows from about
// half size with its top edge pinned under the bar. A panel that slides in is a
// thing being moved into place by a program; a panel that comes into focus is a
// thing that was always there and is now being looked at. It costs one layer
// for the length of the entrance and the layer is switched off the moment it
// lands -- an FBO left standing is a permanent tax.
//
// **It leaves outward.** Measured on the reference: within four frames of the
// close, the changed area is wider than the panel itself. So it scales *up* and
// dissolves instead of shrinking back into the chip it came from. That reads as
// the thing ceasing to exist, where a shrink reads as it crawling back into a
// hole, and the second is a lie about where panels live.
Item {
    id: root

    property bool shown: false
    // Which edge stays put while it grows. The sheet belongs to the chip that
    // opened it, and it must not appear to come from anywhere else.
    // "left" | "right" | "centre"
    property string align: "left"
    property color accent: Theme.accent
    // Something to lay under the surface, blurred and darkened -- album art for
    // the player. Empty for the rest, which get the plain painted ground.
    property string backdrop: ""

    default property alias content: body.data

    signal closeRequested()

    // 0 while shut, 1 when settled. Everything below reads this rather than
    // `shown`, so the entrance and the exit are one description.
    readonly property real progress: root._drive
    property real _drive: 0

    readonly property bool _busy: root._drive > 0.001 && root._drive < 0.999

    Behavior on _drive {
        NumberAnimation {
            duration: root.shown ? Theme.animSlow : Theme.animExit
            easing.type: Easing.Bezier
            easing.bezierCurve: root.shown ? Theme.easeEmphasized : Theme.easeExit
        }
    }

    onShownChanged: root._drive = root.shown ? 1 : 0
    Component.onCompleted: if (root.shown) root._drive = 1

    opacity: root._drive
    visible: root._drive > 0.002

    // Grows in on the way in and past itself on the way out.
    scale: root.shown ? (0.55 + 0.45 * root._drive) : (1 + 0.14 * (1 - root._drive))
    transformOrigin: root.align === "right" ? Item.TopRight
        : (root.align === "centre" ? Item.Top : Item.TopLeft)

    RectangularShadow {
        anchors.fill: parent
        radius: Theme.radiusSheet
        color: Theme.shadowColor
        blur: Theme.elevModalBlur
        spread: Theme.elevModalSpread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSheet
        color: Theme.crust
    }

    // The panel belongs to what it is about. Heavily blurred and pushed down
    // under a veil, so it is a ground and never something anyone tries to look
    // at -- the art is already on the panel at full size.
    ClippingRectangle {
        anchors.fill: parent
        visible: root.backdrop !== ""
        radius: Theme.radiusSheet
        color: "transparent"

        Image {
            id: art
            anchors.fill: parent
            source: root.backdrop
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 320
            // Hidden but rendered: MultiEffect needs a live texture, and an
            // item that is merely invisible does not have one.
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: art
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            opacity: Theme.veilThin
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Theme.crust, Theme.veilSoft)
        }
    }

    Item {
        id: body
        anchors.fill: parent

        // Only while it is moving. See above: a standing layer is an FBO the
        // compositor pays for on every frame for the rest of the session.
        layer.enabled: root._busy
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 40
            blur: 1 - root._drive
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSheet
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.text, Theme.strokeSoft)
    }

    // ── The rule the chip was wearing, continued ──
    //
    // `accent` has been on this component from the beginning and was read by
    // nothing: six panels compute their domain — `Theme.tone("net")`, `"bt"`,
    // `"audio"`, `"power"`, `"vpn"`, and the album's own colour for the player —
    // hand it over, and it was dropped on the floor. Recorded as F1 with the
    // conclusion that deleting the property was the wrong repair, and this is
    // the right one: **use it.**
    //
    // `Theme` says what it is for, in as many words: a fixed hue per domain
    // means "a chip in the bar and the panel it opens are visibly the same
    // subject". That was true of the chip and had never been true of the panel.
    //
    // A hairline, because that is the vocabulary the bar already speaks — `Chip`
    // carries the domain as a rule *under* the mark, on a shared baseline, and
    // this is that rule continued along the top edge of what the mark opened.
    // The panel hangs from the bar it came out of, so the join is where they
    // meet. Inset past the corner radius so it is a rule and not a bezel, and
    // riding the entrance so it arrives with the sheet rather than on it.
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.radiusSheet * 2
        height: 2
        radius: height / 2
        color: root.accent
        opacity: root._drive
    }
}
