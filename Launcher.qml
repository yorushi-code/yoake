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

    readonly property bool open: arm.open
    property PanelArm _arm: PanelArm { id: arm; requested: Toggles.launcherOpen }

    property string query: ""
    property int selected: 0

    // Whether the pointer owns the selection.
    //
    // It did, unconditionally, and that is most of what "Win+D is buggy" meant.
    // A row claimed the selection on `entered`, and `entered` fires whenever the
    // row arrives under the pointer — which is not the same event as the pointer
    // arriving on the row. Opening the launcher maps a list under a mouse that
    // has been sitting still since whenever it was last used, so the launcher
    // opened with the seventh row selected, and Enter launched it. Typing was
    // worse: every keystroke restages the list, so whatever ranked into the slot
    // under the stationary pointer took the selection away from the top match on
    // every letter.
    //
    // So the pointer earns the selection by moving, and gives it back to the
    // keyboard on any key that moves it. This is what a launcher, a menu and a
    // command palette all do, and none of them say so out loud, which is
    // probably why it was written the other way.
    property bool pointerLive: false

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

    // The substring ladder, shared by every kind so that an application, an open
    // window and a shell action can be ranked against each other on one scale.
    //
    // Subsequence matching is deliberately not in here. It earns its place
    // against a short application name -- "fox" finding Firefox -- and it ruins
    // a window title, where sixty characters of prose contain the letters of
    // almost any query in order and every window would match everything.
    function _textScore(text, needle) {
        if (needle === "") return 0;
        if (text === needle) return 1000;
        if (text.startsWith(needle)) return 900 - text.length;
        // A word boundary inside the name: "code" should find "Visual Studio
        // Code" well ahead of anything that merely contains the letters.
        if (text.indexOf(" " + needle) >= 0) return 800 - text.length;
        if (text.indexOf(needle) >= 0) return 700 - text.length;
        return -1;
    }

    function score(entry, needle) {
        if (needle === "") return 0;
        const name = (entry.name || "").toLowerCase();
        const direct = root._textScore(name, needle);
        if (direct >= 0) return direct;

        const generic = (entry.genericName || "").toLowerCase();
        const exec = (entry.execString || "").toLowerCase();
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

    // ── Modes ──
    //
    // The launcher found applications and nothing else, so everything adjacent
    // to "start a thing" -- switch to a window that is already open, run a
    // shell action, work out a number -- was somewhere else or nowhere. A
    // prefix is the cheapest possible mode switch: it needs no chrome, it is
    // one keystroke, and the query itself says which list you are looking at.
    //
    // A prefix *narrows*; typing without one asks the whole question. So the
    // default is not "applications" but "everything that matches", and the
    // prefixes are there for the times you already know which list you want.
    // Searching for firefox when firefox is open should not hide the window.
    readonly property var modes: [
        { key: "app", prefix: "", label: "Приложения", glyph: Glyphs.apps },
        { key: "window", prefix: "/", label: "Окна", glyph: Glyphs.monitor },
        { key: "action", prefix: ">", label: "Действия", glyph: Glyphs.tune },
        { key: "calc", prefix: "=", label: "Счёт", glyph: Glyphs.plus }
    ]

    readonly property string mode: {
        const q = root.query;
        if (q.startsWith("/")) return "window";
        if (q.startsWith(">")) return "action";
        if (q.startsWith("=")) return "calc";
        return "app";
    }

    readonly property string needle: root.mode === "app"
        ? root.query.trim() : root.query.substring(1).trim()

    function setMode(key) {
        for (const m of root.modes) {
            if (m.key === key) {
                input.text = m.prefix;
                input.forceActiveFocus();
                return;
            }
        }
    }

    // Arithmetic, with the character set as the whole of the safety argument.
    //
    // Anything that reaches a JS evaluator from a text field is a hole; a
    // whitelist of digits and operators is not a parser but it is a proof that
    // nothing else can be in the string by the time it is evaluated.
    function calculate(expression) {
        const text = expression.replace(/\^/g, "**").replace(/,/g, ".");
        if (text === "" || !/^[0-9+\-*/(). %]*$/.test(text.replace(/\*\*/g, ""))) return null;
        try {
            const value = Function("\"use strict\"; return (" + text + ")")();
            if (typeof value !== "number" || !isFinite(value)) return null;
            return Math.round(value * 1e6) / 1e6;
        } catch (e) {
            return null;
        }
    }

    readonly property var results: {
        if (root.mode === "calc") return root._calcResults();
        if (root.mode === "window") return root._windowResults();
        if (root.mode === "action") return root._actionResults();
        return root._combinedResults();
    }

    // The kind is worth printing exactly when it tells the rows apart.
    //
    // It used to be printed always, and the row type was written for a list of
    // four kinds -- but a prefix selects exactly one generator, so every list
    // this launcher could produce was homogeneous and the badge said the same
    // four letters forty times down the right edge. That is not a label, it is
    // a texture. Now that a plain query really can return an application, a
    // window and an action together, the badge has its job back, and it appears
    // only in the lists that have that job to do.
    readonly property bool mixed: {
        const rows = root.results;
        for (let i = 1; i < rows.length; i++) {
            if (rows[i].kind !== rows[0].kind) return true;
        }
        return false;
    }

    // Ties go to the kind you more often meant. Two things matching a query
    // equally well is common -- an application and its own open window match
    // their shared name identically -- and "launch it" is the more frequent
    // intent, so it leads and the window sits directly under it.
    readonly property var _kindRank: ({ "app": 0, "window": 1, "action": 2, "calc": 3 })

    function _combinedResults() {
        const apps = root._appResults();
        // An empty query is "what can I run", not "everything this session
        // contains". With nothing typed there is no ranking to speak of, a list
        // of every open window is noise, and `/` asks that question directly.
        const out = root.needle === ""
            ? apps
            : apps.concat(root._windowResults(), root._actionResults());

        out.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            const ka = root._kindRank[a.kind], kb = root._kindRank[b.kind];
            if (ka !== kb) return ka - kb;
            if ((b.uses || 0) !== (a.uses || 0)) return (b.uses || 0) - (a.uses || 0);
            return (a.name || "").localeCompare(b.name || "");
        });
        return out.slice(0, 40);
    }

    // Unsorted: the caller merges these with the other kinds and ranks the lot
    // in one pass, because sorting a slice of a list twice ranks it by the
    // wrong thing the first time.
    function _appResults() {
        const needle = root.needle.toLowerCase();
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
            out.push({
                kind: "app", label: "прил.", entry: entry,
                name: entry.name || "", subtitle: entry.genericName || entry.comment || "",
                iconName: entry.icon || "", glyph: Glyphs.apps,
                score: s, uses: seen
            });
        }
        return out;
    }

    function _windowResults() {
        const needle = root.needle.toLowerCase();
        const swapped = root.swapLayout(needle);
        const out = [];
        for (const w of Niri.windows) {
            const title = (w.title || "").toLowerCase();
            const app = (w.app_id || "").toLowerCase();
            // Against the application id as well as the title, and the better of
            // the two wins: a window is findable by what program it is and by
            // what is currently in it, which are rarely the same word.
            let s = Math.max(root._textScore(app, needle), root._textScore(title, needle));
            if (swapped !== needle) {
                s = Math.max(s, root._textScore(app, swapped), root._textScore(title, swapped));
            }
            if (s < 0) continue;
            out.push({
                kind: "window", label: "окно", windowId: w.id,
                name: w.title || w.app_id || "Окно",
                subtitle: w.app_id || "",
                iconName: w.app_id || "", glyph: Glyphs.monitor,
                // The one you are on is the least useful thing to switch to.
                // Below every other match rather than merely last among windows,
                // now that windows share a scale with everything else.
                score: w.is_focused ? s - 2000 : s
            });
        }
        out.sort((a, b) => b.score - a.score);
        return out;
    }

    function _actionResults() {
        const needle = root.needle.toLowerCase();
        const out = [];
        for (const item of ShellActions.shellMenu) {
            if (item.separator) continue;
            const text = (item.text || "").toLowerCase();
            const s = root._textScore(text, needle);
            if (s < 0) continue;
            out.push({
                kind: "action", label: "действие", act: item.action,
                name: item.text || "", subtitle: "",
                iconName: "", glyph: item.glyph || Glyphs.tune,
                score: s
            });
        }
        return out;
    }

    function _calcResults() {
        const value = root.calculate(root.needle);
        if (value === null) return [];
        return [{
            kind: "calc", label: "=", value: value,
            name: String(value), subtitle: root.needle,
            iconName: "", glyph: Glyphs.plus
        }];
    }

    // Whether a row appearing right now is part of an arrival or is simply
    // scrolling into view.
    //
    // A delegate cannot tell the difference by itself, which is why every list
    // that animates on `Component.onCompleted` replays its entrance forever as
    // you scroll. The window is opened deliberately -- on the open and on a new
    // query, the only two moments when the whole list really is new -- and shut
    // by the time anything could have been scrolled to.
    property bool cascading: false
    property Timer _cascadeWindow: Timer {
        id: cascadeWindow
        interval: Direction.rest
        onTriggered: root.cascading = false
    }

    function restage() {
        root.cascading = true;
        cascadeWindow.restart();
    }

    // Set for as long as it takes the panel to leave. The row you chose gets to
    // acknowledge the choice: without it the window simply stops existing, and
    // a launcher that vanishes has not told you it did anything.
    property bool committing: false

    function launch(index) {
        const hit = root.results[index];
        if (!hit) return;
        // Before the close, not after: the slow part of this function is
        // whatever it starts, and holding the flash behind that would put the
        // acknowledgement after the thing it acknowledges.
        root.committing = true;

        if (hit.kind === "app") {
            const next = Object.assign({}, root.usage);
            next[hit.entry.id] = (next[hit.entry.id] || 0) + 1;
            Prefs.set("launcher.usage", next);
            hit.entry.execute();
        } else if (hit.kind === "window") {
            Niri.focusWindow(hit.windowId);
        } else if (hit.kind === "action") {
            if (hit.act) hit.act();
        } else if (hit.kind === "calc") {
            // The answer is the point, and an answer you cannot take with you
            // is a calculator that only talks to itself.
            Quickshell.clipboardText = String(hit.value);
        }

        Toggles.launcherOpen = false;
    }

    function move(delta) {
        if (root.results.length === 0) return;
        // An arrow key takes the selection back. Without this the list scrolls
        // under a stationary pointer, the row that lands beneath it reports a
        // hover, and the selection snaps back to the mouse on the next keypress.
        root.pointerLive = false;
        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + delta));
        root.reveal(root.selected);
    }

    // Scrolls the selection into view, as a movement rather than a jump.
    //
    // This was `positionViewAtIndex`, which is instant, and that is the whole
    // reason the selection could not be drawn once and moved: the marker would
    // glide a row down in content coordinates while the content itself
    // teleported a row up, and the two together read as the highlight lagging.
    // They are one movement and have to travel at one speed.
    function reveal(index) {
        const top = index * chrome.rowHeight;
        const bottom = top + chrome.rowHeight;
        let want = list.contentY;
        if (top < want) want = top;
        else if (bottom > want + list.height) want = bottom - list.height;
        want = Math.max(0, Math.min(want, Math.max(0, list.contentHeight - list.height)));
        if (Math.abs(want - list.contentY) < 1) return;
        scroll.to = want;
        scroll.restart();
    }

    onQueryChanged: {
        // The list is about to be rebuilt under whatever the pointer is resting
        // on, and the top match is the answer to what was just typed.
        root.pointerLive = false;
        root.selected = 0;
        list.positionViewAtBeginning();
        root.restage();
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
            // The pointer has not moved since the launcher was last used, and
            // wherever it is resting is not a choice anybody just made.
            root.pointerLive = false;
            pointer.lastX = -1;
            pointer.lastY = -1;
            root.committing = false;
            root.restage();
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

            // What counts as the pointer moving, measured once for the whole
            // launcher rather than per row.
            //
            // It has to be measured here because a row cannot tell the two cases
            // apart: scrolling the list under a still mouse changes the pointer's
            // position *inside* the delegate exactly as much as moving the mouse
            // does, and Qt re-delivers a hover move for both. This handler's
            // coordinates are the window's, and the window does not move when the
            // list scrolls — so a position that changed here is a hand that moved.
            //
            // Passive on purpose: a HoverHandler observes without taking the
            // events, so the rows keep their own hover and their own cursor.
            HoverHandler {
                id: pointer
                property real lastX: -1
                property real lastY: -1
                onPointChanged: {
                    const p = pointer.point.position;
                    if (pointer.lastX >= 0
                            && (Math.abs(p.x - pointer.lastX) > 0.5
                                || Math.abs(p.y - pointer.lastY) > 0.5))
                        root.pointerLive = true;
                    pointer.lastX = p.x;
                    pointer.lastY = p.y;
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

                    MaterialSymbol {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Glyphs.magnify
                        size: Theme.fontIcon
                        // Fills as soon as there is a query, which is the axis
                        // doing what it is for: the same glyph, in a different
                        // state, rather than a second picture.
                        fill: root.query === "" ? 0 : 1
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
                            // The prefixes are the whole discoverability of
                            // the modes: nothing else on screen says they
                            // exist, and a mode nobody knows about is a mode
                            // nobody has.
                            text: "Приложение · / окно · > действие · = счёт"
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
                    boundsBehavior: Flickable.StopAtBounds

                    // The one thing that is scrolled rather than jumped. See
                    // root.reveal(): a marker that travels and a viewport that
                    // teleports are the two halves of the bug that made a
                    // moving highlight unusable here in the first place.
                    NumberAnimation {
                        id: scroll
                        target: list
                        property: "contentY"
                        duration: Theme.animNormal
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasized
                    }

                    // Declared inside the view on purpose: a Flickable puts its
                    // visual children in the content item, so this shares the
                    // delegates' coordinate space and scrolls with them for
                    // free. Behind them, so the marker is a surface the row
                    // sits on rather than a pane over it.
                    Traveller {
                        id: marker
                        z: -1
                        active: root.results.length > 0
                        // Exactly the window in which this list is being
                        // rebuilt -- an open, or a new query. Outside it the
                        // marker travels, because then the selection really did
                        // move within a list that stayed put.
                        snapping: root.cascading
                        slotX: 0
                        slotY: root.selected * chrome.rowHeight
                        slotWidth: list.width
                        slotHeight: chrome.rowHeight
                        // A page of arrow keys is the longest journey worth
                        // deforming for; beyond that it is a jump, and a jump
                        // that stretches reads as elastic rather than as mass.
                        span: chrome.rowHeight * 4

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusChip
                            color: Qt.alpha(Theme.accent, Theme.tintSubtle)
                            // The commit. Brief and bright, and it plays while
                            // the panel is already on its way out, so the two
                            // are one event rather than a flash followed by a
                            // close.
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Theme.accent
                                opacity: root.committing ? Theme.tintActive : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.animFlick } }
                            }
                        }

                        // Travels with the fill rather than being drawn by the
                        // selected row, so the rail is the same object all the
                        // way down the list.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 24
                            radius: width / 2
                            color: Theme.accent
                        }
                    }

                    delegate: LauncherRow {
                        id: row
                        required property var modelData
                        required property int index

                        width: list.width
                        name: modelData.name
                        subtitle: modelData.subtitle
                        iconName: modelData.iconName
                        glyph: modelData.glyph
                        kind: root.mixed ? modelData.label : ""
                        selected: index === root.selected
                        onActivated: root.launch(index)
                        onHovered: if (root.pointerLive) root.selected = index

                        // Rows arrive one after another, from the left, but
                        // only when the list itself is new -- see
                        // root.cascading. A delegate built because you scrolled
                        // is not an arrival and must not be staged as one.
                        opacity: 0
                        Component.onCompleted: {
                            if (root.cascading) intro.restart();
                            else row.opacity = 1;
                        }

                        SequentialAnimation {
                            id: intro
                            PauseAnimation { duration: Direction.stagger(row.index) }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: row; property: "opacity"; to: 1
                                    duration: Theme.animNormal
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasized
                                }
                                NumberAnimation {
                                    target: row; property: "x"; from: -22; to: 0
                                    duration: Theme.animSlow
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeSpringBig
                                }
                            }
                        }
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
