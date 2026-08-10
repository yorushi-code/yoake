import QtQuick
import Quickshell
import Quickshell.Wayland

// The tunnel, in the same language as everything else.
//
// This was eight hundred lines of layout written before there was a vocabulary
// to write it in: its own rows, its own headers, its own idea of what a
// selected thing looks like. None of the logic was wrong -- Mihomo is untouched
// -- but a panel that draws its own furniture is a panel that stops matching
// the shell the first time either one changes.
//
// What it gains by being rebuilt on the shared parts is the thing every other
// panel already had: the active row is a solid domain ground with no control of
// its own, because what is active is controlled by the header.
PanelWindow {
    id: win

    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Toggles.vpnPanelOpen && win.armed
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
    focusable: Toggles.vpnPanelOpen
    WlrLayershell.keyboardFocus: Toggles.vpnPanelOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Timer {
        id: hideDelay
        interval: Theme.animExit + 60
        onTriggered: win.mapped = false
    }

    Connections {
        target: Toggles
        function onVpnPanelOpenChanged() {
            if (Toggles.vpnPanelOpen) {
                hideDelay.stop();
                win.mapped = true;
                Mihomo.refresh();
                Mihomo.probeDelaysIfStale(Mihomo.primaryGroup);
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: {
        win.mapped = Toggles.vpnPanelOpen;
        if (Toggles.vpnPanelOpen) Mihomo.refresh();
    }

    readonly property bool up: Mihomo.running && Mihomo.controllerUp

    // Servers only. AUTO and DIRECT are policies rather than exits, and mixing
    // them into the list of places the traffic can come out of is how a list of
    // nodes stops being one.
    readonly property var nodes: {
        const group = Mihomo.primary;
        if (!group || !group.nodes) return [];
        return group.nodes.filter(n => !Mihomo.isSelectable(n));
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Toggles.vpnPanelOpen = false
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Toggles.vpnPanelOpen = false

        Sheet {
            id: sheet
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barHeight + Theme.barMargin * 2
            anchors.rightMargin: Theme.barMargin
            width: 460
            height: Math.min(740, column.implicitHeight + Theme.sheetPad * 2)
            align: "right"
            accent: Theme.tone("vpn")
            shown: win.open
            onCloseRequested: Toggles.vpnPanelOpen = false

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

                SheetHeader {
                    width: parent.width
                    title: Mihomo.busy ? "Подключаюсь…"
                        : (win.up ? (Mihomo.currentNode || "Туннель поднят") : "Выключен")
                    subtitle: Mihomo.active !== "" ? Mihomo.active : Mihomo.core

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.pill(height)
                        color: win.up ? Theme.tone("vpn") : Qt.alpha(Theme.text, Theme.fillMuted)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            icon: Glyphs.vpn
                            size: Theme.fontIconSmall
                            fill: win.up ? 1 : 0
                            color: win.up ? Theme.onTone("vpn") : Theme.subtext0

                            // Only while the tunnel is actually coming up: the
                            // one moment the shell has nothing else to say for
                            // several seconds, and stopped the rest of the time
                            // because a permanent animation costs a fifth of a
                            // core for as long as it runs.
                            SequentialAnimation on opacity {
                                running: Mihomo.busy
                                loops: Animation.Infinite
                                onStopped: parent.opacity = 1
                                NumberAnimation { to: Theme.inkFaint; duration: Theme.animBusy; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: Theme.animBusy; easing.type: Easing.InOutQuad }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.up ? Mihomo.stop() : Mihomo.start(Mihomo.active)
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.gapTight
                    visible: win.up

                    KeyValue {
                        width: parent.width
                        key: "Задержка"
                        value: Mihomo.currentDelay !== undefined && Mihomo.currentDelay !== null
                            ? Mihomo.currentDelay + " мс" : "нет ответа"
                        valueColor: Mihomo.currentDelay === null ? Theme.red : Theme.text
                    }
                    KeyValue {
                        width: parent.width
                        key: "Приём / отдача"
                        value: Mihomo.formatSpeed(Mihomo.downSpeed) + " / "
                            + Mihomo.formatSpeed(Mihomo.upSpeed)
                    }
                    KeyValue {
                        width: parent.width
                        key: "Ядро"
                        value: Mihomo.core
                    }
                }

                Segmented {
                    width: parent.width
                    tone: "vpn"
                    model: ["Узлы", "Подписки"]
                    current: sheet.page
                    onPicked: i => sheet.page = i
                }

                // ── Узлы ──
                Column {
                    width: parent.width
                    spacing: Theme.spacing
                    visible: sheet.page === 0

                    Repeater {
                        model: win.nodes

                        delegate: DeviceRow {
                            id: nodeRow
                            required property var modelData
                            required property int index

                            readonly property var delay: Mihomo.delays[nodeRow.modelData]

                            width: parent.width
                            tone: "vpn"
                            glyph: Glyphs.earth
                            name: nodeRow.modelData
                            subtitle: Mihomo.proxyTypes[nodeRow.modelData] || ""
                            trailing: nodeRow.delay === undefined ? ""
                                : (nodeRow.delay === null ? "—" : nodeRow.delay + " мс")
                            active: nodeRow.modelData === Mihomo.currentNode
                            hasControl: false

                            onActivated: {
                                const group = Mihomo.primary;
                                if (group) Mihomo.select(group.name, nodeRow.modelData);
                            }
                            onRightClicked: Mihomo.probeDelays(Mihomo.primaryGroup)

                            // Rule 8: choosing a node repaints the list along
                            // its own length rather than on one frame.
                            opacity: 0
                            Component.onCompleted: intro.restart()
                            SequentialAnimation {
                                id: intro
                                PauseAnimation { duration: Direction.sweep(nodeRow.index, win.nodes.length) }
                                NumberAnimation {
                                    target: nodeRow; property: "opacity"; to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasized
                                }
                            }
                        }
                    }

                    EmptyRow {
                        width: parent.width
                        visible: win.nodes.length === 0
                        glyph: Glyphs.vpn
                        text: win.up ? "Узлов нет" : "Туннель выключен"
                    }
                }

                // ── Подписки ──
                Column {
                    width: parent.width
                    spacing: Theme.spacing
                    visible: sheet.page === 1

                    Repeater {
                        model: Mihomo.subscriptions

                        delegate: DeviceRow {
                            required property var modelData
                            width: parent.width
                            tone: "vpn"
                            glyph: Glyphs.earth
                            name: modelData.name || ""
                            subtitle: modelData.core || Mihomo.core
                            active: modelData.name === Mihomo.active
                            hasControl: false
                            trailing: modelData.name === Mihomo.active && win.up ? "активна" : ""

                            // Starting a subscription is starting the tunnel on
                            // it, which is what "switch to this one" means here.
                            onActivated: Mihomo.start(modelData.name)
                            onRightClicked: Mihomo.refreshSubscription(modelData.name)
                        }
                    }

                    EmptyRow {
                        width: parent.width
                        visible: Mihomo.subscriptions.length === 0
                        glyph: Glyphs.earth
                        text: "Подписок нет"
                    }
                }

                // The two things that are neither a node nor a subscription,
                // and both of which people reach for when something is wrong.
                Row {
                    width: parent.width
                    spacing: Theme.spacing

                    Chip {
                        tone: "vpn"
                        live: false
                        glyph: Glyphs.refresh
                        label: "Проверить задержки"
                        onClicked: Mihomo.probeDelays(Mihomo.primaryGroup)
                    }

                    Chip {
                        tone: "vpn"
                        live: false
                        glyph: Glyphs.close
                        label: "Сбросить соединения"
                        onClicked: Mihomo.resetConnections()
                    }
                }

                Text {
                    width: parent.width
                    visible: Mihomo.lastError !== ""
                    text: Mihomo.lastError
                    color: Theme.red
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
