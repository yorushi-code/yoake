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
                Bluetooth.hold();
            } else {
                hideDelay.restart();
                Bluetooth.release();
            }
        }
    }
    Component.onCompleted: {
        win.mapped = Toggles.btPanelOpen;
        if (Toggles.btPanelOpen) Bluetooth.hold();
    }
    // The counter belongs to this window, so an unmap that skips the toggle --
    // a config reload -- must not leave the poll running for nobody.
    Component.onDestruction: if (Toggles.btPanelOpen) Bluetooth.release()

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
            readonly property var lists: [Bluetooth.connected, Bluetooth.paired, Bluetooth.nearby]
            readonly property var current: sheet.lists[sheet.page] || []

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                SheetHeader {
                    width: parent.width
                    title: Bluetooth.primary
                        ? Bluetooth.primary.name
                        : (Bluetooth.powered ? "Ничего не подключено" : "Bluetooth выключен")
                    subtitle: Bluetooth.primary
                        ? Bluetooth.primary.mac
                        : (Bluetooth.adapter !== "" ? Bluetooth.adapter : "")

                    Row {
                        spacing: Theme.spacing

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.pill(height)
                            enabled: Bluetooth.powered
                            opacity: enabled ? 1 : Theme.inkFaint
                            color: Bluetooth.scanning ? Theme.tone("bt")
                                : (scanHit.containsMouse ? Qt.alpha(Theme.text, Theme.fillHover)
                                                         : Qt.alpha(Theme.text, Theme.fillMuted))
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: Glyphs.scan
                                size: Theme.fontIconSmall
                                fill: Bluetooth.scanning ? 1 : 0
                                color: Bluetooth.scanning ? Theme.onTone("bt") : Theme.text

                                // Only while a scan is genuinely running, and
                                // stopped rather than paused when it is not --
                                // a permanently running animation costs about a
                                // fifth of a core for as long as it runs.
                                RotationAnimator on rotation {
                                    running: Bluetooth.scanning
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
                                onClicked: Bluetooth.scan()
                            }
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.pill(height)
                            color: Bluetooth.powered ? Theme.tone("bt")
                                : Qt.alpha(Theme.text, Theme.fillMuted)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: Bluetooth.powered ? Glyphs.bluetooth : Glyphs.bluetoothOff
                                size: Theme.fontIconSmall
                                fill: Bluetooth.powered ? 1 : 0
                                color: Bluetooth.powered ? Theme.onTone("bt") : Theme.subtext0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bluetooth.setPowered(!Bluetooth.powered)
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
                            glyph: Bluetooth.glyphFor(btRow.modelData)
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
                                if (btRow.modelData.connected) Bluetooth.disconnect(btRow.modelData.mac);
                                else if (btRow.modelData.paired) Bluetooth.connect(btRow.modelData.mac);
                                else Bluetooth.pair(btRow.modelData.mac);
                            }
                            onRightClicked: Bluetooth.forget(btRow.modelData.mac)

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
                        glyph: Bluetooth.powered ? Glyphs.bluetooth : Glyphs.bluetoothOff
                        text: !Bluetooth.powered ? "Bluetooth выключен"
                            : (sheet.page === 0 ? "Ничего не подключено"
                            : (sheet.page === 1 ? "Нет спаренных устройств"
                            : "Нажмите поиск, чтобы найти устройства"))
                    }
                }
            }
        }
    }
}
