import QtQuick
import Quickshell

// VPN control, in the shell.
//
// This replaces the GTK application entirely: subscriptions, node selection,
// latency and the tunnel itself are all here, and mihomo-gui is now a headless
// backend with no window of its own.
Item {
    id: root

    // Animations bind to this, not to the toggle. Created lazily, the panel is
    // born with the toggle already true, and an entry animation bound straight
    // to the toggle has nothing to animate from.
    readonly property bool open: Toggles.vpnPanelOpen && root.armed
    property bool armed: false
    Component.onCompleted: armTick.start()
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: root.armed = true
    }

    // Which selector group's nodes are on screen. Empty means the primary one,
    // and so does a name that no longer exists — restarting on a different
    // subscription replaces the whole group list.
    property string shownGroup: ""
    readonly property string activeGroup: (root.shownGroup !== ""
        && Mihomo.groupNamed(root.shownGroup)) ? root.shownGroup : Mihomo.primaryGroup
    readonly property var activeGroupData: Mihomo.groupNamed(root.activeGroup)

    property bool adding: false

    PanelWindow {
        id: win
        // See ControlCenter: mapping is an explicit bool so the exit animation
        // is never cut off by a visible-binding race.
        property bool mapped: false
        visible: mapped

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        focusable: root.open

        readonly property int cardWidth: 420
        readonly property int cardHeight: Math.min(Screen.height - Theme.barHeight - 60, 760)

        Timer {
            id: hideDelay
            interval: Theme.animExit + 40
            onTriggered: win.mapped = false
        }
        Connections {
            target: Toggles
            function onVpnPanelOpenChanged() {
                if (Toggles.vpnPanelOpen) {
                    hideDelay.stop();
                    win.mapped = true;
                    root.adding = false;
                    Mihomo.probeDelaysIfStale(root.activeGroup);
                } else {
                    hideDelay.restart();
                }
            }
        }

        // The group list arrives asynchronously — Python reports the process
        // state, then the controller is asked for the groups — so opening the
        // panel is usually too early to probe anything.
        Connections {
            target: Mihomo
            function onGroupsChanged() {
                if (Toggles.vpnPanelOpen) Mihomo.probeDelaysIfStale(root.activeGroup);
            }
        }
        Component.onCompleted: win.mapped = Toggles.vpnPanelOpen

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.vpnPanelOpen = false
        }

        Item {
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: Toggles.vpnPanelOpen = false

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

                opacity: root.open ? 1 : 0
                scale: root.open ? 1 : Theme.revealScale
                transformOrigin: Item.TopRight
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
                onCloseRequested: Toggles.vpnPanelOpen = false

                // Swallows clicks so the backdrop does not treat a click on the
                // panel itself as "outside".
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.topMargin: 36

                    // ── status header ──
                    Column {
                        id: head
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 12

                        Row {
                            spacing: 10

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34
                                radius: 17
                                color: Mihomo.running ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.text, 0.08)
                                Behavior on color { ColorAnimation { duration: Theme.animNormal } }

                                Text {
                                    anchors.centerIn: parent
                                    text: Glyphs.vpn
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 15
                                    color: Mihomo.running ? Theme.accent : Theme.subtext0
                                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                                }

                                // A ring that only exists while the tunnel is
                                // coming up: `start` blocks for several seconds
                                // and silence there reads as a hang.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.accent
                                    opacity: Mihomo.busy ? 0.8 : 0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                                    RotationAnimation on rotation {
                                        running: Mihomo.busy
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1400
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: Mihomo.busy
                                        ? "Подключение…"
                                        : (Mihomo.running ? (Mihomo.active || "Подключено") : "Отключено")
                                    color: Theme.text
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    text: {
                                        if (!Mihomo.running) return "Туннель не поднят";
                                        if (!Mihomo.controllerUp) return "Контроллер не отвечает";
                                        return Mihomo.currentNode !== "" ? Mihomo.currentNode : "Нода не выбрана";
                                    }
                                    color: Theme.subtext0
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: 210
                                }
                            }
                        }

                        // Traffic. Streamed from the controller, so this costs
                        // nothing while the tunnel is down.
                        Row {
                            visible: Mihomo.running && Mihomo.controllerUp
                            spacing: 16

                            Repeater {
                                model: [
                                    { glyph: Glyphs.chevronDown, value: Mihomo.downSpeed },
                                    { glyph: Glyphs.chevronUp, value: Mihomo.upSpeed }
                                ]

                                delegate: Row {
                                    id: rate
                                    required property var modelData
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: rate.modelData.glyph
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: Theme.accent
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Mihomo.formatSpeed(rate.modelData.value)
                                        color: Theme.subtext1
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: conflictText.implicitHeight + 16
                            radius: Theme.radius
                            visible: Mihomo.conflict !== ""
                            color: Qt.alpha(Theme.yellow, 0.16)

                            Text {
                                id: conflictText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: Mihomo.conflict + " держит маршрут по умолчанию — трафик пойдёт мимо туннеля"
                                color: Theme.yellow
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }

                        Text {
                            width: parent.width
                            visible: Mihomo.lastError !== ""
                            text: Mihomo.lastError
                            color: Theme.red
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        // ── actions ──
                        Row {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: [
                                    { label: Mihomo.running ? "Отключить" : "Подключить",
                                      accent: !Mihomo.running, act: "power", on: true },
                                    { label: "Пинг", accent: false, act: "delay",
                                      on: Mihomo.running && Mihomo.controllerUp },
                                    { label: "Сброс", accent: false, act: "reset",
                                      on: Mihomo.running && Mihomo.controllerUp }
                                ]

                                delegate: Rectangle {
                                    id: action
                                    required property var modelData

                                    width: (head.width - 16) / 3
                                    height: 32
                                    radius: Theme.radius
                                    color: !action.modelData.on || Mihomo.busy
                                        ? Qt.alpha(Theme.text, 0.06)
                                        : action.modelData.accent
                                            ? (actionArea.containsMouse ? Theme.accent : Qt.alpha(Theme.accent, 0.85))
                                            : Qt.alpha(Theme.text, actionArea.containsMouse ? 0.16 : 0.09)
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: action.modelData.act === "delay" && Mihomo.probing
                                            ? "…" : action.modelData.label
                                        color: !action.modelData.on || Mihomo.busy
                                            ? Theme.subtext0
                                            : (action.modelData.accent ? Theme.crust : Theme.text)
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: action.modelData.on && !Mihomo.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (action.modelData.act === "power") {
                                                if (Mihomo.running) Mihomo.stop();
                                                else Mihomo.start();
                                            } else if (action.modelData.act === "delay") {
                                                Mihomo.probeDelays(root.activeGroup);
                                            } else {
                                                Mihomo.resetConnections();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── group tabs ──
                        // Only when there is a choice to make: one group is the
                        // common case and a single tab is furniture.
                        Row {
                            width: parent.width
                            spacing: 6
                            visible: Mihomo.groups.length > 1

                            Repeater {
                                model: Mihomo.groups

                                delegate: Rectangle {
                                    id: tab
                                    required property var modelData

                                    readonly property bool selected: tab.modelData.name === root.activeGroup
                                    width: tabText.width + 20
                                    height: 25
                                    radius: 12.5
                                    color: tab.selected ? Qt.alpha(Theme.accent, 0.2)
                                        : (tabArea.containsMouse ? Qt.alpha(Theme.text, 0.10) : "transparent")
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        id: tabText
                                        anchors.centerIn: parent
                                        text: tab.modelData.name
                                        color: tab.selected ? Theme.accent : Theme.subtext0
                                        font.pixelSize: 11
                                        font.bold: tab.selected
                                    }

                                    MouseArea {
                                        id: tabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.shownGroup = tab.modelData.name
                                    }
                                }
                            }
                        }
                    }

                    // ── footer: subscriptions ──
                    Column {
                        id: foot
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Подписки"
                                color: Theme.subtext0
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.adding ? "отмена" : "добавить"
                                color: addArea.containsMouse ? Theme.accent : Theme.subtext0
                                font.pixelSize: 10
                                font.underline: addArea.containsMouse
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                MouseArea {
                                    id: addArea
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.adding = !root.adding
                                }
                            }
                        }

                        VpnSubscriptionEditor {
                            width: parent.width
                            visible: root.adding
                            busy: Mihomo.busy
                            onSubmitted: (name, url, userAgent) => {
                                Mihomo.addSubscription(name, url, userAgent);
                                root.adding = false;
                            }
                        }

                        // Bounded and scrollable. Six subscriptions is 350px of
                        // rows, and letting the footer take that left the node
                        // list — the thing the panel is actually for — one row
                        // tall.
                        Flickable {
                            width: parent.width
                            height: Math.min(subsColumn.implicitHeight, 172)
                            contentHeight: subsColumn.implicitHeight
                            clip: true
                            visible: !root.adding

                            Column {
                                id: subsColumn
                                width: parent.width
                                spacing: 5

                                Repeater {
                                    model: Mihomo.subscriptions

                                    delegate: VpnSubscriptionRow {
                                        width: subsColumn.width
                                        busy: Mihomo.busy

                                        onConnectRequested: Mihomo.start(modelData.name)
                                        onRefreshRequested: Mihomo.refreshSubscription(modelData.name)
                                        onRemoveRequested: Mihomo.removeSubscription(modelData.name)
                                    }
                                }
                            }
                        }
                    }

                    // ── node list ──
                    Flickable {
                        anchors.top: head.bottom
                        anchors.topMargin: 14
                        anchors.bottom: foot.top
                        anchors.bottomMargin: 14
                        anchors.left: parent.left
                        anchors.right: parent.right
                        contentHeight: nodes.implicitHeight
                        clip: true

                        Column {
                            id: nodes
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: root.activeGroupData ? root.activeGroupData.nodes : []

                                delegate: VpnNodeRow {
                                    required property var modelData
                                    required property int index

                                    width: nodes.width
                                    name: modelData
                                    current: root.activeGroupData
                                        && root.activeGroupData.now === modelData
                                    delay: Mihomo.delays[modelData]
                                    probing: Mihomo.probing

                                    // A cascade rather than a wall of rows
                                    // arriving at once. Theme.stagger caps the
                                    // delay, so a fifty-node list is not still
                                    // arriving a second and a half later.
                                    opacity: root.open ? 1 : 0
                                    Behavior on opacity {
                                        SequentialAnimation {
                                            PauseAnimation { duration: root.open ? Theme.stagger(index) : 0 }
                                            NumberAnimation {
                                                duration: Theme.animNormal
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.easeEmphasized
                                            }
                                        }
                                    }

                                    onActivated: Mihomo.select(root.activeGroup, modelData)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Mihomo.running && Mihomo.groups.length === 0
                        text: Mihomo.controllerUp ? "Групп нет" : "Контроллер не отвечает"
                        color: Theme.subtext0
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
