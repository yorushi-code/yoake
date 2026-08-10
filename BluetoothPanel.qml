import QtQuick
import Quickshell
import Quickshell.Wayland

// Bluetooth, with the devices named.
//
// The headphones that dropped are reconnected from here, which is the whole
// reason this panel exists: that was a terminal, and it is the single most
// common thing anyone does with bluetooth on a laptop.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Toggles.btPanelOpen && win.armed
    property bool armed: false
    property Timer _armTick: Timer {
        interval: 16
        running: true
        onTriggered: win.armed = true
    }

    property bool mapped: false
    visible: mapped

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    focusable: Toggles.btPanelOpen
    WlrLayershell.keyboardFocus: Toggles.btPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onBtPanelOpenChanged() {
            if (Toggles.btPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
                Bt.hold();
            } else {
                hideDelay.restart();
                Bt.release();
            }
        }
    }
    Component.onCompleted: {
        win.mapped = Toggles.btPanelOpen;
        if (Toggles.btPanelOpen) Bt.hold();
    }
    // The counter belongs to this window, so an unmap that skips the toggle --
    // a config reload -- must not leave the poll running for nobody.
    Component.onDestruction: if (Toggles.btPanelOpen) Bt.release()

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.btPanelOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.btPanelOpen = false

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.rightMargin: Theme.barMargin
            width: 430
            height: Math.min(720, column.implicitHeight + Theme.sheetPad * 2)
            align: "right"
            accent: Theme.tone("bt")
            shown: win.open
            onCloseRequested: Toggles.btPanelOpen = false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            property int page: 0
            readonly property var lists: [Bt.connected, Bt.paired, Bt.nearby]
            readonly property var current: sheet.lists[sheet.page] || []

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                SheetHeader {
                    width: parent.width
                    title: Bt.primary
                        ? Bt.primary.name
                        : (Bt.powered ? "Ничего не подключено" : "Bluetooth выключен")
                    subtitle: Bt.primary
                        ? Bt.primary.mac
                        : (Bt.adapter !== "" ? Bt.adapter : "")

                    Row {
                        spacing: Theme.spacing

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.pill(height)
                            enabled: Bt.powered
                            opacity: enabled ? 1 : Theme.inkFaint
                            color: Bt.scanning ? Theme.tone("bt")
                                : (scanHit.containsMouse ? Qt.alpha(Theme.text, Theme.fillHover)
                                                         : Qt.alpha(Theme.text, Theme.fillMuted))
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: Glyphs.scan
                                size: Theme.fontIconSmall
                                fill: Bt.scanning ? 1 : 0
                                color: Bt.scanning ? Theme.onTone("bt") : Theme.text

                                // Only while a scan is genuinely running, and
                                // stopped rather than paused when it is not --
                                // a permanently running animation costs about a
                                // fifth of a core for as long as it runs.
                                RotationAnimator on rotation {
                                    running: Bt.scanning
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: Theme.animArrive
                                }
                            }

                            MouseArea {
                                id: scanHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bt.scan()
                            }
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.pill(height)
                            color: Bt.powered ? Theme.tone("bt")
                                : Qt.alpha(Theme.text, Theme.fillMuted)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: Bt.powered ? Glyphs.bluetooth : Glyphs.bluetoothOff
                                size: Theme.fontIconSmall
                                fill: Bt.powered ? 1 : 0
                                color: Bt.powered ? Theme.onTone("bt") : Theme.subtext0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bt.setPowered(!Bt.powered)
                            }
                        }
                    }
                }

                Segmented {
                    width: parent.width
                    tone: "bt"
                    model: ["Подключённые", "Спаренные", "Рядом"]
                    current: sheet.page
                    onPicked: i => sheet.page = i
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacing

                    Repeater {
                        model: sheet.current

                        delegate: DeviceRow {
                            id: btRow
                            required property var modelData
                            required property int index

                            width: parent.width
                            tone: "bt"
                            glyph: Bt.glyphFor(btRow.modelData)
                            name: btRow.modelData.name
                            subtitle: btRow.modelData.mac
                            // The battery of the thing on your head, which is
                            // the one number bluetooth is asked for and the one
                            // no shell here has ever shown.
                            trailing: btRow.modelData.battery >= 0
                                ? btRow.modelData.battery + "%" : ""
                            active: btRow.modelData.connected
                            hasControl: false

                            onActivated: {
                                if (btRow.modelData.connected) Bt.disconnect(btRow.modelData.mac);
                                else if (btRow.modelData.paired) Bt.connect(btRow.modelData.mac);
                                else Bt.pair(btRow.modelData.mac);
                            }
                            onRightClicked: Bt.forget(btRow.modelData.mac)

                            opacity: 0
                            Component.onCompleted: intro.restart()
                            SequentialAnimation {
                                id: intro
                                PauseAnimation { duration: Direction.stagger(btRow.index) }
                                NumberAnimation {
                                    target: btRow; property: "opacity"; to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasized
                                }
                            }
                        }
                    }

                    EmptyRow {
                        width: parent.width
                        visible: sheet.current.length === 0
                        glyph: Bt.powered ? Glyphs.bluetooth : Glyphs.bluetoothOff
                        text: !Bt.powered ? "Bluetooth выключен"
                            : (sheet.page === 0 ? "Ничего не подключено"
                            : (sheet.page === 1 ? "Нет спаренных устройств"
                            : "Нажмите поиск, чтобы найти устройства"))
                    }
                }
            }
        }
    }
}
