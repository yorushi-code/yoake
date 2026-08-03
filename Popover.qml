import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// A card that opens under a bar widget on hover.
//
// The shell had one way to show more: a menu on right-click. A menu is a list
// of commands — it cannot show a battery estimate, a network name, three power
// profiles in a row, or a preview of a window. And right-click is a thing you
// have to know is there.
//
// This is the other half: point at a widget and the card that belongs to it
// opens underneath, holding whatever that widget wants to show. Nothing has to
// be discovered, and closing is walking away.
//
// The delays are the whole design. Opening immediately makes the bar flicker
// as the pointer crosses it; closing immediately makes it impossible to reach
// the card, because the gap between widget and card is not hovered. So opening
// waits, and closing waits longer and is cancelled by the card itself being
// entered.
Item {
    id: root

    // The bar widget this belongs under.
    property Item anchorItem: null
    // Whether the pointer is on the widget. The card adds its own hover.
    property bool hovered: false
    // Content decides its own size; this is only the minimum.
    property real minWidth: 200
    property int openDelay: 240
    property int closeDelay: 220

    default property alias content: body.data

    readonly property bool shown: root.hovered || card.hovered
    property bool open: false

    onShownChanged: {
        if (root.shown) {
            closeTimer.stop();
            openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }

    Timer {
        id: openTimer
        interval: root.openDelay
        onTriggered: root.open = true
    }

    Timer {
        id: closeTimer
        interval: root.closeDelay
        onTriggered: root.open = false
    }

    // Any menu opening, or attention moving to a window, takes the card with
    // it — two floating surfaces at once is the confusion this replaces.
    Connections {
        target: Menus
        function onAnyOpenChanged() {
            if (Menus.anyOpen) {
                openTimer.stop();
                root.open = false;
            }
        }
    }

    PopupWindow {
        id: popup
        visible: root.open || card.opacity > 0.01
        implicitWidth: Math.max(root.minWidth, body.implicitWidth + 28)
        implicitHeight: body.implicitHeight + 26
        color: "transparent"

        // Window coordinates are screen coordinates here: the bar is a
        // layer-shell surface pinned to the top edge, so its origin is the
        // display's.
        readonly property point anchorPos: root.anchorItem
            ? root.anchorItem.mapToItem(null, 0, 0)
            : Qt.point(0, 0)

        anchor {
            item: root.anchorItem
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.top: 10
            // Kept on screen: a card under the rightmost widget would otherwise
            // hang off the edge of the display.
            adjustment: PopupAdjustment.SlideX
        }

        // A HoverHandler, not a MouseArea. A hoverEnabled MouseArea further up
        // the stack consumes the hover, so a parent one goes false the instant
        // the pointer reaches any control inside the card -- and the card then
        // closed exactly as the user reached to click something in it. A
        // HoverHandler sees the pointer regardless of what is above it.
        HoverHandler {
            id: cardHover
        }

        Item {
            id: card
            anchors.fill: parent
            readonly property bool hovered: cardHover.hovered

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            transformOrigin: Item.Top
            Behavior on opacity {
                NumberAnimation {
                    duration: root.open ? Theme.animNormal : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.open ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.open ? Theme.animNormal : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.open ? Theme.easeSpringBig : Theme.easeExit
                }
            }

            RectangularShadow {
                anchors.fill: glass
                radius: glass.radius
                color: Theme.shadowColor
                blur: Theme.shadowBlur
                spread: Theme.shadowSpread
                offset: Qt.vector2d(0, 4)
            }

            FrostedBackground {
                id: glass
                anchors.fill: parent
                radius: Theme.radiusLarge
                // The backing samples the wallpaper where the card actually
                // is. A PopupWindow does not report its own placement, so the
                // position is derived from the anchor the same way the
                // compositor derives it: centred under the item, below it by
                // the anchor margin.
                screenX: popup.anchorPos.x
                    + (root.anchorItem ? root.anchorItem.width : 0) / 2
                    - popup.width / 2
                screenY: popup.anchorPos.y
                    + (root.anchorItem ? root.anchorItem.height : 0) + 10
                tintOpacity: 0.86
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLarge
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.text, Theme.strokeSoft)
            }

            // The light along the top lip, the same one the bar islands have,
            // so a card reads as the same material the bar is made of.
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.radiusLarge
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 26
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha("white", 0.10) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.margins: 13
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }
    }
}
