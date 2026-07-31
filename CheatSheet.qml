import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Parses 50-binds.kdl directly so this overlay can never drift out of sync
// with the real keybinds — no separate list to maintain by hand.
Item {
    id: root

    // Animations bind to this, not to the toggle. The panel is created lazily,
    // which means it is born with the toggle already true — an entry animation
    // bound straight to the toggle has nothing to animate from and the panel
    // simply appears at its final size. `armed` turns on a frame later, so the
    // open state is always a transition.
    readonly property bool open: Toggles.cheatSheetOpen && root.armed
    property bool armed: false
    Component.onCompleted: {
        armTick.start();
        reader.running = true;
    }
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: root.armed = true
    }

    property var categories: []

    Process {
        id: reader
        command: ["cat", Quickshell.env("HOME") + "/.config/niri/config.d/50-binds.kdl"]
        stdout: StdioCollector {
            onStreamFinished: root.categories = root.parse(text)
        }
    }

    function parse(text) {
        const lines = text.split("\n");
        const result = [];
        let current = { name: "Прочее", binds: [] };

        const headerRe = /^\s*\/\/\s*---+\s*(.+?)\s*---+\s*$/;
        const bindRe = /^\s*([A-Za-z0-9_+]+)\s+(?:[^\{]*?)?\{\s*(.+?)\s*;?\s*\}\s*$/;
        const titleRe = /hotkey-overlay-title="([^"]*)"/;
        const titleNullRe = /hotkey-overlay-title=null/;

        for (const raw of lines) {
            const headerMatch = raw.match(headerRe);
            if (headerMatch) {
                if (current.binds.length > 0) result.push(current);
                current = { name: headerMatch[1], binds: [] };
                continue;
            }

            const line = raw.trim();
            if (!line || line.startsWith("//")) continue;

            const m = line.match(bindRe);
            if (!m) continue;
            const key = m[1];
            const action = m[2];

            if (titleNullRe.test(line)) continue;
            const titleMatch = line.match(titleRe);
            let label = titleMatch ? titleMatch[1] : action;
            if (!titleMatch) {
                label = action.split(" ")[0].replace(/-/g, " ");
            }
            if (!label) continue;

            current.binds.push({ key: key.replace(/\+/g, " + "), label });
        }
        if (current.binds.length > 0) result.push(current);
        return [...result, ...root.mouseCategories];
    }

    // Mouse actions can't be parsed out of the niri config — they live in the
    // bar's own widgets — so they're listed here by hand and merged with the
    // parsed keybinds. Without this the shell's entire right-click layer was
    // undiscoverable.
    readonly property var mouseCategories: [
        {
            name: "Мышь: бар",
            binds: [
                { key: "ЛКМ", label: "Часы — панель управления; дата — календарь" },
                { key: "ПКМ", label: "Меню на любом виджете и на пустом месте бара" },
                { key: "Колесо", label: "Над воркспейсами — переключение столов" }
            ]
        },
        {
            name: "Мышь: звук и сеть",
            binds: [
                { key: "ЛКМ", label: "Громкость — заглушить" },
                { key: "Колесо", label: "Громкость ±5%" },
                { key: "ПКМ", label: "Звук — выбор устройства вывода, микрофон" },
                { key: "ПКМ", label: "Сеть — список Wi-Fi (скан только здесь)" },
                { key: "ПКМ", label: "Батарея — профиль питания, сон, выключение" }
            ]
        },
        {
            name: "Мышь: трей",
            binds: [
                { key: "ЛКМ", label: "Активировать приложение" },
                { key: "ПКМ", label: "Меню приложения" },
                { key: "СКМ", label: "Вторичное действие" },
                { key: "Колесо", label: "Прокрутка (громкость и т.п.)" }
            ]
        },
        {
            name: "Мышь: плеер и уведомления",
            binds: [
                { key: "ЛКМ", label: "Плеер — пауза; уведомление — закрыть" },
                { key: "СКМ", label: "Плеер — следующий трек" },
                { key: "Колесо", label: "Плеер — переключение треков" },
                { key: "ПКМ", label: "Плеер — выбор плеера, повтор, перемешивание" },
                { key: "СКМ", label: "Колокольчик — «не беспокоить»" },
                { key: "ПКМ", label: "Уведомление в истории — убрать" }
            ]
        }
    ]

    Connections {
        target: Toggles
        function onCheatSheetOpenChanged() {
            if (Toggles.cheatSheetOpen) reader.running = true;
        }
    }

    PanelWindow {
        id: win
        // Overlay, not the default Top: niri draws a fullscreen window above
        // the Top layer, so a panel the user just asked for would open behind
        // the video they were watching and read as a dead keystroke.
        WlrLayershell.layer: WlrLayer.Overlay
        // Explicit mapping bool — see ControlCenter.qml. Stays mapped through
        // the whole close so the card fade and screen-dim fade can play;
        // binding visible to the toggle raced the unmap ahead of the fade.
        property bool mapped: false
        visible: mapped
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusiveZone: 0
        aboveWindows: true
        // Bound to the toggle, not to `open`. `open` waits a frame for `armed`
        // so the entrance has something to animate from, and a surface mapped
        // asking for no keyboard never gets offered one afterwards -- which is
        // a panel that ignores Escape and every key in it.
        focusable: Toggles.cheatSheetOpen
        // Exclusive, not merely focusable. `focusable` alone asks for
        // on-demand interactivity, which means the compositor hands over the
        // keyboard when the surface is clicked -- so a panel opened from a
        // keybind ignored Escape until you had clicked it first.
        WlrLayershell.keyboardFocus: Toggles.cheatSheetOpen
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // Escape closes it, from anywhere inside.
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Toggles.cheatSheetOpen = false;
                    event.accepted = true;
                }
            }
        }

        Timer {
            id: hideDelay
            // Held to the slower dim fade, not animExit: the card leaves fast
            // but the screen dim needs the full fade or the backdrop pops off
            // a frame before the card is gone.
            interval: Theme.animNormal + 40
            onTriggered: win.mapped = false
        }
        Connections {
            target: Toggles
            function onCheatSheetOpenChanged() {
                if (Toggles.cheatSheetOpen) {
                    hideDelay.stop();
                    win.mapped = true;
                } else {
                    hideDelay.restart();
                }
            }
        }
        Component.onCompleted: win.mapped = Toggles.cheatSheetOpen

        // Dims the rest of the screen while open — also doubles as the
        // click-outside-to-close target.
        Rectangle {
            anchors.fill: parent
            color: "#00000000"
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.open ? 0.35 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.open ? Theme.animNormal : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.open ? Theme.easeEmphasized : Theme.easeExit
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: Toggles.cheatSheetOpen = false
            }
        }

        Item {
            id: focusScope
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: Toggles.cheatSheetOpen = false

            PanelChrome {
                id: chrome
                anchors.centerIn: parent
                // 1100 fits only three 320px columns, which pushed the last
                // third of the sheet — including the mouse sections — below the
                // fold on a 1920 screen.
                width: Math.min(parent.width - 80, 1500)
                height: Math.min(parent.height - 80, 700)
                screenX: (Screen.width - width) / 2
                screenY: (Screen.height - height) / 2
                opacity: root.open ? 1 : 0
                scale: root.open ? 1 : 0.9
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
                onCloseRequested: Toggles.cheatSheetOpen = false

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // swallow so the outer overlay doesn't treat this as "outside"
                }

                // Sharp art panel on the right edge, over the frosted backing:
                // the glass alone is too diffuse to carry the character, so a
                // crisp crop of the wallpaper anchors the sheet visually.
                Image {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: parent.width * 0.42
                    height: parent.height
                    // Still frame for video wallpapers — a sharp crop is the
                    // point here, and a second decoding video would buy nothing.
                    source: Wallpaper.blurSource
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.38
                }
                // Fades that crop back into the glass so it reads as one
                // surface. The right end keeps a scrim rather than going fully
                // transparent — a keybind column sits over the art there, and
                // the raw image destroys its contrast.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.alpha(Theme.mantle, 0.60) }
                        GradientStop { position: 0.5; color: Qt.alpha(Theme.mantle, 0.42) }
                        GradientStop { position: 1.0; color: Qt.alpha(Theme.mantle, 0.30) }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 24
                    contentHeight: grid.height
                    clip: true

                    Flow {
                        id: grid
                        width: parent.width
                        spacing: 20

                        Repeater {
                            model: root.categories
                            delegate: Column {
                                id: categoryDelegate
                                required property var modelData
                                required property int index
                                width: 320
                                spacing: 6

                                opacity: 0
                                scale: 0.94
                                transformOrigin: Item.Top
                                Component.onCompleted: categoryEntryAnim.start()
                                ParallelAnimation {
                                    id: categoryEntryAnim
                                    SequentialAnimation {
                                        PauseAnimation { duration: Math.min(categoryDelegate.index, 8) * 30 }
                                        NumberAnimation {
                                            target: categoryDelegate; property: "opacity"; to: 1
                                            duration: Theme.animNormal
                                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeEmphasized
                                        }
                                    }
                                    SequentialAnimation {
                                        PauseAnimation { duration: Math.min(categoryDelegate.index, 8) * 30 }
                                        NumberAnimation {
                                            target: categoryDelegate; property: "scale"; to: 1
                                            duration: Theme.animNormal
                                            easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.name
                                    color: Theme.accent
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Repeater {
                                    model: modelData.binds
                                    delegate: Row {
                                        id: bindRow
                                        required property var modelData
                                        width: categoryDelegate.width
                                        spacing: 10
                                        Rectangle {
                                            id: keyChip
                                            width: keyText.width + 12
                                            height: 20
                                            radius: 10
                                            color: Theme.surface0
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: bindRow.modelData.key
                                                color: Theme.subtext1
                                                font.pixelSize: 11
                                                font.family: "monospace"
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            // Bound and elided: labels that fall
                                            // back to the raw niri action name
                                            // ("move column to monitor left") ran
                                            // straight over the next column.
                                            width: bindRow.width - keyChip.width - bindRow.spacing
                                            elide: Text.ElideRight
                                            text: bindRow.modelData.label
                                            color: Theme.text
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
