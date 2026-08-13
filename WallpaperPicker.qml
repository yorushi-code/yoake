import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

// Wallpaper chooser, in the shell rather than in a separate application.
//
// It replaces a GTK4 window wrapping a WebKit view — two toolkits and a browser
// engine, spawned per use, themed separately from everything around it.
//
// The card grid it first replaced that with was the wrong shape for the job: a
// wallpaper is judged full-screen, and a 250px card tells you almost nothing
// about one. So the wallpaper under attention is drawn full-screen behind a
// scrim, the library is a filmstrip along the bottom, and the right-hand column
// answers the question the old picker could not: what the accent will become.
// That preview is the point — the palette is derived from the image (see
// wallpaper-palette.py), and seeing it before committing is what makes the
// connection between wallpaper and shell colour legible.
PanelWindow {
    id: win
    // Overlay, not the default Top: niri draws a fullscreen window above
    // the Top layer, so a panel the user just asked for would open behind
    // the video they were watching and read as a dead keystroke.
    WlrLayershell.layer: WlrLayer.Overlay

    // See ControlCenter: mapping is an explicit bool so the exit animation is
    // not cut off by a visible-binding race.
    property bool mapped: false
    visible: mapped

    // Animations bind to this, not the toggle: created lazily, the picker is
    // born with the toggle already true and an entry animation would have
    // nothing to animate from.
    readonly property bool open: arm.open
    property PanelArm _arm: PanelArm { id: arm; requested: Toggles.wallpaperPickerOpen }
    Component.onCompleted: {
        win.mapped = Toggles.wallpaperPickerOpen;
        win.syncToApplied();
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    focusable: Toggles.wallpaperPickerOpen
    // Exclusive, not merely focusable. `focusable` alone asks for
    // on-demand interactivity, which means the compositor hands over the
    // keyboard when the surface is clicked -- so a panel opened from a
    // keybind ignored Escape until you had clicked it first.
    WlrLayershell.keyboardFocus: Toggles.wallpaperPickerOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // Escape closes it, from anywhere inside.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Toggles.wallpaperPickerOpen = false;
                event.accepted = true;
            }
        }
    }

    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: win.mapped = false
    }
    Connections {
        target: Toggles
        function onWallpaperPickerOpenChanged() {
            if (Toggles.wallpaperPickerOpen) {
                hideDelay.stop();
                win.mapped = true;
                Wallpapers.search = "";
                win.searching = false;
                win.syncToApplied();
                settle.triggered();
            } else {
                hideDelay.restart();
                // Releases the preview decoder rather than leaving a video
                // playing behind an unmapped window.
                win.previewEntry = null;
            }
        }
    }

    // ── attention ──
    // Keyed by path, not by index: the filter reorders and shortens the list as
    // the user types, and an index would silently point at a different
    // wallpaper the moment it did.
    readonly property var entries: Wallpapers.visibleEntries
    property string focusPath: ""

    // A function, not a bound property: the strip's index has to be pushed from
    // here and read back when the view is flicked, and a two-way binding on a
    // derived index is a loop by construction.
    function indexOfPath(path) {
        for (let i = 0; i < win.entries.length; i++) {
            if (win.entries[i].path === path) return i;
        }
        return -1;
    }

    readonly property var focusedEntry: {
        const at = win.indexOfPath(win.focusPath);
        return at >= 0 ? win.entries[at] : null;
    }

    function syncToApplied() {
        const hit = win.indexOfPath(Wallpapers.currentPath);
        if (hit >= 0) win.focusPath = win.entries[hit].path;
        else if (win.entries.length > 0) win.focusPath = win.entries[0].path;
    }

    function syncStrip() {
        const at = win.indexOfPath(win.focusPath);
        if (at >= 0 && strip.currentIndex !== at) strip.currentIndex = at;
    }

    onFocusPathChanged: {
        settle.restart();
        win.syncStrip();
    }

    // Falling out of the filtered list is the normal case while typing, so the
    // first surviving match takes over rather than the strip going blank.
    Connections {
        target: Wallpapers
        function onVisibleEntriesChanged() {
            if (win.indexOfPath(win.focusPath) < 0 && win.entries.length > 0) {
                win.focusPath = win.entries[0].path;
            } else {
                win.syncStrip();
            }
        }
    }

    function step(delta) {
        const n = win.entries.length;
        if (n === 0) return;
        const at = Math.max(0, win.indexOfPath(win.focusPath));
        win.focusPath = win.entries[Math.max(0, Math.min(n - 1, at + delta))].path;
    }

    function applyFocused() {
        if (!win.focusedEntry) return;
        Wallpapers.apply(win.focusedEntry.path);
        Toggles.wallpaperPickerOpen = false;
    }

    // ── full-screen preview ──
    // Settled rather than immediate: holding an arrow key down would otherwise
    // start a full-resolution decode, and possibly a video, per keystroke.
    property var previewEntry: null

    Timer {
        id: settle
        interval: 190
        onTriggered: {
            win.previewEntry = win.focusedEntry;
            if (win.focusedEntry) Wallpapers.request(win.focusedEntry);
        }
    }

    readonly property bool previewIsVideo: win.previewEntry !== null && win.previewEntry.video
    // A video previews through the frame already extracted for its thumbnail
    // until playback has something to show.
    readonly property string previewImage: !win.previewEntry
        ? ""
        : "file://" + (win.previewEntry.video ? win.previewEntry.thumb : win.previewEntry.path)

    readonly property var previewPalette: win.previewEntry
        ? (Wallpapers.palettes[win.previewEntry.path] || null)
        : null
    readonly property var previewMeta: win.previewEntry
        ? (Wallpapers.meta[win.previewEntry.path] || null)
        : null

    // ── input ──
    property bool searching: false

    function handleKey(event) {
        const k = event.key;
        event.accepted = true;

        if (k === Qt.Key_Escape) {
            if (win.searching || Wallpapers.search !== "") {
                win.searching = false;
                Wallpapers.search = "";
            } else {
                Toggles.wallpaperPickerOpen = false;
            }
            return;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) return win.applyFocused();
        if (k === Qt.Key_Backspace) {
            Wallpapers.search = Wallpapers.search.slice(0, -1);
            if (Wallpapers.search === "") win.searching = false;
            return;
        }
        if (k === Qt.Key_Left || k === Qt.Key_Up) return win.step(-1);
        if (k === Qt.Key_Right || k === Qt.Key_Down) return win.step(1);
        if (k === Qt.Key_PageUp) return win.step(-5);
        if (k === Qt.Key_PageDown) return win.step(5);
        if (k === Qt.Key_Home) return win.step(-win.entries.length);
        if (k === Qt.Key_End) return win.step(win.entries.length);
        if (k === Qt.Key_Slash) {
            win.searching = true;
            return;
        }

        // hjkl only while nothing is being typed. Letters have to reach the
        // search box — the alternative is a picker where no wallpaper whose
        // name starts with those four letters can ever be found. `/` is the way
        // back into search when they are wanted.
        if (!win.searching) {
            if (k === Qt.Key_H || k === Qt.Key_K) return win.step(-1);
            if (k === Qt.Key_L || k === Qt.Key_J) return win.step(1);
            if (k === Qt.Key_Space) return win.applyFocused();
        }

        const t = event.text;
        if (t && t.length === 1 && t.charCodeAt(0) >= 0x20) {
            win.searching = true;
            Wallpapers.search += t;
            return;
        }
        event.accepted = false;
    }

    // ── backdrop ──
    // Two images flip-flopping. Swapping one Image's source hard-cuts, and the
    // whole point of a full-screen preview is that walking the strip feels
    // continuous rather than like a slideshow of jump cuts.
    property bool showingB: false

    onPreviewImageChanged: {
        const incoming = win.showingB ? previewA : previewB;
        incoming.source = win.previewImage;
    }

    Item {
        anchors.fill: parent
        opacity: win.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: win.open ? Theme.animSlow : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
            }
        }

        // A touch of overscale on entry, released as the picker settles — the
        // backdrop arrives rather than simply being switched on.
        scale: win.open ? 1.0 : 1.06
        Behavior on scale {
            NumberAnimation {
                duration: win.open ? Theme.animEnter : Theme.animExit
                easing.type: Easing.OutExpo
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.crust
        }

        Image {
            id: previewA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Screen.width
            sourceSize.height: Screen.height
            asynchronous: true
            cache: false
            opacity: win.showingB ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready && win.showingB) win.showingB = false
        }

        Image {
            id: previewB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Screen.width
            sourceSize.height: Screen.height
            asynchronous: true
            cache: false
            opacity: win.showingB ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready && !win.showingB) win.showingB = true
        }

        // Exactly one decoder for the whole library, and only for the entry the
        // user has settled on.
        Connections {
            target: Toggles
            function onWallpaperPickerOpenChanged() {
                if (!Toggles.wallpaperPickerOpen) {
                    player.stop();
                    Wallpaper._previewing = false;
                }
            }
        }

        MediaPlayer {
            id: player
            source: win.previewIsVideo ? "file://" + win.previewEntry.path : ""
            loops: MediaPlayer.Infinite
            // No audioOutput at all, rather than a muted one. A muted sink still
            // opens the stream: Qt kept a QFFmpeg audio renderer thread and a
            // PipeWire data loop running to produce silence, which measured 3.0
            // points of a core for a wallpaper that is decoration by definition.
            videoOutput: videoOut
            onSourceChanged: source == "" ? stop() : play()

            // The desktop's own copy is hidden behind this window and does not
            // need decoding while this one is up.
            onPlaybackStateChanged: Wallpaper._previewing =
                (playbackState === MediaPlayer.PlayingState)
            Component.onDestruction: Wallpaper._previewing = false
        }

        VideoOutput {
            id: videoOut
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            opacity: win.previewIsVideo && player.playbackState === MediaPlayer.PlayingState ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
        }
    }

    // Scrim. Heavier at the bottom, where the filmstrip and the hints have to
    // stay readable over whatever the wallpaper happens to be there.
    Rectangle {
        anchors.fill: parent
        opacity: win.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: win.open ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
            }
        }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.crust, Theme.veilDense) }
            GradientStop { position: 0.38; color: Qt.alpha(Theme.crust, Theme.veilThin) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, Theme.veilSolid) }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.wallpaperPickerOpen = false
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: Toggles.wallpaperPickerOpen
        Keys.onPressed: event => win.handleKey(event)

        // ── header ──
        Row {
            id: header
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 44
            anchors.topMargin: 40
            spacing: 16

            opacity: win.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
            transform: Translate {
                y: win.open ? 0 : -26
                Behavior on y {
                    NumberAnimation {
                        duration: win.open ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: win.open ? Theme.easeSpringBig : Theme.easeExit
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Обои"
                color: Theme.text
                font.pixelSize: Theme.fontHeadline
                font.bold: true
                font.letterSpacing: -0.5
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpapers.search !== ""
                    ? win.entries.length + " из " + Wallpapers.entries.length
                    : Wallpapers.entries.length + " шт."
                color: Theme.subtext0
                font.pixelSize: Theme.fontBody
            }

            // Search reads as a field but is not one: keystrokes are routed by
            // handleKey so arrows can page the strip without a caret stealing
            // them.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 300
                height: 34
                radius: Theme.pill(height)
                color: Qt.alpha(Theme.crust, win.searching ? 0.9 : 0.6)
                border.width: 1
                border.color: win.searching ? Theme.accent : Qt.alpha(Theme.text, Theme.fillHover)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    id: searchGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: Glyphs.magnify
                    font.family: Theme.fontIconFamily
                    font.pixelSize: Theme.fontIconMicro
                    color: win.searching ? Theme.accent : Theme.subtext0
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    id: searchText
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallpapers.search !== ""
                        ? Wallpapers.search
                        : (win.searching ? "" : "Начните печатать или нажмите /")
                    color: Wallpapers.search !== "" ? Theme.text : Theme.subtext0
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.left: searchText.right
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1.5
                    height: 15
                    color: Theme.accent
                    visible: win.searching
                    SequentialAnimation on opacity {
                        running: win.searching
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: Theme.animEnter }
                        NumberAnimation { to: 1; duration: Theme.animEnter }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: win.searching = true
                }
            }
        }

        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 40
            width: 34
            height: 34
            radius: Theme.pill(height)
            color: closeArea.containsMouse ? Theme.red : Qt.alpha(Theme.crust, Theme.veilDense)
            opacity: win.open ? 1 : 0
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
            scale: closeArea.containsMouse ? 1.1 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
            }

            Text {
                anchors.centerIn: parent
                text: Glyphs.close
                font.family: Theme.fontIconFamily
                font.pixelSize: Theme.fontIconSmall
                color: Theme.text
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Toggles.wallpaperPickerOpen = false
            }
        }

        // ── side column ──
        // Beside the preview rather than under the strip: this is what the
        // wallpaper *is* and what it will do to the shell, and it belongs next
        // to the image it describes, not at the bottom of a list of thumbnails.
        Item {
            id: side
            anchors.right: parent.right
            anchors.rightMargin: 44
            anchors.bottom: strip.top
            anchors.bottomMargin: 30
            width: 340
            height: sideCard.height

            opacity: win.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            transform: Translate {
                x: win.open ? 0 : 70
                Behavior on x {
                    NumberAnimation {
                        duration: win.open ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: win.open ? Theme.easeSpringBig : Theme.easeExit
                    }
                }
            }

            Rectangle {
                id: sideCard
                width: parent.width
                height: sideColumn.height + 44
                radius: Theme.radiusLarge
                // Deliberately not frosted glass: the backing samples the
                // *applied* wallpaper, and over a full-screen preview of a
                // different one that mismatch is visible.
                color: Qt.alpha(Theme.crust, Theme.veilSolid)
                border.width: 1
                border.color: Qt.alpha(Theme.text, Theme.strokeSoft)

                Column {
                    id: sideColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 22
                    spacing: Theme.gapCard

                    Text {
                        width: parent.width
                        text: win.previewEntry ? win.previewEntry.label : "—"
                        color: Theme.text
                        font.pixelSize: Theme.fontDisplay
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 8

                        Rectangle {
                            width: kindText.width + 18
                            height: 22
                            radius: Theme.radiusChip
                            color: Qt.alpha(Theme.accent, 0.18)

                            Text {
                                id: kindText
                                anchors.centerIn: parent
                                text: win.previewEntry && win.previewEntry.video ? "ВИДЕО" : "ФОТО"
                                color: Theme.accent
                                font.pixelSize: Theme.fontMicro
                                font.bold: true
                                font.letterSpacing: 1
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.previewMeta ? win.previewMeta.size : "…"
                            color: Theme.subtext1
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.previewMeta ? Wallpapers.formatBytes(win.previewMeta.bytes) : ""
                            color: Theme.subtext0
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.alpha(Theme.text, Theme.fillMuted)
                    }

                    // The live palette when the focused wallpaper is the one on
                    // screen — so swatches stay pinnable — and the probe of what
                    // it would become otherwise.
                    PalettePreview {
                        width: parent.width
                        swatchSize: 28
                        probe: (win.previewEntry && win.previewEntry.path === Wallpapers.currentPath)
                            ? null
                            : win.previewPalette
                        // Nothing to say until the probe lands; a half-drawn
                        // palette is worse than a beat of nothing.
                        visible: win.previewEntry !== null
                            && (win.previewEntry.path === Wallpapers.currentPath || win.previewPalette !== null)
                    }

                    Rectangle {
                        id: applyButton
                        width: parent.width
                        height: 40
                        radius: Theme.radius + 2
                        readonly property bool isApplied: win.previewEntry
                            && win.previewEntry.path === Wallpapers.currentPath
                        color: applyButton.isApplied
                            ? Qt.alpha(Theme.text, Theme.fillSubtle)
                            : (applyArea.containsMouse ? Theme.accent : Qt.alpha(Theme.accent, Theme.veilSolid))
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        scale: applyArea.pressed ? 0.97 : 1
                        Behavior on scale {
                            NumberAnimation { duration: Theme.animFast; easing.type: Easing.Bezier; easing.bezierCurve: Theme.easeSpring }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: applyButton.isApplied ? "Уже установлены" : "Установить"
                            color: applyButton.isApplied ? Theme.subtext0 : Theme.crust
                            font.pixelSize: Theme.fontLead
                            font.bold: true
                        }

                        MouseArea {
                            id: applyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !applyButton.isApplied
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.applyFocused()
                        }
                    }
                }
            }
        }

        // ── key hints ──
        Row {
            id: hints
            anchors.left: parent.left
            anchors.leftMargin: 44
            anchors.bottom: strip.top
            anchors.bottomMargin: 34
            spacing: Theme.gapSection

            opacity: win.open ? 0.8 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

            Repeater {
                model: [
                    { keys: "← →", what: "листать" },
                    { keys: "Enter", what: "установить" },
                    { keys: "/", what: "поиск" },
                    { keys: "Esc", what: "закрыть" }
                ]

                delegate: Row {
                    id: hint
                    required property var modelData
                    spacing: Theme.spacing

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: hintKey.width + 14
                        height: 21
                        // A keycap, so the pip rung rather than the chip one:
                        // at chip radius a 21px-high hint is most of a pill and
                        // stops reading as a key.
                        radius: Theme.radiusPip
                        color: Qt.alpha(Theme.text, Theme.fillHover)

                        Text {
                            id: hintKey
                            anchors.centerIn: parent
                            text: hint.modelData.keys
                            color: Theme.text
                            font.pixelSize: Theme.fontLabel
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hint.modelData.what
                        color: Theme.subtext0
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }

        // ── filmstrip ──
        // A reel, centred on the frame under attention. StrictlyEnforceRange is
        // what makes the wheel, a drag and the arrow keys all end in the same
        // place: whatever sits in the centre band is the current index, by
        // definition.
        ListView {
            id: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 34
            height: 178
            orientation: ListView.Horizontal
            spacing: Theme.gapSection
            clip: false

            opacity: win.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            transform: Translate {
                y: win.open ? 0 : 90
                Behavior on y {
                    NumberAnimation {
                        duration: win.open ? Theme.animSlow : Theme.animExit
                        easing.type: Easing.Bezier
                        easing.bezierCurve: win.open ? Theme.easeSpringBig : Theme.easeExit
                    }
                }
            }

            readonly property int frameWidth: 250

            preferredHighlightBegin: (width - strip.frameWidth) / 2
            preferredHighlightEnd: (width + strip.frameWidth) / 2
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 330
            highlightMoveVelocity: -1
            snapMode: ListView.SnapToItem

            model: ScriptModel {
                values: Wallpapers.visibleEntries
                objectProp: "path"
            }

            // Real additions only — see BarWorkspaces. Filtering the list as the
            // user types is exactly the case where every surviving frame must
            // not replay its entry.
            add: MotionAdd {}
            move: MotionMove {}
            populate: MotionAdd {}

            onCurrentIndexChanged: {
                const entry = Wallpapers.visibleEntries[strip.currentIndex];
                if (entry && entry.path !== win.focusPath) win.focusPath = entry.path;
            }

            // A vertical wheel is what a mouse actually has, and on a horizontal
            // view Qt does not map it to anything.
            WheelHandler {
                orientation: Qt.Vertical | Qt.Horizontal
                onWheel: event => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (delta !== 0) win.step(delta > 0 ? -1 : 1);
                }
            }

            delegate: Item {
                required property var modelData
                required property int index
                width: strip.frameWidth
                height: strip.height

                WallpaperTile {
                    anchors.centerIn: parent
                    width: strip.frameWidth
                    height: 148
                    modelData: parent.modelData
                    index: parent.index
                    focusedItem: parent.modelData.path === win.focusPath
                    applied: parent.modelData.path === Wallpapers.currentPath
                    thumbReady: Wallpapers.ready[parent.modelData.key] === true

                    onRequested: win.focusPath = parent.modelData.path
                    onActivated: win.applyFocused()
                }
            }
        }

        // Nothing in the library at all, which otherwise looks like the picker
        // failed to open.
        Text {
            anchors.centerIn: parent
            visible: win.entries.length === 0
            text: Wallpapers.entries.length === 0
                ? "В ~/Pictures/Wallpapers пусто"
                : "Ничего не найдено"
            color: Theme.subtext0
            font.pixelSize: Theme.fontTitle
        }
    }
}
