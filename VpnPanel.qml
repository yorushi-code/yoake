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

    readonly property bool open: arm.open
    property PanelArm _arm: PanelArm { id: arm; requested: Toggles.vpnPanelOpen }

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
            width: Theme.sheetList
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
                    // Down is a state and the empty row says so in those words;
                    // the title names the subject instead. "Подключаюсь…" stays
                    // a title because it is not a state the body reports -- it
                    // is an operation in flight, and the header is where this
                    // shell puts the thing that is currently happening.
                    title: Mihomo.busy ? "Подключаюсь…"
                        : (win.up ? (Mihomo.currentNode || "Туннель поднят") : "VPN")
                    subtitle: Mihomo.active !== "" ? Mihomo.active : Mihomo.core

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.pill(height)
                        // On/off, not chosen -- see NetworkPanel.
                        color: Qt.alpha(Theme.text, Theme.fillMuted)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        MaterialSymbol {
                            id: tunnelGlyph
                            anchors.centerIn: parent
                            icon: Glyphs.vpn
                            size: Theme.fontIconSmall
                            fill: win.up ? 1 : 0
                            color: win.up ? Theme.tone("vpn") : Theme.subtext0

                            // Only while the tunnel is actually coming up: the
                            // one moment the shell has nothing else to say for
                            // several seconds, and stopped the rest of the time
                            // because a permanent animation costs a fifth of a
                            // core for as long as it runs.
                            SequentialAnimation on opacity {
                                running: Mihomo.busy
                                loops: Animation.Infinite
                                // By id. An animation is not a visual item and
                                // has no `parent`, so this wrote to nothing and
                                // the glyph stayed at whatever opacity the loop
                                // was interrupted on -- a tunnel that finished
                                // connecting kept a half-faded icon until the
                                // panel was rebuilt.
                                onStopped: tunnelGlyph.opacity = 1
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

                // ── The way out of a jam ──
                //
                // Restored after the rewrite dropped it. Another core holding
                // the default route is the one failure where the tunnel looks
                // perfectly healthy and none of the traffic is in it, and this
                // banner is the only place the shell ever says so. Losing it
                // was the clearest case of a rewrite being smaller rather than
                // better.
                Rectangle {
                    width: parent.width
                    height: conflictColumn.implicitHeight + Theme.gapCard
                    radius: Theme.radiusChip
                    visible: Mihomo.conflict !== ""
                    color: Qt.alpha(Theme.yellow, Theme.tintSubtle)

                    Column {
                        id: conflictColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacing

                        Text {
                            width: parent.width
                            text: Mihomo.conflict
                                + " держит маршрут по умолчанию — трафик пойдёт мимо туннеля"
                            color: Theme.yellow
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            wrapMode: Text.WordWrap
                        }

                        // Only when there is a service to stop. Happ's tunnel
                        // daemon runs as root, so this raises a polkit prompt
                        // rather than acting silently.
                        Chip {
                            visible: Mihomo.conflictCanStop
                            tone: "alert"
                            live: true
                            glyph: Glyphs.stop
                            label: "Остановить " + Mihomo.conflict
                            onClicked: if (!Mihomo.busy) Mihomo.stopRival()
                        }
                    }
                }

                // ── Where the traffic actually comes out ──
                //
                // Also restored. A tunnel that is up and a tunnel that is
                // carrying your traffic are different facts, and this is the
                // only one of the two the shell can check rather than assume.
                Row {
                    width: parent.width
                    spacing: Theme.spacing
                    visible: Mihomo.running && (Mihomo.egress !== null || Mihomo.checking)

                    MaterialSymbol {
                        id: egressGlyph
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Glyphs.earth
                        size: Theme.fontIconMicro
                        fill: 1
                        color: Mihomo.leaking ? Theme.red : Theme.tone("vpn")
                        opacity: Mihomo.checking ? Theme.inkFaint : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    Text {
                        id: egressText
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (Mihomo.egress === null) return "Проверяю выход…";
                            if (Mihomo.leaking) return "Трафик идёт мимо туннеля";
                            const e = Mihomo.egress;
                            return e.ip + (e.country ? " · " + e.country : "");
                        }
                        color: Mihomo.leaking ? Theme.red : Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.underline: egressHit.containsMouse && !Mihomo.checking
                    }

                    MouseArea {
                        id: egressHit
                        width: egressGlyph.width + egressText.width + Theme.spacing
                        height: egressText.height + Theme.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        hoverEnabled: true
                        enabled: !Mihomo.checking
                        cursorShape: Qt.PointingHandCursor
                        // The reading belongs to whichever node was selected
                        // when it was taken, so it needs a way to be retaken
                        // without reopening the panel.
                        onClicked: Mihomo.check()
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
                            id: subRow
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
                            // Refresh, core and delete are three actions and a
                            // row has two gestures, so they go where every other
                            // list of actions in this shell goes.
                            onRightClicked: Menus.toggle(subRow.menuId)

                            readonly property string menuId:
                                Menus.idFor(win, "vpnsub/" + (modelData.name || ""))

                            ActionMenu {
                                menuId: subRow.menuId
                                anchorItem: subRow
                                open: Menus.isOpen(subRow.menuId)
                                model: Menus.isOpen(subRow.menuId) ? [
                                    {
                                        text: "Обновить",
                                        glyph: Glyphs.refresh,
                                        action: () => Mihomo.refreshSubscription(subRow.modelData.name)
                                    },
                                    { separator: true },
                                    {
                                        text: "Ядро: mihomo",
                                        checkable: true,
                                        checked: (subRow.modelData.core || Mihomo.core) === "mihomo",
                                        action: () => Mihomo.setCore(subRow.modelData.name, "mihomo")
                                    },
                                    {
                                        text: "Ядро: sing-box",
                                        checkable: true,
                                        checked: (subRow.modelData.core || Mihomo.core) === "sing-box",
                                        action: () => Mihomo.setCore(subRow.modelData.name, "sing-box")
                                    },
                                    {
                                        text: "Ядро: xray",
                                        checkable: true,
                                        checked: (subRow.modelData.core || Mihomo.core) === "xray",
                                        action: () => Mihomo.setCore(subRow.modelData.name, "xray")
                                    },
                                    { separator: true },
                                    {
                                        text: "Удалить подписку",
                                        glyph: Glyphs.close,
                                        destructive: true,
                                        action: () => Mihomo.removeSubscription(subRow.modelData.name)
                                    }
                                ] : []
                            }
                        }
                    }

                    // Adding one. Restored: the rewrite dropped the editor
                    // entirely, so a subscription could be started, refreshed
                    // and deleted but never added -- the shell could operate the
                    // list it was given and not build one.
                    VpnSubscriptionEditor {
                        width: parent.width
                        busy: Mihomo.busy
                        onSubmitted: (name, url, userAgent) => {
                            Mihomo.addSubscription(name, url, userAgent);
                            reset();
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
