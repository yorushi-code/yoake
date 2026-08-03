import QtQuick
import Quickshell
import QtQuick.Effects

// Split into separate floating islands rather than one full-width strip: the
// wallpaper shows through between them, which is what makes the shell read as
// sitting *on* the desktop instead of cropping it.
//
// This file is now only layout and window plumbing — each widget lives in its
// own Bar*.qml. It had grown to 620 lines with hit areas, poll loops, tray
// D-Bus handling and menu logic all inline, which is how the tray's broken
// right-click went unnoticed for as long as it did.
PanelWindow {
    id: bar

    // Injected by the Variants in shell.qml, one bar per connected output.
    // The workspace list is filtered by this screen's name, so a second monitor
    // no longer shows the laptop panel's workspaces.
    required property var modelData
    readonly property ShellScreen barScreen: modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight + Theme.barMargin * 2
    color: "transparent"

    // Only while a menu is up. Left permanently on, the compositor warps the
    // cursor back to the bar on every workspace switch; left permanently off,
    // menus get no keyboard focus and Escape does nothing.
    focusable: Menus.anyOpen

    readonly property string barMenuId: Menus.idFor(bar, "bar")

    // Any click that isn't on a menu should dismiss it. The islands don't cover
    // the whole bar, so this sits underneath them and catches the gaps.
    // Clicks on bare desktop are DesktopLayer's job.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                barMenuAnchor.x = mouse.x;
                Menus.toggle(bar.barMenuId);
                return;
            }
            Menus.closeAll();
        }
    }

    // The menu opens where it was asked for rather than at a fixed spot, so it
    // behaves like every other right-click on the bar.
    Item {
        id: barMenuAnchor
        y: 0
        width: 1
        height: bar.height
    }

    // The same menu the islands carry, not a second one beside it. The cheat
    // sheet has always promised a menu "on any widget and on the empty part of
    // the bar", and the empty part did nothing at all -- but ShellActions
    // exists precisely so the bar and the desktop cannot drift apart, and
    // inventing a different list here would have been the drift it warns about.
    ActionMenu {
        menuId: bar.barMenuId
        anchorItem: barMenuAnchor
        open: Menus.isOpen(bar.barMenuId)
        model: Menus.isOpen(bar.barMenuId) ? ShellActions.shellMenu : []
    }

    Item {
        anchors.fill: parent
        focus: Menus.anyOpen
        Keys.onEscapePressed: {
            Menus.closeAll();
            Toggles.closeAll();
        }
    }

    // ── Left island: workspaces ──
    BarIsland {
        id: leftIsland
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        barWindow: bar
        islandName: "left"

        BarWorkspaces {
            anchors.verticalCenter: parent.verticalCenter
            output: bar.barScreen.name
        }
    }

    // ── Centre island: now-playing + clock ──
    BarIsland {
        id: centerIsland
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        barWindow: bar
        islandName: "centre"

        pulseWithAudio: true

        // No Behavior on width here. Animating the island's own width relayouts
        // every widget inside it on each frame of the animation, and its width
        // is driven by the mini spectrum, which already animates its own. The
        // island follows for free and nothing has to be laid out twice.

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gapWide

            BarMedia { barWindow: bar }
            BarClock { barWindow: bar }
        }

        // Pointing at the centre island opens the dashboard. It is the one
        // island that is already about "what is going on" rather than about a
        // single control, so it is where the summary of everything belongs --
        // and reaching it should not require remembering a key.
        //
        // A HoverHandler, not a MouseArea under the widgets. Underneath, it
        // only saw the pointer in the gaps between the clock and the media
        // widget -- pointing at the island's actual contents did nothing, and
        // finding the strip that worked was the whole complaint. A
        // HoverHandler sees the pointer whatever is drawn above it, and it
        // takes no clicks, so the widgets keep their own.
        HoverHandler {
            id: dashHover
            onHoveredChanged: hovered ? dashOpen.restart() : dashOpen.stop()
        }

        Timer {
            id: dashOpen
            // Long enough that crossing the bar on the way somewhere else does
            // not summon it.
            interval: 420
            onTriggered: if (dashHover.hovered && !Menus.anyOpen) {
                Toggles.exclusive("dashboard");
            }
        }
    }

    // ── Right island: tray + status ──
    BarIsland {
        id: rightIsland
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        barWindow: bar
        islandName: "right"

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            BarRecorder {
                barWindow: bar
                // Without this the capture script falls back to the first
                // output it finds, which is only right by luck on one monitor.
                Component.onCompleted: Recorder.output = bar.barScreen.name
            }
            BarNotifications { barWindow: bar }
            BarTray { barWindow: bar }

            Rectangle {
                width: 1
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Theme.text, Theme.strokeFirm)
            }

            BarVpn { barWindow: bar }
            BarNetwork { barWindow: bar }
            BarAudio { barWindow: bar }
            BarBattery { barWindow: bar }
        }
    }
}
