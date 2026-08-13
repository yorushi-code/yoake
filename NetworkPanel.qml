import QtQuick
import Quickshell
import Quickshell.Wayland

// Every network in reach, and a way onto one.
//
// The bar chip names the network now, which answers "which" and immediately
// raises "and how do I get onto another one". That was a terminal or a
// right-click menu of eight entries with no password field in it, so joining a
// new network was the one everyday task this shell sent people elsewhere for.
//
// The scan is held open only while this window is: `Net.hold()` is what stops a
// single-radio card from being told to rescan the airwaves forever, which was
// the old "network keeps dropping" bug wearing a different hat.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: arm.open
    property PanelArm _arm: PanelArm { id: arm; requested: Toggles.netPanelOpen }

    property bool mapped: false
    visible: mapped

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    focusable: Toggles.netPanelOpen
    WlrLayershell.keyboardFocus: Toggles.netPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onNetPanelOpenChanged() {
            if (Toggles.netPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
                Net.hold();
            } else {
                hideDelay.restart();
                Net.release();
            }
        }
    }
    Component.onCompleted: {
        win.mapped = Toggles.netPanelOpen;
        if (Toggles.netPanelOpen) Net.hold();
    }
    // The counter is the panel's, so an unmap that skips the toggle -- a reload,
    // a crash of this window alone -- must not leave the scanner running.
    Component.onDestruction: if (Toggles.netPanelOpen) Net.release()

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.netPanelOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.netPanelOpen = false

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.rightMargin: Theme.barMargin
            width: Theme.sheetList
            height: Math.min(720, column.implicitHeight + Theme.sheetPad * 2)
            align: "right"
            accent: Theme.tone("net")
            shown: win.open
            onCloseRequested: Toggles.netPanelOpen = false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            property int page: 0
            readonly property var lists: [Net.networks, Net.wired, Net.saved]
            readonly property var current: sheet.lists[sheet.page] || []

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: Theme.sheetPad
                spacing: Theme.gapCard

                SheetHeader {
                    width: parent.width
                    // Off is a state, and the empty row below already reports it
                    // in those words. Printed here as well it was the same
                    // sentence twice, so the title falls back to the subject --
                    // the radio -- and lets the body do the reporting. "Не
                    // подключено" stays: with Wi-Fi on the body is a list of
                    // networks rather than an empty row, so nothing repeats it.
                    title: Net.activeSsid !== "" ? Net.activeSsid
                        : (Net.wifiEnabled ? "Не подключено" : "Wi-Fi")
                    subtitle: Net.activeIp !== "" ? Net.activeIp : Net.iface

                    Row {
                        spacing: Theme.spacing

                        // On/off, not chosen. A header toggle reports a live
                        // state, and in this shell a live state is a tinted glyph
                        // rather than a filled ground -- filling it put a second
                        // "chosen" colour beside the accent one row down.
                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.pill(height)
                            color: scanHit.containsMouse ? Qt.alpha(Theme.text, Theme.fillHover)
                                : Qt.alpha(Theme.text, Theme.fillMuted)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: Glyphs.scan
                                size: Theme.fontIconSmall
                                fill: Net.scanning ? 1 : 0
                                color: Net.scanning ? Theme.tone("net") : Theme.text
                            }

                            MouseArea {
                                id: scanHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Net.rescan()
                            }
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.pill(height)
                            color: Qt.alpha(Theme.text, Theme.fillMuted)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                icon: Net.wifiEnabled ? Glyphs.wifi : Glyphs.wifiOff
                                size: Theme.fontIconSmall
                                fill: Net.wifiEnabled ? 1 : 0
                                color: Net.wifiEnabled ? Theme.tone("net") : Theme.subtext0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Net.setWifiEnabled(!Net.wifiEnabled)
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.gapTight
                    visible: Net.activeSsid !== ""

                    KeyValue {
                        width: parent.width
                        key: "Приём / отдача"
                        value: Net.rateText(Net.rxRate) + " / " + Net.rateText(Net.txRate)
                    }
                    KeyValue {
                        width: parent.width
                        key: "Сигнал"
                        value: Net.activeSignal >= 0 ? Net.activeSignal + "%" : "—"
                    }
                    KeyValue {
                        width: parent.width
                        key: "Диапазон"
                        value: Net.activeBand !== "" ? Net.activeBand : "—"
                    }
                }

                Segmented {
                    width: parent.width
                    tone: "net"
                    model: ["Wi-Fi", "Проводное", "Известные"]
                    current: sheet.page
                    onPicked: i => sheet.page = i
                }

                // The error from the last attempt, where the attempt was made.
                // A wrong password that fails silently is the reason people go
                // back to the terminal and stay there.
                Rectangle {
                    width: parent.width
                    height: errorText.implicitHeight + Theme.spacing * 2
                    radius: Theme.radiusChip
                    visible: Net.lastError !== ""
                    color: Qt.alpha(Theme.tone("alert"), Theme.tintSubtle)

                    Text {
                        id: errorText
                        anchors.centerIn: parent
                        width: parent.width - Theme.rowPad * 2
                        text: Net.lastError
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacing

                    Repeater {
                        model: sheet.current

                        delegate: Column {
                            id: entry
                            required property var modelData
                            required property int index

                            width: parent.width
                            spacing: Theme.gapTight

                            readonly property string ssid: entry.modelData.ssid || ""
                            readonly property bool asking: Net.needsPassword === entry.ssid

                            DeviceRow {
                                id: netRow
                                width: parent.width
                                tone: "net"
                                glyph: sheet.page === 1 ? Glyphs.ethernet
                                    : Glyphs.wifiFor(entry.modelData.signal !== undefined
                                        ? entry.modelData.signal : -1)
                                name: entry.ssid
                                subtitle: sheet.page === 2
                                    ? "Сохранённая сеть"
                                    : [Net.securityLabel(entry.modelData.security || ""),
                                       entry.modelData.band || ""].filter(s => s !== "").join(" · ")
                                trailing: entry.modelData.signal !== undefined && entry.modelData.signal >= 0
                                    ? entry.modelData.signal + "%" : ""
                                active: entry.modelData.active === true
                                    || entry.ssid === Net.activeSsid
                                // A network has no level to set, so the row is
                                // a choice and nothing else.
                                hasControl: false

                                onActivated: {
                                    if (entry.ssid === Net.activeSsid) Net.disconnect();
                                    else Net.connect(entry.ssid, "");
                                }
                                onRightClicked: Net.forget(entry.ssid)

                                // Targets the row itself, not the column it sits
                                // in: animating the wrong object leaves every
                                // row parked at zero opacity, which looks
                                // exactly like a list that found nothing.
                                opacity: 0
                                Component.onCompleted: intro.restart()
                                SequentialAnimation {
                                    id: intro
                                    PauseAnimation { duration: Direction.stagger(entry.index) }
                                    NumberAnimation {
                                        target: netRow; property: "opacity"; to: 1
                                        duration: Theme.animNormal
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.easeEmphasized
                                    }
                                }
                            }

                            // Inside the row, not in a dialog. A password is an
                            // answer to the row you just clicked, and a second
                            // window would have to say which network it meant.
                            Rectangle {
                                width: parent.width
                                height: entry.asking ? 40 : 0
                                visible: height > 0
                                clip: true
                                radius: Theme.radiusChip
                                color: Qt.alpha(Theme.text, Theme.fillMuted)

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.animNormal
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.easeEmphasized
                                    }
                                }

                                onVisibleChanged: if (visible) password.forceActiveFocus()

                                TextInput {
                                    id: password
                                    anchors.left: parent.left
                                    anchors.right: joinButton.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.rowPad
                                    anchors.rightMargin: Theme.spacing
                                    echoMode: TextInput.Password
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    clip: true
                                    onAccepted: {
                                        Net.connect(entry.ssid, password.text);
                                        password.text = "";
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: password.text === ""
                                        text: "Пароль"
                                        color: Theme.subtext0
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontBody
                                    }
                                }

                                Rectangle {
                                    id: joinButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: Theme.spacing
                                    width: 28
                                    height: 28
                                    radius: Theme.pill(height)
                                    color: Theme.tone("net")

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        icon: Glyphs.check
                                        size: Theme.fontIconSmall
                                        fill: 1
                                        color: Theme.onTone("net")
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Net.connect(entry.ssid, password.text);
                                            password.text = "";
                                        }
                                    }
                                }
                            }
                        }
                    }

                    EmptyRow {
                        width: parent.width
                        visible: sheet.current.length === 0
                        glyph: Net.wifiEnabled ? Glyphs.wifiNone : Glyphs.wifiOff
                        text: !Net.wifiEnabled ? "Wi-Fi выключен"
                            : (sheet.page === 1 ? "Кабель не подключён"
                            : (sheet.page === 2 ? "Нет сохранённых сетей" : "Сетей не найдено"))
                    }
                }
            }
        }
    }
}
