import QtQuick
import Quickshell

// The masthead.
//
// Two rows and a rule between them, edge to edge, no islands and no glass. The
// three floating pills this replaces were the same shape every other Wayland
// rice arrives at, and they made the bar an object sitting on the desktop.
// A masthead is not an object — it is the top of the page, and what holds it
// there is the rule under it, not a border around it.
//
// Row one is the record: time, date, the state of the machine. Row two is what
// is happening right now: which desks have windows, what is playing. Numbers
// are set in tabular figures throughout, because a masthead that reflows every
// minute is not set, it is animated.
PanelWindow {
    id: bar

    // Injected by the Variants in shell.qml, one bar per connected output.
    required property var modelData
    readonly property ShellScreen barScreen: modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    focusable: Menus.anyOpen

    // A masthead needs to hold its type against whatever the wallpaper is
    // doing, and a flat plate the width of the screen is heavy. A gradient
    // solves both: opaque enough to read at the top, letting the picture back
    // in as it approaches the rule.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.crust, 0.92) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.62) }
        }
    }

    // The one edge that has to hold. Everything else in this language separates
    // with air.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.ruleBold
        color: Theme.ruleStrong
    }

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

    readonly property int rowOne: 30
    readonly property int rowTwo: Theme.barHeight - bar.rowOne - Theme.ruleHair

    // ── Row one: time, date, machine ──
    Item {
        id: top
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: bar.rowOne

        BarClock {
            anchors.left: parent.left
            anchors.leftMargin: Theme.gutter
            anchors.verticalCenter: parent.verticalCenter
            barWindow: bar
        }

        BarDateline {
            anchors.centerIn: parent
            barWindow: bar
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.gutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            BarRecorder {
                barWindow: bar
                Component.onCompleted: Recorder.output = bar.barScreen.name
            }
            BarVpn { barWindow: bar }
            BarNetwork { barWindow: bar }
            BarAudio { barWindow: bar }
            BarBattery { barWindow: bar }
        }
    }

    // The internal division is a hairline, not the bold rule: inside one
    // surface a heavy line would read as two surfaces.
    Rectangle {
        id: innerRule
        anchors.top: top.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.gutter
        anchors.rightMargin: Theme.gutter
        height: Theme.ruleHair
        color: Theme.ruleColor
    }

    // ── Row two: what is happening ──
    Item {
        anchors.top: innerRule.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        BarWorkspaces {
            anchors.left: parent.left
            anchors.leftMargin: Theme.gutter
            anchors.verticalCenter: parent.verticalCenter
            output: bar.barScreen.name
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.gutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            BarMedia { barWindow: bar }
            BarNotifications { barWindow: bar }
            BarTray { barWindow: bar }
        }
    }
}
