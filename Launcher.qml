import QtQuick
import Quickshell
import Quickshell.Wayland

// Application launcher.
//
// Replaces fuzzel, which was a separate program with a separate palette, a
// separate font and a separate idea of what a rounded corner is — the one
// surface on this desktop that visibly came from somewhere else.
//
// Ranking is deliberate rather than alphabetical: a prefix match on the name
// beats a match in the middle, which beats a match on the generic name or the
// executable, and everything is broken by how recently it was launched. Fuzzy
// subsequence matching is last, so typing "fox" still finds Firefox without
// letting subsequence noise outrank a real prefix.
Item {
    id: root

    readonly property bool open: Toggles.launcherOpen && root.armed
    property bool armed: false
    Component.onCompleted: armTick.start()
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: root.armed = true
    }

    property string query: ""
    property int selected: 0

    // How often each .desktop id has been launched, and when it last was.
    // Persisted, because a launcher that has to be re-taught your habits every
    // login is just a list.
    readonly property var usage: Prefs.get("launcher.usage", {})

    // ЙЦУКЕН against QWERTY, key for key.
    //
    // Win+D does not switch the layout, so on a machine that types Russian all
    // day the launcher is opened with the wrong one about as often as with the
    // right one, and "аштупщч" found nothing at all. The mapping is by physical
    // key, not by sound: this is a typo to undo, not a transliteration.
    readonly property string _cyrillicKeys: "йцукенгшщзхъфывапролджэячсмитьбю.ё"
    readonly property string _latinKeys: "qwertyuiop[]asdfghjkl;'zxcvbnm,./`"

    function swapLayout(text) {
        let out = "";
        for (const ch of text) {
            const at = root._cyrillicKeys.indexOf(ch);
            out += at >= 0 ? root._latinKeys.charAt(at) : ch;
        }
        return out;
    }

    function score(entry, needle) {
        if (needle === "") return 0;
        const name = (entry.name || "").toLowerCase();
        const generic = (entry.genericName || "").toLowerCase();
        const exec = (entry.execString || "").toLowerCase();

        if (name === needle) return 1000;
        if (name.startsWith(needle)) return 900 - name.length;
        // A word boundary inside the name: "code" should find "Visual Studio
        // Code" well ahead of anything that merely contains the letters.
        if (name.indexOf(" " + needle) >= 0) return 800 - name.length;
        if (name.indexOf(needle) >= 0) return 700 - name.length;
        if (generic.indexOf(needle) >= 0) return 500;
        if (exec.indexOf(needle) >= 0) return 400;

        // Subsequence, last: every letter in order but not adjacent.
        let at = 0;
        for (const ch of needle) {
            at = name.indexOf(ch, at);
            if (at < 0) return -1;
            at += 1;
        }
        return 200 - name.length;
    }

    readonly property var results: {
        const needle = root.query.trim().toLowerCase();
        // Only when the swap changes something, so a Latin query costs nothing
        // and a Russian app name is still matched by what was actually typed.
        const swapped = root.swapLayout(needle);
        const out = [];
        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay) continue;
            const s = swapped === needle
                ? root.score(entry, needle)
                : Math.max(root.score(entry, needle), root.score(entry, swapped));
            if (s < 0) continue;
            const seen = root.usage[entry.id] || 0;
            out.push({ entry: entry, score: s, uses: seen });
        }
        out.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            if (b.uses !== a.uses) return b.uses - a.uses;
            return (a.entry.name || "").localeCompare(b.entry.name || "");
        });
        return out.slice(0, 40);
    }

    function launch(index) {
        const hit = root.results[index];
        if (!hit) return;
        const next = Object.assign({}, root.usage);
        next[hit.entry.id] = (next[hit.entry.id] || 0) + 1;
        Prefs.set("launcher.usage", next);
        hit.entry.execute();
        Toggles.launcherOpen = false;
    }

    function move(delta) {
        if (root.results.length === 0) return;
        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + delta));
        list.positionViewAtIndex(root.selected, ListView.Contain);
    }

    onQueryChanged: {
        root.selected = 0;
        list.positionViewAtBeginning();
    }

    PanelWindow {
        id: win
        // Overlay, not the default Top: niri draws a fullscreen window above
        // the Top layer, so a panel the user just asked for would open behind
        // the video they were watching and read as a dead keystroke.
        WlrLayershell.layer: WlrLayer.Overlay
        property bool mapped: false
        visible: mapped

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: 0
        // Bound to the toggle, not to `open`. `open` waits a frame for `armed`
        // so the entrance has something to animate from -- which meant the
        // surface was mapped asking for no keyboard at all, and the compositor
        // does not come back later to offer it. The launcher opened unfocused:
        // no typing, no arrows, and Escape did nothing either.
        focusable: Toggles.launcherOpen
        WlrLayershell.keyboardFocus: Toggles.launcherOpen
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        Timer {
            id: hideDelay
            interval: Theme.animExit + 40
            onTriggered: win.mapped = false
        }

        function opened() {
            hideDelay.stop();
            win.mapped = true;
            root.query = "";
            root.selected = 0;
            input.text = "";
            input.forceActiveFocus();
            // Again once the surface is actually up. Focus asked for before the
            // compositor has handed the window a keyboard goes nowhere.
            focusRetry.restart();
        }

        Timer {
            id: focusRetry
            interval: 40
            repeat: true
            property int tries: 0
            onTriggered: {
                input.forceActiveFocus();
                focusRetry.tries++;
                if (input.activeFocus || focusRetry.tries > 12) {
                    focusRetry.stop();
                    focusRetry.tries = 0;
                }
            }
        }

        Connections {
            target: Toggles
            function onLauncherOpenChanged() {
                if (Toggles.launcherOpen) win.opened();
                else hideDelay.restart();
            }
        }
        // Loaded lazily *because* the toggle went true, so the signal above has
        // already fired by the time this exists.
        Component.onCompleted: if (Toggles.launcherOpen) win.opened()

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.launcherOpen = false
        }

        Item {
            anchors.fill: parent
            // The field holds the focus, not this. Anything typed has to reach
            // a TextInput to become text, and a wrapper that takes focus for
            // its key handler is a wrapper that swallows the search.
            Keys.forwardTo: [input]

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Toggles.launcherOpen = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.move(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.move(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    root.move(8);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.move(-8);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launch(root.selected);
                    event.accepted = true;
                }
            }

            PanelChrome {
                id: chrome
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(parent.height * 0.16)
                width: 620
                // Snapped to whole rows: a list clipped through the middle of
                // one reads as a rendering fault rather than as a list that
                // continues.
                readonly property int rowHeight: 52
                readonly property int visibleRows: Math.max(1, Math.min(
                    Math.floor(396 / chrome.rowHeight),
                    Math.ceil(list.contentHeight / chrome.rowHeight)))
                // The empty state is a picture, not a row, so it needs a body
                // of its own height -- at one row's worth the cat was clipped
                // through the middle and sat on the search field.
                readonly property int bodyHeight: root.results.length === 0
                    ? 196
                    : chrome.visibleRows * chrome.rowHeight
                height: header.height + chrome.bodyHeight + 20
                screenX: Math.round((Screen.width - 620) / 2)
                screenY: Math.round(Screen.height * 0.16)

                // Short, and decelerating. The card resizes on every keystroke
                // as the result count changes; at 220ms with a spring it was
                // still settling when the next letter arrived, so the whole
                // panel wobbled the entire time you were typing.
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }

                // Rises into place. It used to spring in on scale, which on a
                // 620px card is the whole panel breathing in and out -- fine on
                // a chip in the bar, seasick on something this big. A short
                // lift and a fade is what a search field should do; you are
                // already typing by the time it lands.
                shown: root.open
                origin: Item.Top
                // The one panel that keeps its travel: it is summoned by a key
                // rather than opened from a widget, so it has nowhere to grow
                // out of and the drop is what says where it came from. The 180
                // it used to fade in was a literal the drift check could not
                // see, hiding inside a ternary.
                slideY: Theme.revealSlide
                // Pure drop. Scaling as well would be the two movements rule 1
                // forbids, and the panel is nearly a third of the screen —
                // large things that scale read as zooming, not as arriving.
                fromScale: 1
                onCloseRequested: Toggles.launcherOpen = false

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                // ── Search field ──
                Item {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 62

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: Glyphs.magnify
                        font.family: Theme.fontIconFamily
                        font.pixelSize: Theme.fontIcon
                        color: root.query === "" ? Theme.subtext0 : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    TextInput {
                        id: input
                        anchors.left: searchIcon.right
                        anchors.leftMargin: 14
                        anchors.right: countLabel.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        selectByMouse: true
                        selectionColor: Qt.alpha(Theme.accent, Theme.veilSoft)
                        clip: true
                        focus: true
                        onTextChanged: root.query = text

                        // Navigation lives on the field itself: TextInput
                        // ignores these keys, and putting them anywhere else
                        // means competing for the focus the field needs.
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Toggles.launcherOpen = false;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                root.move(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.move(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.move(8);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp) {
                                root.move(-8);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launch(root.selected);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Tab) {
                                root.move(1);
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Найти приложение"
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            visible: input.text === ""
                        }
                    }

                    Text {
                        id: countLabel
                        anchors.right: parent.right
                        // Clear of the chrome's close button, which sits in the
                        // same corner.
                        anchors.rightMargin: 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.results.length
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.features: ({ "tnum": 1 })
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        height: 1
                        color: Qt.alpha(Theme.text, Theme.fillMuted)
                    }
                }

                // ── Results ──
                ListView {
                    id: list
                    anchors.top: header.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    clip: true
                    model: root.results
                    currentIndex: root.selected
                    // The highlight is drawn per delegate instead: a moving
                    // highlight rectangle lags the selection by its animation
                    // whenever the list scrolls under it.
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: LauncherRow {
                        required property var modelData
                        required property int index

                        width: list.width
                        entry: modelData.entry
                        selected: index === root.selected
                        onActivated: root.launch(index)
                        onHovered: root.selected = index
                    }
                }

                EmptyState {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: "Ничего не найдено"
                }
            }
        }
    }
}
