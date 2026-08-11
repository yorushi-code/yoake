import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

// Power and screen, where the battery chip points.
//
// The power profile was reachable from exactly one place in the shell: a
// right-click on the battery, which is a gesture people have to be told about.
// Everything else here -- how healthy the pack is, how many cycles it has done,
// how many watts are actually leaving it right now -- the machine knew and the
// shell never said.
//
// Screen sits in the same sheet rather than its own, because brightness and
// battery are the same subject from opposite ends: every question about one is
// really a question about the other.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Toggles.powerPanelOpen && win.armed
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
    focusable: Toggles.powerPanelOpen
    WlrLayershell.keyboardFocus: Toggles.powerPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onPowerPanelOpenChanged() {
            if (Toggles.powerPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
                Power.refresh();
                Brightness.refresh(false);
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: {
        win.mapped = Toggles.powerPanelOpen;
        if (Toggles.powerPanelOpen) Power.refresh();
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool charging: win.battery.state === UPowerDeviceState.Charging
    readonly property real fraction: win.battery.percentage

    readonly property string remaining: {
        const secs = win.charging ? win.battery.timeToFull : win.battery.timeToEmpty;
        if (!secs || secs <= 0) return "оценка ещё считается";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const t = h > 0 ? `${h} ч ${m} мин` : `${m} мин`;
        return win.charging ? "до полного " + t : "осталось " + t;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.powerPanelOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.powerPanelOpen = false

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.rightMargin: Theme.barMargin
            width: Theme.sheetList
            height: Math.min(760, column.implicitHeight + Theme.sheetPad * 2)
            align: "right"
            accent: Theme.tone("power")
            shown: win.open
            onCloseRequested: Toggles.powerPanelOpen = false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            property int page: 0

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                Row {
                    width: parent.width
                    spacing: Theme.gapCard

                    LevelTile {
                        id: tile
                        anchors.verticalCenter: parent.verticalCenter
                        value: win.fraction
                        tone: "power"
                        active: win.open
                    }

                    Column {
                        width: parent.width - tile.width - Theme.gapCard
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        SheetHeader {
                            width: parent.width
                            title: win.charging ? "Заряжается" : "От батареи"
                            subtitle: win.remaining
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.gapTight

                            KeyValue {
                                width: parent.width
                                visible: Power.drawKnown
                                key: "Расход"
                                value: Power.drawWatts.toFixed(1) + " Вт"
                            }
                            KeyValue {
                                width: parent.width
                                visible: Power.healthKnown
                                key: "Здоровье"
                                value: Math.round(Power.health * 100) + "% · "
                                    + Power.capacityWh.toFixed(1) + " / "
                                    + Power.designWh.toFixed(1) + " Вт·ч"
                            }
                            KeyValue {
                                width: parent.width
                                visible: Power.cycleCount >= 0
                                key: "Циклов"
                                value: String(Power.cycleCount)
                            }
                        }
                    }
                }

                Segmented {
                    width: parent.width
                    tone: "power"
                    model: ["Питание", "Экран"]
                    current: sheet.page
                    onPicked: i => sheet.page = i
                }

                // ── Питание ──
                Column {
                    width: parent.width
                    spacing: Theme.spacing
                    visible: sheet.page === 0

                    Repeater {
                        model: Power.profiles

                        delegate: DeviceRow {
                            id: profileRow
                            required property var modelData
                            required property int index

                            width: parent.width
                            tone: "power"
                            glyph: Power.glyphFor(profileRow.modelData)
                            name: Power.labelFor(profileRow.modelData)
                            subtitle: Power.detailFor(profileRow.modelData)
                            active: Power.activeProfile === profileRow.modelData
                            hasControl: false
                            onActivated: Power.setProfile(profileRow.modelData)
                        }
                    }

                    KeyValue {
                        width: parent.width
                        visible: Power.chargeLimit > 0
                        key: "Порог зарядки"
                        value: Power.chargeLimit + "%"
                    }

                    // ── Settings above, acts below ──
                    //
                    // A profile is a choice that persists and shows which one is
                    // current. An action is a verb: it happens once, the panel
                    // is gone a moment later, and one of them ends the session.
                    // Drawn in the same class they read as four more settings,
                    // which is how "Выключение" ends up looking like something
                    // you can browse.
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.alpha(Theme.text, Theme.fillMuted)
                    }

                    Text {
                        text: "СЕАНС"
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                        font.letterSpacing: Theme.trackCaption
                    }

                    // Named, not a row of glyphs. Four unlabelled icons where
                    // one of them powers the machine off is a guessing game
                    // with a bad prize.
                    Repeater {
                        model: [
                            { text: "Заблокировать", glyph: Glyphs.lock, danger: false, act: () => Power.lock() },
                            { text: "Спящий режим", glyph: Glyphs.sleep, danger: false, act: () => Power.suspend() },
                            { text: "Перезагрузка", glyph: Glyphs.restart, danger: true, act: () => Power.reboot() },
                            { text: "Выключение", glyph: Glyphs.power, danger: true, act: () => Power.powerOff() }
                        ]

                        delegate: DeviceRow {
                            required property var modelData
                            width: parent.width
                            tone: "power"
                            glyph: modelData.glyph
                            name: modelData.text
                            hasControl: false
                            danger: modelData.danger
                            onActivated: modelData.act()
                        }
                    }
                }

                // ── Экран ──
                Column {
                    width: parent.width
                    spacing: Theme.gapCard
                    visible: sheet.page === 1

                    Column {
                        width: parent.width
                        spacing: Theme.spacing
                        visible: Brightness.available

                        KeyValue {
                            width: parent.width
                            key: "Яркость"
                            value: Math.round(Brightness.value * 100) + "%"
                        }

                        HSlider {
                            width: parent.width
                            value: Brightness.value
                            tint: Theme.tone("power")
                            onMoved: v => Brightness.set(v)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacing

                        DeviceRow {
                            width: parent.width
                            tone: "power"
                            glyph: Glyphs.nightLight
                            name: "Ночной свет"
                            subtitle: NightLight.enabled
                                ? NightLight.temperature + " K"
                                : "Выключен"
                            active: NightLight.enabled
                            hasControl: false
                            onActivated: NightLight.toggle()
                        }

                        HSlider {
                            width: parent.width
                            visible: NightLight.enabled
                            value: NightLight.fraction
                            tint: Theme.tone("power")
                            onMoved: v => NightLight.setFraction(v)
                        }
                    }
                }
            }
        }
    }
}
