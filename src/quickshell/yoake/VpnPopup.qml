import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../reusables"
import "../"

// The VPN panel.
//
// The shell this came from had its own component library -- Surface, Chip,
// Sheet, Segmented -- and porting the old panel verbatim would have meant
// porting all of that with it. What was worth carrying is underneath: Mihomo
// and MihomoApi came across whole, because the hard part was never the panel.
// This is that state, drawn with the components this shell already has.
Item {
    id: window
    focus: true

    function s(val) { return Scaler.s(val); }

    // Which group's members are listed. PROXY is the one that matters on a
    // normal config; the rest are reachable through the tabs when a config
    // has them.
    property string viewGroup: ""
    readonly property var currentGroup: {
        if (window.viewGroup !== "") {
            const g = Mihomo.groupNamed(window.viewGroup);
            if (g) return g;
        }
        return Mihomo.primary || (Mihomo.groups.length > 0 ? Mihomo.groups[0] : null);
    }
    readonly property var nodeList: currentGroup ? (currentGroup.nodes || []) : []

    // Latency is a judgement, not a number: the thresholds are where a tunnel
    // stops being usable for a call, then for a page.
    function delayColor(ms) {
        if (ms === undefined || ms === null) return ThemeBackend.subtext0;
        if (ms < 150) return ThemeBackend.green;
        if (ms < 400) return ThemeBackend.yellow;
        return ThemeBackend.red;
    }
    function delayText(name) {
        if (!Mihomo.measurable(name)) return "";
        const d = Mihomo.delays[name];
        if (d === undefined) return "—";
        if (d === null) return "нет";
        return d + " мс";
    }

    // Asking costs up to twelve seconds and only matters while something is
    // displaying the answer, so the flag is held exactly as long as the panel.
    Component.onCompleted: {
        Mihomo.watched = true;
        Mihomo.refresh();
    }
    Component.onDestruction: Mihomo.watched = false;

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: window.s(14)
        spacing: window.s(10)

        // ── state ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: window.s(76)
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.surface0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: window.s(16)
                anchors.rightMargin: window.s(16)
                spacing: window.s(14)

                Rectangle {
                    Layout.preferredWidth: window.s(44)
                    Layout.preferredHeight: window.s(44)
                    radius: width / 2
                    color: Mihomo.running ? (Mihomo.leaking ? ThemeBackend.red : ThemeBackend.teal)
                                          : ThemeBackend.surface1
                    Behavior on color { ColorAnimation { duration: 220 } }
                    Text {
                        anchors.centerIn: parent
                        text: Mihomo.running ? "󰦝" : "󰦞"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(20)
                        color: Mihomo.running ? ThemeBackend.base : ThemeBackend.subtext0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(2)
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (Mihomo.conflict !== "") return Mihomo.conflict + " перехватывает трафик";
                            if (!Mihomo.running) return "Туннель выключен";
                            if (!Mihomo.controllerUp) return "Контроллер не отвечает";
                            if (Mihomo.leaking) return "Трафик идёт мимо туннеля";
                            return Mihomo.currentNode !== "" ? Mihomo.currentNode : "Туннель поднят";
                        }
                        elide: Text.ElideRight
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(15)
                        font.weight: Font.Medium
                        color: ThemeBackend.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            let bits = [Mihomo.core];
                            if (Mihomo.active !== "") bits.push(Mihomo.active);
                            if (Mihomo.tunActive) bits.push("TUN");
                            return bits.join(" · ");
                        }
                        elide: Text.ElideRight
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(11)
                        color: ThemeBackend.subtext0
                    }
                }

                ColumnLayout {
                    visible: Mihomo.running && Mihomo.controllerUp
                    spacing: window.s(2)
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "↓ " + Mihomo.formatSpeed(Mihomo.downSpeed)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(11)
                        font.variableAxes: ({})
                        color: ThemeBackend.text
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "↑ " + Mihomo.formatSpeed(Mihomo.upSpeed)
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(11)
                        color: ThemeBackend.subtext0
                    }
                }
            }
        }

        // ── a rival tunnel, which is the one fault the panel cannot fix by
        // itself: two of them own the same routes and the loser is silent ──
        Rectangle {
            visible: Mihomo.conflict !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: window.s(46)
            radius: ThemeBackend.borderRadius
            color: Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.14)
            border.width: 1
            border.color: ThemeBackend.red

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: window.s(14)
                anchors.rightMargin: window.s(8)
                spacing: window.s(10)
                Text {
                    Layout.fillWidth: true
                    text: "Сначала нужно остановить " + Mihomo.conflict
                    elide: Text.ElideRight
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(12)
                    color: ThemeBackend.text
                }
                ClickButton {
                    visible: Mihomo.conflictCanStop
                    height: window.s(30)
                    cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                    horizontalPadding: window.s(12)
                    buttonText: "Остановить"
                    textFontSize: window.s(11)
                    accentColor: ThemeBackend.red
                    textColor: ThemeBackend.base
                    onClicked: Mihomo.stopRival()
                }
            }
        }

        // ── actions ──
        RowLayout {
            Layout.fillWidth: true
            spacing: window.s(8)

            ClickButton {
                Layout.fillWidth: true
                height: window.s(38)
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: Mihomo.running ? "󰐊" : "󰓛"
                iconFontSize: window.s(14)
                buttonText: Mihomo.busy ? "..." : (Mihomo.running ? "Выключить" : "Включить")
                textFontSize: window.s(12)
                accentColor: Mihomo.running ? ThemeBackend.surface1 : ThemeBackend.teal
                textColor: Mihomo.running ? ThemeBackend.text : ThemeBackend.base
                onClicked: Mihomo.running ? Mihomo.stop() : Mihomo.start()
            }

            ClickButton {
                height: window.s(38)
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: window.s(14)
                buttonIcon: "󱎫"
                iconFontSize: window.s(14)
                buttonText: Mihomo.probing ? "Замеряю" : "Замерить"
                textFontSize: window.s(12)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: {
                    if (window.currentGroup) Mihomo.probeDelays(window.currentGroup.name);
                }
            }

            ClickButton {
                height: window.s(38)
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: window.s(14)
                buttonIcon: "󰇧"
                iconFontSize: window.s(14)
                buttonText: Mihomo.checking ? "Проверяю" : "Выход"
                textFontSize: window.s(12)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: Mihomo.check()
            }
        }

        // ── groups, only when a config actually has more than one ──
        Flow {
            Layout.fillWidth: true
            visible: Mihomo.groups.length > 1
            spacing: window.s(6)
            Repeater {
                model: Mihomo.groups
                ClickButton {
                    required property var modelData
                    height: window.s(28)
                    cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                    horizontalPadding: window.s(12)
                    buttonText: modelData.name
                    textFontSize: window.s(11)
                    property bool picked: window.currentGroup && window.currentGroup.name === modelData.name
                    accentColor: picked ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: picked ? ThemeBackend.base : ThemeBackend.subtext1
                    onClicked: window.viewGroup = modelData.name
                }
            }
        }

        // ── nodes ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.surface0
            clip: true

            Text {
                anchors.centerIn: parent
                width: parent.width - window.s(40)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: window.nodeList.length === 0
                text: Mihomo.running ? "Контроллер пока не отдал список узлов"
                                     : "Включи туннель, чтобы увидеть узлы"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: window.s(12)
                color: ThemeBackend.subtext0
            }

            ListView {
                anchors.fill: parent
                anchors.margins: window.s(6)
                visible: window.nodeList.length > 0
                model: window.nodeList
                spacing: window.s(2)
                clip: true

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: window.s(40)
                    radius: Math.max(0, ThemeBackend.borderRadius - 2)
                    readonly property bool picked: window.currentGroup
                        && window.currentGroup.now === modelData
                    color: picked ? ThemeBackend.surface2
                                  : (nodeMouse.containsMouse ? ThemeBackend.surface1 : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: window.s(12)
                        anchors.rightMargin: window.s(12)
                        spacing: window.s(10)

                        Text {
                            text: parent.parent.picked ? "󰄬" : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(13)
                            color: ThemeBackend.teal
                            Layout.preferredWidth: window.s(14)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(12)
                            color: ThemeBackend.text
                        }
                        Text {
                            text: window.delayText(modelData)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(11)
                            color: window.delayColor(Mihomo.delays[modelData])
                        }
                    }

                    MouseArea {
                        id: nodeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (window.currentGroup)
                                Mihomo.select(window.currentGroup.name, modelData);
                        }
                    }
                }
            }
        }

        // ── where traffic comes out ──
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: {
                if (Mihomo.lastError !== "") return Mihomo.lastError;
                if (Mihomo.checking) return "Проверяю, откуда выходит трафик...";
                if (!Mihomo.egress) return "Выход не проверялся";
                const e = Mihomo.egress;
                const where = (e.ip || "?") + (e.country ? " · " + e.country : "");
                return Mihomo.leaking ? ("Утечка: " + where) : ("Выход: " + where);
            }
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(11)
            color: (Mihomo.leaking || Mihomo.lastError !== "") ? ThemeBackend.red : ThemeBackend.subtext0
        }
    }
}
