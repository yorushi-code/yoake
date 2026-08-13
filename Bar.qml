import QtQuick
import Quickshell
import QtQuick.Effects

// The window the bar lives in, and nothing else.
//
// This file is layout and window plumbing — each widget lives in its own
// Bar*.qml, and the strip itself in `BarStrip.qml`. It had grown to 620 lines
// with hit areas, poll loops, tray D-Bus handling and menu logic all inline,
// which is how the tray's broken right-click went unnoticed for as long as it
// did.
//
// It said here, until this was written, that the bar is "separate floating
// islands rather than one full-width strip". It has been one strip for some
// time; `BarStrip.qml` carries the argument for the change and this paragraph
// was describing the shell as it was two rewrites ago, at the top of the file
// anyone opens first.
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


    // ── One strip ──
    //
    // Three islands became one surface. The air between them was the argument
    // for them and the grid was what it cost: two islands have a gap, and a gap
    // is only a boundary to someone who already knows one is meant to be there.
    // A strip has slots, and a chip in a slot is found by position.
    //
    // The zones are lists rather than named children so the order in this file
    // is the order on screen, which is the only property of a bar layout anyone
    // ever needs to check.
    BarStrip {
        id: strip
        anchors.fill: parent
        // The clock is what sits on the bar's midpoint, and the centre zone
        // composes itself around it. Everything else in the centre opens room
        // to one side or the other of a clock that never moves.
        centreAnchorX: barClock.x + barClock.anchorX

        leftItems: [
            BarMedia { barWindow: bar },
            BarStrip.Divider {},
            BarWorkspaces {
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                output: bar.barScreen.name
            }
        ]

        centreItems: [
            BarClock { id: barClock; barWindow: bar },
            BarRecorder {
                barWindow: bar
                // Without this the capture script falls back to the first
                // output it finds, which is only right by luck on one monitor.
                Component.onCompleted: Recorder.output = bar.barScreen.name
            },
            BarWeather {}
        ]

        rightItems: [
            BarTray { barWindow: bar },
            BarLayout {},
            BarStrip.Divider {},
            BarLoad { barWindow: bar },
            BarVpn { barWindow: bar },
            BarNetwork { barWindow: bar },
            BarBluetooth {},
            BarAudio { barWindow: bar },
            BarBattery { barWindow: bar },
            BarNotifications { barWindow: bar }
        ]
    }

    // Pointing at the centre of the strip opens the dashboard. It is the part
    // of the bar that is already about "what is going on" rather than about a
    // single control, so it is where the summary of everything belongs -- and
    // reaching it should not require remembering a key.
    //
    // A HoverHandler on the zone, not a MouseArea under the widgets: underneath
    // it only saw the pointer in the gaps between the clock and its
    // neighbours, so pointing at the island's actual contents did nothing.
    HoverHandler {
        id: dashHover
        parent: strip.centreArea
        onHoveredChanged: {
            // The peek watches both surfaces, so the strip reports where the
            // pointer is rather than deciding on its own when to close.
            Toggles.dashPointerOnBar = hovered;
            if (hovered) dashOpen.restart();
            else dashOpen.stop();
        }
    }

    Timer {
        id: dashOpen
        // Long enough that crossing the bar on the way somewhere else does not
        // summon it.
        interval: Theme.animSlow
        // A peek, not an open: it asks for no keyboard and it leaves with the
        // pointer. Pointing at something is not the same as asking for it.
        onTriggered: if (dashHover.hovered && !Menus.anyOpen) {
            Toggles.dashPeek();
        }
    }
}
