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

    // What is written on the key, not what X calls it.
    //
    // The volume and brightness column was a list of XF86AudioRaiseVolume and
    // XF86MonBrightnessDown: strings nobody can press, in a sheet whose whole
    // job is to say what to press. The rest of the chips are already Latin
    // (Mod, Shift, Page_Down), so these stay Latin too and match the legend on
    // the keyboard itself.
    readonly property var keyNames: ({
        "XF86AudioRaiseVolume": "Vol +",
        "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic",
        "XF86AudioPlay": "Play",
        "XF86AudioStop": "Stop",
        "XF86AudioPrev": "Prev",
        "XF86AudioNext": "Next",
        "XF86MonBrightnessUp": "Bright +",
        "XF86MonBrightnessDown": "Bright −"
    })

    function prettyKey(key) {
        return key.split("+").map(part => {
            const named = root.keyNames[part];
            if (named) return named;
            // Page_Down and WheelScrollUp are the config's spelling, not the
            // keyboard's.
            return part.replace(/_/g, " ").replace(/([a-z])([A-Z])/g, "$1 $2");
        }).join(" + ");
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
            let label = titleMatch ? titleMatch[1] : "";
            if (!titleMatch) {
                const verb = action.split(" ")[0];
                // The argument matters for the ones that take one: nine binds
                // are all "focus-workspace" and would otherwise be nine
                // identical lines.
                let arg = action.split(" ").slice(1).join(" ").trim();
                const named = root.actionNames[verb];
                label = named ? named : verb.replace(/-/g, " ");
                // niri quotes every word of a spawn, so an untitled bind read
                // `spawn "qs" "ipc" "call" "toggles" "wallpaper"` and took three
                // lines to say less than its own title would have.
                if (verb === "spawn") arg = arg.replace(/"/g, "");
                if (arg !== "") label += " " + arg;
            }
            if (!label) continue;

            current.binds.push({ key: root.prettyKey(key), label });
        }
        if (current.binds.length > 0) result.push(current);
        for (const category of result) category.binds = root.collapseRuns(category.binds);
        return [...result, ...root.mouseCategories];
    }

    // Categories dealt into columns, shortest column first.
    //
    // A Flow lays them out in rows, and a row is as tall as its tallest member:
    // with one long section and four short ones that leaves half a screen of
    // nothing under the short ones, and pushes the mouse sections off the
    // bottom entirely. Dealing into columns instead spends that space on the
    // content that was hidden.
    //
    // The heights are estimated rather than measured -- a binding on the real
    // heights would have to lay out to decide the layout. Being a row or two
    // out only makes the columns slightly uneven, which is invisible; waiting
    // for a measurement would not be.
    function balanced(count) {
        const columns = [];
        const heights = [];
        for (let i = 0; i < count; i++) {
            columns.push([]);
            heights.push(0);
        }
        for (const category of root.categories) {
            let cost = 26;
            for (const bind of category.binds) {
                // Roughly where a 320px column wraps a 12px label, counted per
                // line rather than as wrapped-or-not: the raw fallback labels
                // run to three.
                cost += Math.max(1, Math.ceil(bind.label.length / 26)) * 16 + 6;
            }
            let target = 0;
            for (let i = 1; i < count; i++) {
                if (heights[i] < heights[target]) target = i;
            }
            columns[target].push(category);
            heights[target] += cost + 20;
        }
        return columns;
    }

    // Nine binds that differ by one digit are one bind with a range in it.
    //
    // "Mod + 1 На рабочий стол 1" through "Mod + 9" filled a third of the sheet
    // with a pattern the reader works out from the first two lines, and pushed
    // the sections that actually need reading off the bottom of the screen.
    function collapseRuns(binds) {
        const out = [];
        let i = 0;
        while (i < binds.length) {
            const m = binds[i].key.match(/^(.*\+ )(\d)$/);
            if (!m) {
                out.push(binds[i]);
                i += 1;
                continue;
            }
            let j = i;
            while (j + 1 < binds.length) {
                const next = binds[j + 1].key.match(/^(.*\+ )(\d)$/);
                if (!next || next[1] !== m[1]) break;
                if (parseInt(next[2]) !== parseInt(binds[j].key.slice(-1)) + 1) break;
                j += 1;
            }
            // Two of them are shorter written out than explained as a range.
            if (j - i < 2) {
                out.push(binds[i]);
                i += 1;
                continue;
            }
            const last = binds[j].key.slice(-1);
            out.push({
                key: m[1] + m[2] + "…" + last,
                label: binds[i].label.replace(/\d+\s*$/, m[2] + "–" + last)
            });
            i = j + 1;
        }
        return out;
    }

    // niri's own action names, in Russian.
    //
    // A bind without a hotkey-overlay-title falls back to the action, and niri
    // names actions in English -- so half the sheet read "focus column left"
    // under a heading that said "Фокус между окнами". Translating here rather
    // than titling every bind in the config keeps one list instead of eighty,
    // and covers binds added later without touching this file again.
    readonly property var actionNames: ({
        "focus-column-left": "Колонка левее",
        "focus-column-right": "Колонка правее",
        "focus-column-first": "Первая колонка",
        "focus-column-last": "Последняя колонка",
        "focus-window-up": "Окно выше",
        "focus-window-down": "Окно ниже",
        "move-column-left": "Двинуть колонку влево",
        "move-column-right": "Двинуть колонку вправо",
        "move-column-to-first": "Колонку в начало",
        "move-column-to-last": "Колонку в конец",
        "move-window-up": "Двинуть окно вверх",
        "move-window-down": "Двинуть окно вниз",
        "focus-workspace": "На рабочий стол",
        "focus-workspace-up": "Рабочий стол выше",
        "focus-workspace-down": "Рабочий стол ниже",
        "move-workspace-up": "Стол выше",
        "move-workspace-down": "Стол ниже",
        "move-column-to-workspace": "Колонку на стол",
        "move-column-to-workspace-up": "Колонку на стол выше",
        "move-column-to-workspace-down": "Колонку на стол ниже",
        "focus-monitor-left": "Монитор слева",
        "focus-monitor-right": "Монитор справа",
        "focus-monitor-up": "Монитор выше",
        "focus-monitor-down": "Монитор ниже",
        "move-column-to-monitor-left": "Колонку на монитор слева",
        "move-column-to-monitor-right": "Колонку на монитор справа",
        "move-column-to-monitor-up": "Колонку на монитор выше",
        "move-column-to-monitor-down": "Колонку на монитор ниже",
        "close-window": "Закрыть окно",
        "fullscreen-window": "Во весь экран",
        "maximize-column": "Развернуть колонку",
        "maximize-window-to-edges": "Развернуть до краёв",
        "center-column": "Колонку по центру",
        "center-visible-columns": "Видимые по центру",
        "expand-column-to-available-width": "Растянуть колонку",
        "consume-window-into-column": "Втянуть окно в колонку",
        "expel-window-from-column": "Вытолкнуть окно из колонки",
        "consume-or-expel-window-left": "Втянуть или вытолкнуть влево",
        "consume-or-expel-window-right": "Втянуть или вытолкнуть вправо",
        "switch-preset-column-width": "Ширина колонки далее",
        "switch-preset-column-width-back": "Ширина колонки назад",
        "switch-preset-window-height": "Высота окна далее",
        "set-column-width": "Ширина колонки",
        "set-window-height": "Высота окна",
        "reset-window-height": "Сбросить высоту",
        "toggle-window-floating": "Плавающее окно",
        "switch-focus-between-floating-and-tiling": "Плавающие или плитка",
        "toggle-column-tabbed-display": "Колонка вкладками",
        "toggle-overview": "Обзор столов",
        "toggle-keyboard-shortcuts-inhibit": "Отдать горячие клавиши окну",
        "power-off-monitors": "Погасить экраны",
        "screenshot": "Снимок области",
        "screenshot-screen": "Снимок экрана",
        "screenshot-window": "Снимок окна",
        "quit": "Выйти из сессии"
    })

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
                { key: "ПКМ", label: "Батарея — профиль питания, сон, выключение" },
                { key: "ПКМ", label: "VPN — узлы по задержке, отключить, проверить" }
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
                // The columns are a fixed 320, so the width decides how many of
                // them the Flow gets: 1100 gave three and 1500 gives four, and
                // at four the workspace binds still ran past the bottom of the
                // screen once labels wrapped. Five fits the whole sheet, which
                // is the entire point of a sheet.
                width: Math.min(parent.width - 80, 1800)
                // As tall as the bindings need, capped by the screen. A fixed
                // 700 was right until the labels started wrapping, and then the
                // last workspace binds sat below the fold in a sheet whose
                // point is that everything is visible at once.
                height: Math.min(parent.height - 80, grid.height + 48)
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

                    Row {
                        id: grid
                        width: parent.width
                        spacing: Theme.gapSection

                        Repeater {
                        model: root.balanced(Math.max(1, Math.floor((parent.width + 20) / 340)))
                        delegate: Column {
                        required property var modelData
                        width: 320
                        spacing: Theme.gapSection

                        Repeater {
                            model: modelData
                            delegate: Column {
                                id: categoryDelegate
                                required property var modelData
                                required property int index
                                width: 320
                                spacing: Theme.spacing

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
                                        spacing: Theme.gapWide
                                        Rectangle {
                                            id: keyChip
                                            width: keyText.width + 12
                                            height: 20
                                            radius: Theme.radiusChip
                                            color: Theme.surface0
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: bindRow.modelData.key
                                                color: Theme.subtext1
                                                font.pixelSize: Theme.fontSmall
                                                font.family: "monospace"
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            // Bound and wrapped: the long labels
                                            // ran straight over the next column,
                                            // and eliding them turned the one
                                            // place where the full wording
                                            // matters into "Колонку на монито…".
                                            width: bindRow.width - keyChip.width - bindRow.spacing
                                            wrapMode: Text.Wrap
                                            text: bindRow.modelData.label
                                            color: Theme.text
                                            font.pixelSize: Theme.fontBody
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
    }
}
