import QtQuick
import Quickshell
import Quickshell.Wayland

// The dashboard.
//
// One wide sheet with tabs, instead of a calendar in one corner, a control
// centre in another and statistics on the desktop behind both. Those panels
// never knew about each other: opening two of them overlapped, and none of them
// could show anything the others already had on screen.
//
// It shows rather than sets. Switches stay in the control centre — a dashboard
// that opens on a wall of toggles is a settings dialog with a nicer font.
Item {
    id: root

    // Animations bind to this, not to the toggle: created lazily, the panel is
    // born with the toggle already true and an entry animation bound straight
    // to the toggle has nothing to animate from.
    readonly property bool open: Toggles.dashboardOpen && root.armed
    property bool armed: false
    Component.onCompleted: armTick.start()
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: root.armed = true
    }

    readonly property var tabs: [
        { key: "overview", label: "Обзор", glyph: Glyphs.apps },
        { key: "media", label: "Медиа", glyph: Glyphs.music },
        { key: "system", label: "Система", glyph: Glyphs.speedometer },
        { key: "control", label: "Управление", glyph: Glyphs.cog },
        { key: "desks", label: "Столы", glyph: Glyphs.monitor }
    ]
    // Held in Toggles so the page survives the panel being destroyed, and so
    // the IPC that selects it exists while the panel does not.
    property int tab: Toggles.dashPage

    PanelWindow {
        id: win
        // Overlay, not the default Top: niri draws a fullscreen window above
        // the Top layer, so a panel the user just asked for would open behind
        // the video they were watching and read as a dead keystroke.
        WlrLayershell.layer: WlrLayer.Overlay
        property bool mapped: false
        visible: mapped

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        // See Launcher: bound to the toggle, because `open` waits a frame for
        // `armed` and a surface mapped asking for no keyboard never gets one.
        focusable: Toggles.dashboardOpen
        WlrLayershell.keyboardFocus: Toggles.dashboardOpen
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        Timer {
            id: hideDelay
            interval: Theme.animExit + 60
            onTriggered: win.mapped = false
        }

        function opened() {
            hideDelay.stop();
            win.mapped = true;
        }

        Connections {
            target: Toggles
            function onDashboardOpenChanged() {
                if (Toggles.dashboardOpen) win.opened();
                else hideDelay.restart();
            }
        }
        Component.onCompleted: if (Toggles.dashboardOpen) win.opened()

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.dashboardOpen = false
        }

        Item {
            anchors.fill: parent
            focus: root.open

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Toggles.dashboardOpen = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                    Toggles.dashPage = (root.tab + 1) % root.tabs.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                    Toggles.dashPage = (root.tab + root.tabs.length - 1) % root.tabs.length;
                    event.accepted = true;
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const wanted = event.key - Qt.Key_1;
                    if (wanted < root.tabs.length) Toggles.dashPage = wanted;
                    event.accepted = true;
                }
            }

            readonly property int sheetWidth: Math.min(920, Screen.width - 80)
            readonly property int sheetHeight: 524

            PanelChrome {
                id: chrome
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
                width: parent.sheetWidth
                height: parent.sheetHeight
                screenX: Math.round((Screen.width - parent.sheetWidth) / 2)
                screenY: Theme.barHeight + Theme.barMargin * 2

                opacity: root.open ? 1 : 0
                scale: root.open ? 1 : Theme.revealScale
                transformOrigin: Item.Top
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.open ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.open ? Theme.easeEmphasized : Theme.easeExit
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root.open ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.open ? Theme.easeSpringBig : Theme.easeExit
                    }
                }
                onCloseRequested: Toggles.dashboardOpen = false

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                // ── Tabs ──
                Item {
                    id: tabBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 62

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: root.tabs

                            delegate: Item {
                                id: tab
                                required property var modelData
                                required property int index

                                readonly property bool current: root.tab === tab.index
                                width: tabLabel.implicitWidth + tabGlyph.implicitWidth + 40
                                height: 38

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 9

                                    Text {
                                        id: tabGlyph
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tab.modelData.glyph
                                        font.family: Theme.fontIconFamily
                                        font.pixelSize: 14
                                        color: tab.current ? Theme.accent
                                            : (tabArea.containsMouse ? Theme.text : Theme.subtext0)
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }

                                    Text {
                                        id: tabLabel
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tab.modelData.label
                                        color: tab.current ? Theme.text
                                            : (tabArea.containsMouse ? Theme.text : Theme.subtext0)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontBody
                                        font.weight: tab.current ? Font.DemiBold : Font.Normal
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }
                                }

                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Toggles.dashPage = tab.index
                                }
                            }
                        }
                    }

                    // One indicator that slides between tabs, rather than a
                    // marker per tab appearing and disappearing: the movement is
                    // what tells the eye the two tabs are the same control.
                    Rectangle {
                        id: indicator
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        height: 2.5
                        radius: 1.25
                        color: Theme.accent

                        // Found by the delegate's own index rather than by
                        // position in children: a Repeater is itself a child of
                        // its parent, so children[n] is off by one wherever Qt
                        // decides to put it.
                        readonly property Item target: {
                            for (const child of tabRow.children) {
                                if (child.hasOwnProperty("index") && child.index === root.tab) {
                                    return child;
                                }
                            }
                            return null;
                        }
                        width: indicator.target ? indicator.target.width - 22 : 0
                        x: indicator.target
                            ? tabRow.x + indicator.target.x + 11
                            : 0

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.easeEmphasized
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.easeEmphasized
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        height: 1
                        color: Qt.alpha(Theme.text, Theme.fillMuted)
                    }
                }

                // ── Pages ──
                // All three exist; only the current one is opaque. Rebuilding a
                // page on every tab change would restart its animations and drop
                // the calendar's month back to today each time.
                Item {
                    id: pages
                    anchors.top: tabBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    anchors.topMargin: 14

                    DashOverview {
                        anchors.fill: parent
                        visible: opacity > 0
                        // Cards play their entrance when the sheet opens *and*
                        // when this page becomes the one on screen, so switching
                        // tabs is an arrival rather than a swap.
                        revealed: root.open && root.tab === 0
                        opacity: root.tab === 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }

                    DashMedia {
                        anchors.fill: parent
                        visible: opacity > 0
                        revealed: root.open && root.tab === 1
                        opacity: root.tab === 1 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }

                    DashSystem {
                        anchors.fill: parent
                        visible: opacity > 0
                        revealed: root.open && root.tab === 2
                        opacity: root.tab === 2 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }

                    DashControl {
                        anchors.fill: parent
                        visible: opacity > 0
                        revealed: root.open && root.tab === 3
                        opacity: root.tab === 3 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }

                    DashDesks {
                        anchors.fill: parent
                        visible: opacity > 0
                        opacity: root.tab === 4 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }
                }
            }
        }
    }
}
