import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The controls, as a page of the dashboard.
//
// They used to be their own 400px panel on Mod+P, which meant two overlapping
// answers to "show me what the machine is doing": one sheet with the clock, the
// calendar, the player and the sensors, and beside it a second surface with the
// switches. Nothing about the switches wanted a separate window — they wanted
// more width than 400px, which the sheet already has.
//
// The tiles keep their detail pages. A network list that pushed the panel taller
// was the reason CcPager exists, and that reasoning does not change by moving
// house: the detail slides in over this page, the sheet never resizes.
Item {
    id: root

    property bool revealed: true

    readonly property int gap: 14

    // Which tile's detail is showing, "" for the controls themselves.
    property string page: ""

    // Reopening onto whatever page was last visited hides the controls the user
    // came for.
    onRevealedChanged: if (!root.revealed) root.page = "";

    // Both ends have to be tracked, or PipeWire never sends their properties
    // and the sliders sit at zero.
    PwObjectTracker {
        objects: {
            const list = [];
            if (Pipewire.defaultAudioSink) list.push(Pipewire.defaultAudioSink);
            if (Pipewire.defaultAudioSource) list.push(Pipewire.defaultAudioSource);
            return list;
        }
    }

    readonly property real volume: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
        ? Pipewire.defaultAudioSink.audio.volume : 0

    readonly property var micSource: Pipewire.defaultAudioSource
    readonly property real micVolume: root.micSource && root.micSource.audio
        ? root.micSource.audio.volume : 0
    readonly property bool micMuted: root.micSource && root.micSource.audio
        ? root.micSource.audio.muted : false

    Component { id: wifiPage; CcWifiPage {} }
    Component { id: bluetoothPage; CcBluetoothPage {} }
    Component { id: displayPage; CcDisplayPage {} }
    Component { id: powerPage; CcPowerPage {} }

    readonly property Component pageComponent: {
        switch (root.page) {
        case "wifi": return wifiPage;
        case "bluetooth": return bluetoothPage;
        case "display": return displayPage;
        case "power": return powerPage;
        }
        return null;
    }

    readonly property string pageTitle: {
        switch (root.page) {
        case "wifi": return "Wi-Fi";
        case "bluetooth": return "Bluetooth";
        case "display": return "Экран";
        case "power": return "Питание";
        }
        return "";
    }

    CcPager {
        anchors.fill: parent
        page: root.page
        title: root.pageTitle
        pageComponent: root.pageComponent
        onBack: root.page = ""

        // ── Tiles ──
        DashCard {
            id: tileCard
            order: 0
            revealed: root.revealed
            title: "Быстрые действия"
            anchors.top: parent.top
            anchors.left: parent.left
            width: Math.round(parent.width * 0.56)
            // Sized to the grid, not stretched to the foot of the sheet — the
            // same rule the Apps card below already states and this one
            // contradicted. Centring the grid in a card taller than it needs
            // put forty-six pixels of nothing between the heading and the
            // thing it heads, and a detached header reads as broken where a
            // short card reads as a column that has finished.
            height: 36 + 6 + tiles.height + 16

            CcTileGrid {
                id: tiles
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                anchors.topMargin: 6
                // Three across rather than two: the sheet is more than twice
                // the width of the panel this came from, and two columns of
                // very wide tiles read as a list of buttons.
                columns: 3
                onPageRequested: name => root.page = name
            }
        }

        // ── Levels ──
        DashCard {
            id: levelCard
            order: 1
            revealed: root.revealed
            title: "Уровни"
            anchors.top: parent.top
            anchors.left: tileCard.right
            anchors.leftMargin: root.gap
            anchors.right: parent.right
            height: 206

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                SliderRow {
                    width: parent.width
                    label: "Громкость " + Math.round(root.volume * 100) + "%"
                    value: root.volume
                    onMoved: v => {
                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                            Pipewire.defaultAudioSink.audio.volume = v;
                        }
                    }
                }

                SliderRow {
                    width: parent.width
                    visible: Brightness.value >= 0
                    label: "Яркость " + Math.round(Brightness.value * 100) + "%"
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                }

                // The third level anyone actually reaches for, and the only one
                // that was reachable solely through a right-click menu on the
                // bar. A card called "Уровни" that omits the microphone is
                // asking to be looked past.
                SliderRow {
                    width: parent.width
                    visible: root.micSource !== null
                    label: root.micMuted
                        ? "Микрофон выключен"
                        : "Микрофон " + Math.round(root.micVolume * 100) + "%"
                    value: root.micMuted ? 0 : root.micVolume
                    onMoved: v => {
                        if (root.micSource && root.micSource.audio) {
                            root.micSource.audio.muted = false;
                            root.micSource.audio.volume = v;
                        }
                    }
                }
            }
        }

        // ── Apps ──
        DashCard {
            id: launchCard
            order: 2
            revealed: root.revealed
            title: "Приложения"
            anchors.top: levelCard.bottom
            anchors.topMargin: root.gap
            anchors.left: tileCard.right
            anchors.leftMargin: root.gap
            anchors.right: parent.right
            visible: launcher.entries.length > 0
            // Sized to the chips rather than stretched to the bottom of the
            // sheet. A right column shorter than the left is a layout; a card
            // with a void under its content is a mistake.
            height: 36 + 6 + launcher.height + 16

            // Anchored to the top, not centred: the list grows as habits do,
            // and a centred one left a hand's width of nothing directly under
            // the heading -- the gap that reads as broken rather than as room.
            CcQuickLaunch {
                id: launcher
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                anchors.topMargin: 6
            }
        }
    }

    // Brightness is read from sysfs on demand rather than polled, so the page
    // has to ask when it becomes visible or the slider shows the value from
    // whenever it was last opened.
    onVisibleChanged: if (root.visible) Brightness.refresh();
}
