import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell

// Wallpaper grid, in the shell rather than in a separate application.
//
// It replaces a GTK4 window wrapping a WebKit view — two toolkits and a
// browser engine, spawned per use, themed separately from everything around
// it, and with no way to show what a wallpaper would do to the palette before
// committing to it. That preview is the point: the accent is derived from the
// image (see wallpaper-palette.py), so seeing the swatches beside the grid is
// what makes the connection between the two legible.
PanelWindow {
    id: win

    // See ControlCenter: mapping is an explicit bool so the exit animation is
    // not cut off by a visible-binding race.
    property bool mapped: false
    visible: mapped

    // Animations bind to this, not the toggle: created lazily, the picker is
    // born with the toggle already true and an entry animation would have
    // nothing to animate from.
    readonly property bool open: Toggles.wallpaperPickerOpen && win.armed
    property bool armed: false
    Component.onCompleted: {
        armTick.start();
        win.mapped = Toggles.wallpaperPickerOpen;
    }
    property Timer _armTick: Timer {
        id: armTick
        interval: 16
        onTriggered: win.armed = true
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    focusable: Toggles.wallpaperPickerOpen

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
            } else {
                hideDelay.restart();
            }
        }
    }

    // ── shared video preview ──
    // One player for the whole grid. Reparented into whichever tile is hovered;
    // a player per tile would leave a dozen decoders running behind a grid
    // where only one card can be under the pointer.
    property Item hoveredTile: null

    MediaPlayer {
        id: preview
        source: win.hoveredTile ? "file://" + win.hoveredTile.modelData.path : ""
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { muted: true; volume: 0 }
        videoOutput: previewOut
        onSourceChanged: if (source != "") play()
    }

    VideoOutput {
        id: previewOut
        fillMode: VideoOutput.PreserveAspectCrop
        visible: win.hoveredTile !== null
        // Reparented into the hovered tile's slot; anchors follow it there.
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.crust
        opacity: win.open ? 0.55 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: win.open ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Toggles.wallpaperPickerOpen = false
        }
    }

    Item {
        anchors.fill: parent
        focus: Toggles.wallpaperPickerOpen
        Keys.onEscapePressed: Toggles.wallpaperPickerOpen = false

        PanelChrome {
            id: chrome
            anchors.centerIn: parent
            width: Math.min(1180, Screen.width - 120)
            height: Math.min(760, Screen.height - Theme.barHeight - 90)
            screenX: (Screen.width - width) / 2
            screenY: (Screen.height - height) / 2

            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : Theme.revealScale
            Behavior on opacity {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeEmphasized : Theme.easeExit
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: win.open ? Theme.animSlow : Theme.animExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: win.open ? Theme.easeSpringBig : Theme.easeExit
                }
            }
            onCloseRequested: Toggles.wallpaperPickerOpen = false

            // Swallows clicks so the backdrop does not treat a click on the
            // card itself as "outside".
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Item {
                anchors.fill: parent
                anchors.margins: 22
                anchors.topMargin: 40

                // ── header ──
                Row {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 34
                    spacing: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Обои"
                        color: Theme.text
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Wallpapers.visibleEntries.length + " из " + Wallpapers.entries.length
                        color: Theme.subtext0
                        font.pixelSize: 11
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260
                        height: 30
                        radius: 15
                        color: Qt.alpha(Theme.text, searchField.activeFocus ? 0.12 : 0.07)
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: searchGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: Glyphs.folder
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: Theme.subtext0
                        }

                        TextInput {
                            id: searchField
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            font.pixelSize: 12
                            clip: true
                            onTextChanged: Wallpapers.search = text
                            // Cleared by the toggle handler; mirror it here so
                            // the field does not keep a stale query.
                            Connections {
                                target: Wallpapers
                                function onSearchChanged() {
                                    if (Wallpapers.search === "") searchField.text = "";
                                }
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Поиск"
                                color: Theme.subtext0
                                font.pixelSize: 12
                                visible: searchField.text === ""
                            }
                        }
                    }
                }

                // ── palette preview ──
                // Beside the grid rather than buried in the control centre: the
                // whole reason the accent looks the way it does is the image
                // being chosen right here.
                PalettePreview {
                    id: palette
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    swatchSize: 26
                }

                // ── grid ──
                GridView {
                    id: grid
                    anchors.top: header.bottom
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: palette.top
                    anchors.bottomMargin: 18
                    clip: true

                    readonly property int columns: Math.max(2, Math.floor(width / 250))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: Math.floor(cellWidth * 0.62)

                    model: ScriptModel {
                        values: Wallpapers.visibleEntries
                        objectProp: "path"
                    }

                    // Real additions only — see BarWorkspaces. Filtering the
                    // list as the user types is exactly the case where every
                    // surviving tile must not replay its entry.
                    add: MotionAdd {}
                    move: MotionMove {}
                    populate: MotionAdd {}

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight

                        WallpaperTile {
                            id: tile
                            anchors.fill: parent
                            anchors.margins: 9
                            modelData: parent.modelData
                            index: parent.index
                            current: modelData.path === Wallpapers.currentPath
                            thumbReady: Wallpapers.ready[modelData.key] === true

                            onActivated: {
                                Wallpapers.apply(modelData.path);
                                Toggles.wallpaperPickerOpen = false;
                            }

                            // Hand the shared player to this tile while the
                            // cursor is on it, and take it back on the way out.
                            onHoveredChanged: {
                                if (!tile.modelData.video) return;
                                if (tile.hovered) {
                                    win.hoveredTile = tile;
                                    previewOut.parent = tile.slot;
                                } else if (win.hoveredTile === tile) {
                                    win.hoveredTile = null;
                                    previewOut.parent = win.contentItem;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
