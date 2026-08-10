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

    // Three, where there were five.
    //
    // Media and System were built when this sheet was the only door in the
    // shell. Every chip in the bar opens its own panel now, and a dashboard tab
    // that shows the same list one keystroke further away is not a summary, it
    // is a second copy that will drift from the first.
    //
    // What survives is what no panel owns: Overview is the glance -- calendar,
    // weather, unread, load -- Control is where settings live, and Desks is the
    // only view of the whole compositor.
    readonly property var tabs: [
        { key: "overview", label: "Обзор", glyph: Glyphs.apps },
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
        // Exclusive when it was asked for, on demand when it was only pointed
        // at. A peek that seized the keyboard was the whole problem: a surface
        // mapped asking for no keyboard is never offered one afterwards, so
        // the choice has to be made here rather than by flipping `focusable`
        // once the peek is clicked.
        WlrLayershell.keyboardFocus: !Toggles.dashboardOpen
            ? WlrKeyboardFocus.None
            : (Toggles.dashboardPeek
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.Exclusive)

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
                // Typing into it is asking for it, for the same reason a click
                // is.
                Toggles.dashCommit();
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

                shown: root.open
                origin: Item.Top
                onCloseRequested: Toggles.dashboardOpen = false

                // Reports the pointer to the peek, which watches this surface
                // and the bar island together — neither window can see the
                // other's hover, so each says where the pointer is and the
                // decision is made in one place.
                HoverHandler {
                    onHoveredChanged: Toggles.dashPointerOnSheet = hovered
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // Clicking it is asking for it. From here it stays until
                    // it is dismissed, like a dashboard opened by the key.
                    onPressed: Toggles.dashCommit()
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
                                    spacing: Theme.gapWide

                                    MaterialSymbol {
                                        id: tabGlyph
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: tab.modelData.glyph
                                        size: Theme.fontIconSmall
                                        // The tab you are on is the filled one.
                                        // Same drawing, different state, which
                                        // is the axis doing the job a second
                                        // picture used to do badly.
                                        fill: tab.current ? 1 : 0
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
                    //
                    // A pill rather than the underline it used to be. Every
                    // other selected thing in this shell is a chip, and a hairline
                    // under a word was the last element still speaking its own
                    // language. It sits behind the label, so the sliding that
                    // made the underline worth having is unchanged.
                    // The same marker the workspaces and the launcher use, so
                    // the deformation is not a per-widget decision either. It
                    // already slid; what it did not do was behave like it had
                    // any mass, and the tab bar is the widest thing in the
                    // shell for a marker to cross.
                    Traveller {
                        id: indicator
                        z: -1
                        active: indicator.target !== null
                        slotY: Math.round((tabBar.height - indicator.slotHeight) / 2)
                        slotHeight: 38
                        // Crossing the whole bar is the long journey here, and
                        // it is what "Обзор" to "Столы" actually is.
                        span: tabRow.width

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
                        slotWidth: indicator.target ? indicator.target.width : 0
                        slotX: indicator.target ? tabRow.x + indicator.target.x : 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.pill(height)
                            color: Qt.alpha(Theme.text, Theme.fillHover)
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

                    DashControl {
                        anchors.fill: parent
                        visible: opacity > 0
                        revealed: root.open && root.tab === 1
                        opacity: root.tab === 1 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }

                    DashDesks {
                        anchors.fill: parent
                        visible: opacity > 0
                        opacity: root.tab === 2 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }
                }
            }
        }
    }
}
