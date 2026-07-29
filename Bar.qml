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

    // Any click that isn't on a menu should dismiss it. The islands don't cover
    // the whole bar, so this sits underneath them and catches the gaps.
    // Clicks on bare desktop are DesktopLayer's job.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: Menus.anyOpen
        onClicked: Menus.closeAll()
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
            spacing: 10

            BarMedia { barWindow: bar }
            BarClock { barWindow: bar }
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
                color: Qt.alpha(Theme.text, 0.15)
            }

            BarNetwork { barWindow: bar }
            BarAudio { barWindow: bar }
            BarBattery { barWindow: bar }
        }
    }
}
