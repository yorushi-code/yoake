import QtQuick
import QtQuick.Effects
import Quickshell

// Frosted popup used by every menu in the shell.
//
// Built on PopupWindow rather than another PanelWindow overlay so the
// compositor anchors it to its owning widget: a full-screen catcher window
// (the trick CheatSheet uses to catch outside clicks) would also have to sit
// above the bar, which is exactly where these menus need to remain clickable.
//
// `visible` is assigned, never bound. Quickshell writes to it itself when a
// focus grab breaks, and a binding would be silently destroyed the first time
// that happened, leaving the menu permanently unable to reopen.
PopupWindow {
    id: root

    default property alias content: inner.data
    property bool open: false
    property int contentWidth: 220
    property int contentHeight: 100

    signal dismissed()

    // 10px each side for the shadow drawn inside the window, plus the 6px
    // inset of the content item below. Counting only the shadow left the
    // content 12px taller than the box it sat in, so the last row was clipped.
    readonly property int surfacePadding: (10 + 6) * 2
    implicitWidth: contentWidth + surfacePadding
    implicitHeight: contentHeight + surfacePadding
    color: "transparent"
    grabFocus: root.open

    // The glass samples the wallpaper wherever the popup landed, otherwise the
    // blur behind it shows a slice of the wrong part of the image.
    readonly property real sampleX: root.anchor.window
        ? root.anchor.window.x + root.anchor.rect.x + root.anchor.rect.width / 2 - width / 2
        : 0
    readonly property real sampleY: Theme.barHeight + Theme.barMargin * 2

    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: root.visible = false
    }

    onOpenChanged: {
        if (root.open) {
            hideDelay.stop();
            root.visible = true;
        } else {
            hideDelay.restart();
        }
    }

    // Quickshell drops the popup on grab break. Treat that as the user
    // dismissing it rather than silently desyncing from the owner's state.
    // onOpenChanged does not fire for a value already set at construction, so a
    // menu created in the open state would never map itself.
    Component.onCompleted: if (root.open) root.visible = true

    onVisibleChanged: {
        if (!root.visible && root.open) root.dismissed();
    }

    // The same object every raised thing in this shell is made of. It used to
    // round to Theme.radius + 4, a number that belonged to nothing.
    Surface {
        id: glass
        anchors.fill: parent
        anchors.margins: 10
        radius: Theme.radiusCard
        elevation: "modal"
        screenX: root.sampleX
        screenY: root.sampleY
        tintOpacity: 0.84

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.88
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

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: 6
        }
    }

    Item {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.dismissed()
    }
}
