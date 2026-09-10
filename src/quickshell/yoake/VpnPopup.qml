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

    // Подвал. Ошибка ядра -- строка из его журнала, а не сообщение человеку,
    // поэтому она подписана как журнальная и режется по ширине: раньше она
    // висела красным во всю панель и выглядела страшнее, чем есть.
    readonly property bool footerBad: Mihomo.leaking || Mihomo.lastError !== ""
    readonly property string footerText: {
        if (Mihomo.lastError !== "") return "Ядро: " + Mihomo.lastError;
        if (Mihomo.checking) return "Проверяю, откуда выходит трафик...";
        if (!Mihomo.egress) return "Выход не проверялся";
        const e = Mihomo.egress;
        const where = (e.ip || "?") + (e.country ? " · " + e.country : "");
        return Mihomo.leaking ? ("Утечка: " + where) : ("Выход: " + where);
    }

    // Появление и медленный дрейф пятен -- как у остальных панелей оболочки.
    property real introMain: 0
    NumberAnimation on introMain {
        from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo; running: window.visible
    }
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: window.visible
    }
    readonly property color moodColor: Mihomo.running
        ? (Mihomo.leaking ? ThemeBackend.red : ThemeBackend.teal)
        : ThemeBackend.surface2

    // Which group's members are listed. PROXY is the one that matters on a
    // normal config; the rest are reachable through the tabs when a config
    // has them.
    // Подписки живут отдельной секцией и по умолчанию свёрнуты: главное
    // содержимое панели -- узлы, и отдавать им половину высоты ради списка,
    // который трогают раз в месяц, неправильно.
    property bool subsOpen: false
    property bool addOpen: false

    property string viewGroup: ""
    readonly property var currentGroup: {
        if (window.viewGroup !== "") {
            const g = Mihomo.groupNamed(window.viewGroup);
            if (g) return g;
        }
        return Mihomo.primary || (Mihomo.groups.length > 0 ? Mihomo.groups[0] : null);
    }
    readonly property var nodeList: currentGroup ? (currentGroup.nodes || []) : []

    // Measure on arrival rather than on a button. The list is worth nothing
    // without the numbers, and probeDelaysIfStale only spends a round of
    // requests when some node in the group has never been measured -- so
    // reopening the panel, or flipping back to a tab already seen, is free.
    // Groups land asynchronously, so this hangs off the group becoming known
    // rather than off Component.onCompleted, which is too early.
    onCurrentGroupChanged: {
        if (window.visible && currentGroup) Mihomo.probeDelaysIfStale(currentGroup.name);
    }

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
    // Панель может быть создана заранее и висеть невидимой в
    // preloaderContainer -- тогда будить VPN нельзя. Раньше здесь стоял
    // Component.onCompleted, и из-за этого проверка выхода (до двенадцати
    // секунд сетевых запросов) уходила при каждом входе в систему, ради
    // ответа, на который никто не смотрел. Признак -- видимость, а не
    // создание.
    function _wake() {
        if (!window.visible) return;
        Mihomo.refresh();
        Mihomo.checkTunDns();
        if (window.currentGroup) Mihomo.probeDelaysIfStale(window.currentGroup.name);
    }

    onVisibleChanged: {
        Mihomo.watched = window.visible;
        if (window.visible) window._wake();
    }

    Component.onCompleted: if (window.visible) { Mihomo.watched = true; window._wake(); }
    Component.onDestruction: Mihomo.watched = false

    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * window.introMain)
        opacity: window.introMain
        transform: Translate { y: window.s(20) * (1 - window.introMain) }

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.base
            border.color: ThemeBackend.surface0
            border.width: 1
            clip: true

            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(120)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(80)
                opacity: Mihomo.running ? 0.05 : 0.02
                color: window.moodColor
                Behavior on color { ColorAnimation { duration: 800 } }
            }
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-120)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(90)
                opacity: Mihomo.running ? 0.04 : 0.015
                color: window.moodColor
                Behavior on color { ColorAnimation { duration: 800 } }
            }

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

                // Туннель поднят, но резолвер перенаправлен. Отдельная полоса, а не
                // строка в подвале: без неё панель выглядела исправной ровно тогда,
                // когда интернета не было.
                Rectangle {
                    visible: Mihomo.running && Mihomo.resolvedHijacked
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(52)
                    radius: ThemeBackend.borderRadius
                    color: Qt.rgba(ThemeBackend.peach.r, ThemeBackend.peach.g, ThemeBackend.peach.b, 0.14)
                    border.width: 1
                    border.color: ThemeBackend.peach

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: window.s(14)
                        anchors.rightMargin: window.s(14)
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        text: "systemd-resolved перехвачен туннелем — имена могут не разрешаться"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(12)
                        color: ThemeBackend.text
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

                // ── сколько трафика вообще идёт через правила ──
                // Контроллер это умеет и без yworld, а вопрос «почему сайт открылся
                // мимо туннеля» чаще всего именно про режим.
                RowLayout {
                    Layout.fillWidth: true
                    visible: Mihomo.running && Mihomo.mode !== ""
                    spacing: window.s(6)

                    Repeater {
                        model: [
                            { id: "rule", label: "По правилам" },
                            { id: "global", label: "Через прокси" },
                            { id: "direct", label: "Напрямую" }
                        ]
                        ClickButton {
                            required property var modelData
                            height: window.s(28)
                            cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                            horizontalPadding: window.s(14)
                            buttonText: modelData.label
                            textFontSize: window.s(11)
                            property bool picked: Mihomo.mode === modelData.id
                            accentColor: picked ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: picked ? ThemeBackend.base : ThemeBackend.subtext1
                            onClicked: Mihomo.setMode(modelData.id)
                        }
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

                // ── подписки ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: subsCol.implicitHeight + window.s(16)
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.surface0
                    clip: true
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: subsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: window.s(8)
                        spacing: window.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: window.s(8)

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: window.s(6)
                                text: "Подписки · " + Mihomo.subscriptions.length
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: window.s(12)
                                color: ThemeBackend.subtext1
                            }
                            ClickButton {
                                height: window.s(26)
                                cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                                horizontalPadding: window.s(10)
                                buttonIcon: "󰐕"
                                iconFontSize: window.s(13)
                                accentColor: window.addOpen ? ThemeBackend.mauve : ThemeBackend.surface1
                                textColor: window.addOpen ? ThemeBackend.base : ThemeBackend.text
                                onClicked: { window.addOpen = !window.addOpen; if (window.addOpen) window.subsOpen = true; }
                            }
                            ClickButton {
                                height: window.s(26)
                                cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                                horizontalPadding: window.s(10)
                                buttonIcon: window.subsOpen ? "󰅃" : "󰅀"
                                iconFontSize: window.s(13)
                                accentColor: ThemeBackend.surface1
                                textColor: ThemeBackend.text
                                onClicked: window.subsOpen = !window.subsOpen
                            }
                        }

                        // добавление: имя и ссылка, разворачивается по кнопке
                        ColumnLayout {
                            visible: window.addOpen
                            Layout.fillWidth: true
                            spacing: window.s(6)

                            Input {
                                id: subName
                                Layout.fillWidth: true
                                placeholderText: "Имя подписки"
                                fontPixelSize: window.s(12)
                                baseColor: ThemeBackend.surface1
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.text
                                borderColor: ThemeBackend.surface2
                            }
                            Input {
                                id: subUrl
                                Layout.fillWidth: true
                                placeholderText: "Ссылка на подписку"
                                fontPixelSize: window.s(12)
                                baseColor: ThemeBackend.surface1
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.text
                                borderColor: ThemeBackend.surface2
                            }
                            ClickButton {
                                Layout.fillWidth: true
                                height: window.s(32)
                                cornerRadius: Math.max(0, ThemeBackend.borderRadius - 2)
                                buttonText: Mihomo.busy ? "..." : "Добавить"
                                textFontSize: window.s(12)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.base
                                onClicked: {
                                    if (subName.text.trim() === "" || subUrl.text.trim() === "") return;
                                    Mihomo.addSubscription(subName.text.trim(), subUrl.text.trim(), "");
                                    subName.text = ""; subUrl.text = ""; window.addOpen = false;
                                }
                            }
                        }

                        Repeater {
                            model: window.subsOpen ? Mihomo.subscriptions : []

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(38)
                                radius: Math.max(0, ThemeBackend.borderRadius - 2)
                                readonly property bool isActive: modelData.name === Mihomo.active
                                color: isActive ? ThemeBackend.surface2 : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(10)
                                    anchors.rightMargin: window.s(6)
                                    spacing: window.s(6)

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || ""
                                        elide: Text.ElideRight
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: window.s(12)
                                        color: ThemeBackend.text
                                    }
                                    Text {
                                        text: modelData.core || Mihomo.core
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: window.s(10)
                                        color: ThemeBackend.subtext0
                                    }
                                    // Переключить ядро -- три состояния подряд: выпадающий
                                    // список на каждую строку съедал бы всю ширину.
                                    ClickButton {
                                        height: window.s(26)
                                        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 3)
                                        horizontalPadding: window.s(8)
                                        buttonIcon: "󰍜"
                                        iconFontSize: window.s(12)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.subtext1
                                        onClicked: {
                                            const order = ["mihomo", "sing-box", "xray"];
                                            const cur = modelData.core || Mihomo.core;
                                            const next = order[(order.indexOf(cur) + 1) % order.length];
                                            Mihomo.setCore(modelData.name, next);
                                        }
                                    }
                                    ClickButton {
                                        height: window.s(26)
                                        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 3)
                                        horizontalPadding: window.s(8)
                                        buttonIcon: "󰑐"
                                        iconFontSize: window.s(12)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.subtext1
                                        onClicked: Mihomo.refreshSubscription(modelData.name)
                                    }
                                    ClickButton {
                                        height: window.s(26)
                                        cornerRadius: Math.max(0, ThemeBackend.borderRadius - 3)
                                        horizontalPadding: window.s(8)
                                        buttonIcon: "󰅖"
                                        iconFontSize: window.s(12)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.red
                                        onClicked: Mihomo.removeSubscription(modelData.name)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: window.s(110)
                                    cursorShape: Qt.PointingHandCursor
                                    // Запустить подписку -- значит поднять на ней туннель;
                                    // здесь это и означает «переключиться на неё».
                                    onClicked: if (!Mihomo.busy) Mihomo.start(modelData.name)
                                }
                            }
                        }
                    }
                }

                // ── where traffic comes out ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(32)
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.surface0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: window.s(12)
                        anchors.rightMargin: window.s(12)
                        spacing: window.s(8)

                        Text {
                            text: window.footerBad ? "󰀦" : "󰇧"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(12)
                            color: window.footerBad ? ThemeBackend.red : ThemeBackend.subtext0
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: window.footerText
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(11)
                            color: window.footerBad ? ThemeBackend.red : ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }
}
