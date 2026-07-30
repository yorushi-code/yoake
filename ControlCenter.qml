import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The control centre: window plumbing and layout only.
//
// It had grown to 675 lines with every toggle, every device list and twelve
// hand-written PauseAnimation cascades inline, which is why adding a tile meant
// editing the same block as the power buttons and why the staggers had drifted
// out of step with each other. The controls are Cc*.qml now and the cascade
// comes from Theme.stagger().
//
// The card is 400 wide with a two-column tile grid: as a single column of
// full-width rows the panel needed scrolling to reach Bluetooth, and every
// control looked equally important because they were all the same shape.
Item {
    id: root

    // Animations bind to this, not to the toggle. The panel is created lazily,
    // which means it is born with the toggle already true — an entry animation
    // bound straight to the toggle has nothing to animate from. `armed` turns
    // on a frame later, so the open state is always a transition.
    readonly property bool open: Toggles.controlCenterOpen && root.armed
    property bool armed: false
    Component.onCompleted: armTick.start()
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: root.armed = true
    }

    // Which tile's detail page is showing, "" for the tile grid itself.
    property string page: ""


    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property real volume: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
        ? Pipewire.defaultAudioSink.audio.volume : 0

    Component { id: wifiPage; CcWifiPage {} }
    Component { id: bluetoothPage; CcBluetoothPage {} }
    Component { id: displayPage; CcDisplayPage {} }
    Component { id: powerPage; CcPowerPage {} }

    readonly property Component pageComponent: {
        switch (root.page) {
        case "wifi": return wifiPage;
        case "bluetooth": return bluetoothPage;
        case "display": return displayPage;
        case "power": return powerPage;
        }
        return null;
    }

    readonly property string pageTitle: {
        switch (root.page) {
        case "wifi": return "Wi-Fi";
        case "bluetooth": return "Bluetooth";
        case "display": return "Экран";
        case "power": return "Питание";
        }
        return "";
    }

    PanelWindow {
        id: win
        // Mapping is driven by an explicit bool, never bound to
        // Toggles.controlCenterOpen directly. A binding like
        // `visible: open || hideDelay.running` races: when open flips false the
        // visible binding can re-evaluate BEFORE the Connections handler
        // restarts the timer, so the window unmaps instantly and the exit
        // animation never plays.
        property bool mapped: false
        visible: mapped

        // Full-screen rather than card-sized: without a backdrop there is no
        // click-outside-to-close.
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        focusable: root.open

        readonly property int cardWidth: 400
        // Hugs the tiles, and only grows for a page — a fixed height left a
        // third of the card as empty glass under the app shortcuts.
        readonly property int cardHeight: Math.min(Screen.height - Theme.barHeight - 60,
            root.page !== "" ? 700 : content.implicitHeight + 70)

        // Slightly longer than the exit animation so the unmap lands just after
        // the fade finishes, never mid-fade.
        Timer {
            id: hideDelay
            interval: Theme.animExit + 40
            onTriggered: win.mapped = false
        }
        function opened() {
            hideDelay.stop();
            win.mapped = true;
            // Always opens on the tiles: reopening onto whatever page was last
            // visited hides the controls the user came for.
            root.page = "";
            Brightness.refresh();
        }

        Connections {
            target: Toggles
            function onControlCenterOpenChanged() {
                if (Toggles.controlCenterOpen) win.opened();
                else hideDelay.restart();
            }
        }

        // The panel is loaded lazily *because* the toggle went true, so the
        // signal above has already been emitted by the time this exists. The
        // first open of a session would otherwise skip everything opening is
        // supposed to do.
        Component.onCompleted: if (Toggles.controlCenterOpen) win.opened()

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.controlCenterOpen = false
        }

        Item {
            anchors.fill: parent
            focus: root.open
            // Escape steps back out of a page before it closes the panel:
            // dismissing the whole thing from a device list is a surprise.
            Keys.onEscapePressed: {
                if (root.page !== "") root.page = "";
                else Toggles.controlCenterOpen = false;
            }

            PanelChrome {
                id: chrome
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
                anchors.rightMargin: Theme.barMargin
                width: win.cardWidth
                height: win.cardHeight
                screenX: Screen.width - Theme.barMargin - win.cardWidth
                screenY: Theme.barHeight + Theme.barMargin * 2

                // The card resizes when a page opens; snapping between the two
                // heights reads as the panel being replaced rather than opened
                // into.
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.animNormal
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasized
                    }
                }

                opacity: root.open ? 1 : 0
                scale: root.open ? 1 : Theme.revealScale
                transformOrigin: Item.TopRight
                // Duration and easing depend on direction: the open state's
                // value is already latched by the time the Behavior fires, so
                // this reads "arriving" vs "leaving" correctly.
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
                onCloseRequested: Toggles.controlCenterOpen = false

                // Swallows clicks so the backdrop does not treat a click on the
                // panel itself as "outside".
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                CcPager {
                    id: pager
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 38

                    page: root.page
                    title: root.pageTitle
                    pageComponent: root.pageComponent
                    onBack: root.page = ""

                    Flickable {
                        anchors.fill: parent
                        contentHeight: content.implicitHeight
                        clip: true

                        Column {
                            id: content
                            width: parent.width
                            spacing: 16

                            Reveal {
                                width: parent.width
                                height: volumeSlider.implicitHeight
                                shown: root.open
                                slideY: Theme.revealSlide
                                origin: Item.Top

                                SliderRow {
                                    id: volumeSlider
                                    width: parent.width
                                    label: "Громкость " + Math.round(root.volume * 100) + "%"
                                    value: root.volume
                                    onMoved: v => {
                                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                            Pipewire.defaultAudioSink.audio.volume = v;
                                        }
                                    }
                                }
                            }

                            Reveal {
                                width: parent.width
                                height: tiles.implicitHeight
                                shown: root.open
                                delay: Theme.stagger(1)
                                slideY: Theme.revealSlide
                                origin: Item.Top

                                CcTileGrid {
                                    id: tiles
                                    width: parent.width
                                    onPageRequested: name => root.page = name
                                }
                            }

                            Reveal {
                                width: parent.width
                                height: stats.implicitHeight
                                shown: root.open
                                delay: Theme.stagger(2)
                                slideY: Theme.revealSlide
                                origin: Item.Top

                                CcStats {
                                    id: stats
                                    width: parent.width
                                }
                            }

                            Reveal {
                                width: parent.width
                                height: launcher.implicitHeight
                                shown: root.open
                                delay: Theme.stagger(3)
                                slideY: Theme.revealSlide
                                origin: Item.Top
                                visible: launcher.entries.length > 0

                                CcQuickLaunch {
                                    id: launcher
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
