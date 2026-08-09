import QtQuick

// Tunnel state in the bar: on/off, the active node's latency, and live
// throughput while traffic is moving.
//
// Speed is only shown when there is any, so the widget stays a glyph on an idle
// machine instead of a permanent "0 Б/с" that says nothing.
Item {
    id: root

    property var barWindow: null

    // One menu key per bar, so the copy of this widget on a second monitor does
    // not share one open-menu key with this one.
    readonly property string menuId: Menus.idFor(root.barWindow, "vpn")

    // implicitWidth off the row's *implicit* width, and the row anchored
    // rather than centred: reading .width here while the row centres itself
    // in that same width is a cycle, and Qt resolves it in no fixed order.
    // Whenever the content changed width -- VPN going from "вкл" to a speed,
    // volume from 50%% to 100%% -- the row sat off-centre inside the old width
    // for a frame, which is the clipped percentage at the island's edge.
    implicitWidth: vpnRow.implicitWidth
    width: implicitWidth
    height: Theme.barHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property bool up: Mihomo.running && Mihomo.controllerUp
    readonly property real total: Mihomo.upSpeed + Mihomo.downSpeed
    // A few hundred bytes a second is keepalive traffic, not activity worth
    // widening the island for.
    readonly property bool busy: root.up && root.total > 2048

    readonly property color stateColor: {
        if (Mihomo.busy) return Theme.yellow;
        if (!root.up) return Theme.subtext0;
        if (Mihomo.currentDelay === null) return Theme.red;
        return Theme.accent;
    }

    Row {
        id: vpnRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight

        // The node, by name.
        //
        // It said "вкл", or a latency, or a transfer rate -- three answers to
        // questions nobody had. The one thing worth two centimetres of a bar
        // that is on screen all day is *which exit the traffic is taking*, and
        // that was only discoverable by opening the panel.
        //
        // The latency moves to the value slot, where it belongs: it qualifies
        // the node rather than replacing it.
        Chip {
            id: vpnChip
            anchors.verticalCenter: parent.verticalCenter
            tone: "vpn"
            live: root.up
            glyph: Glyphs.vpn
            label: {
                if (Mihomo.busy) return "…";
                if (!root.up) return "выкл";
                return Mihomo.currentNode !== undefined && Mihomo.currentNode !== ""
                    ? Mihomo.currentNode : "вкл";
            }
            labelCap: 110
            value: {
                if (!root.up || Mihomo.busy) return "";
                if (root.busy) return Mihomo.formatSpeed(root.total);
                return Mihomo.currentDelay !== undefined && Mihomo.currentDelay !== null
                    ? Mihomo.currentDelay + " мс" : "";
            }
            alert: root.up && Mihomo.currentDelay === null
            onClicked: Toggles.vpnPanelOpen = !Toggles.vpnPanelOpen
            onRightClicked: {
                Mihomo.probeDelaysIfStale(Mihomo.primaryGroup);
                Menus.toggle(root.menuId);
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Mihomo.probeDelaysIfStale(Mihomo.primaryGroup);
                Menus.toggle(root.menuId);
                return;
            }
        }
    }

    // The tunnel was the one status widget in the bar with no menu, in a shell
    // whose own cheat sheet promises one on every widget -- and it is the widget
    // where the two things people actually want, switching node and turning the
    // thing off, otherwise cost opening a whole panel.
    ActionMenu {
        id: menu
        menuId: root.menuId
        anchorItem: root
        open: Menus.isOpen(root.menuId)
        model: {
            if (!Menus.isOpen(root.menuId)) return [];

            const out = [{
                text: root.up ? "Отключить" : "Включить",
                glyph: Glyphs.vpn,
                action: () => root.up ? Mihomo.stop() : Mihomo.start(Mihomo.active)
            }];

            const group = Mihomo.primary;
            if (root.up && group) {
                // Servers only, quickest first. AUTO and DIRECT belong in the
                // panel: this list is for picking a way out, not a policy.
                const nodes = (group.nodes || [])
                    .filter(n => !Mihomo.isSelectable(n))
                    .filter(n => Mihomo.delays[n] !== null && Mihomo.delays[n] !== undefined)
                    .sort((a, b) => Mihomo.delays[a] - Mihomo.delays[b])
                    .slice(0, 6);
                if (nodes.length > 0) out.push({ separator: true });
                for (const node of nodes) {
                    out.push({
                        text: node + "  " + Mihomo.delays[node] + " мс",
                        checkable: true,
                        checked: node === Mihomo.currentNode,
                        action: () => Mihomo.select(group.name, node)
                    });
                }
            }

            out.push({ separator: true });
            if (root.up) {
                out.push({
                    text: "Проверить задержки",
                    glyph: Glyphs.refresh,
                    action: () => Mihomo.probeDelays(Mihomo.primaryGroup)
                });
            }
            out.push({
                text: "Панель VPN",
                glyph: Glyphs.cog,
                action: () => Toggles.exclusive("vpnPanel")
            });
            return out;
        }
    }

    // A card, not a tooltip. This is the widget in the bar with the most to say
    // and it was saying the least: the tunnel's node, its latency, where it
    // comes out and how much is moving through it are four facts a tooltip has
    // no room for, and the audio, network and battery chips already answer on
    // hover this way.
    //
    // The egress IP is deliberately not here. It is in the panel, which is
    // opened on purpose; this card appears whenever the pointer crosses the bar
    // and lands in every screenshot taken of it.
    Popover {
        anchorItem: root
        hovered: ma.containsMouse && !Toggles.vpnPanelOpen && !Menus.isOpen(root.menuId)
        minWidth: 248

        Column {
            spacing: Theme.gapWide

            Row {
                spacing: Theme.gapWide

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Glyphs.vpn
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIcon
                    color: root.stateColor
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: 190
                        text: {
                            if (Mihomo.busy) return "Подключаюсь…";
                            if (!root.up) return "VPN отключён";
                            return Mihomo.currentNode || Mihomo.active || "Туннель поднят";
                        }
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        width: 190
                        visible: text !== ""
                        text: {
                            if (!root.up) return "";
                            const bits = [];
                            if (Mihomo.currentDelay !== undefined && Mihomo.currentDelay !== null) {
                                bits.push(Mihomo.currentDelay + " мс");
                            } else {
                                bits.push("нет отклика");
                            }
                            // Country only, never the address.
                            if (Mihomo.egress && Mihomo.egress.country) {
                                bits.push(Mihomo.egress.country);
                            }
                            return bits.join("  ·  ");
                        }
                        color: Mihomo.currentDelay === null ? Theme.red : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.features: ({ "tnum": 1 })
                        elide: Text.ElideRight
                    }
                }
            }

            // Shown even at zero here, unlike in the bar. The bar hides an idle
            // number to keep the island from carrying a permanent "0 Б/с"; a
            // card the user asked for should answer the question it was opened
            // to answer.
            Row {
                spacing: Theme.gapSection
                visible: root.up

                Repeater {
                    model: [
                        { glyph: Glyphs.download, value: Mihomo.formatSpeed(Mihomo.downSpeed) },
                        { glyph: Glyphs.upload, value: Mihomo.formatSpeed(Mihomo.upSpeed) }
                    ]

                    delegate: Row {
                        id: flow
                        required property var modelData
                        spacing: Theme.spacing

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: flow.modelData.glyph
                            font.family: Theme.fontIconFamily
                            font.pixelSize: Theme.fontIconMicro
                            color: Theme.subtext0
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: flow.modelData.value
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }

            Text {
                width: 222
                visible: Mihomo.leaking
                text: "Трафик идёт мимо туннеля"
                color: Theme.red
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                wrapMode: Text.Wrap
            }

            Rectangle {
                width: 222
                height: 1
                color: Qt.alpha(Theme.text, Theme.fillHover)
            }

            // Sibling of the row, not a child of it: a MouseArea inside a Row
            // is laid out as another column of it.
            Item {
                width: 222
                height: 22

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: root.up ? Glyphs.close : Glyphs.vpn
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIconMicro
                        color: Theme.subtext1
                    }

                    Text {
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        text: root.up ? "Отключить туннель" : "Подключить"
                        color: powerHit.containsMouse ? Theme.text : Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }
                }

                MouseArea {
                    id: powerHit
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !Mihomo.busy
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.up ? Mihomo.stop() : Mihomo.start(Mihomo.active)
                }
            }

            Text {
                text: "ЛКМ — ноды и подписки"
                color: Qt.alpha(Theme.subtext0, Theme.inkStrong)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
            }
        }
    }
}
