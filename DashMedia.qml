import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

// The media page.
//
// One object on the left that is the album and the sound at once, the track set
// large beside it, and the transport underneath. Everything else a player
// exposes — which player, shuffle, repeat — sits at the bottom where it does
// not compete with the two things actually being read.
Item {
    id: root

    property bool revealed: true

    DashCard {
        id: card
        order: 0
        revealed: root.revealed
        anchors.fill: parent

        EmptyState {
            anchors.centerIn: parent
            visible: !Media.hasPlayer
            text: "Ничего не играет"
            catSize: 150
        }

        Item {
            anchors.fill: parent
            anchors.margins: 22
            visible: Media.hasPlayer

            MediaOrb {
                id: orb
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                // Sized from the room the whole figure gets, ring included.
                coverSize: Math.min(orb.coverFor(parent.height), 168)
            }

            MediaCat {
                id: cat
                anchors.right: parent.right
                anchors.rightMargin: 6
                // Sits with the block it belongs to. On the card's bottom edge
                // it read as having fallen out of the layout instead of being
                // part of it.
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 30
            }

            Column {
                anchors.left: orb.right
                anchors.right: cat.left
                anchors.leftMargin: 26
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: Media.title
                    color: Theme.text
                    font.family: Theme.fontDisplayFamily
                    font.pixelSize: Theme.fontDisplay
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.trackDisplay
                    // Wraps to a second line before it gives up. The column is
                    // narrow -- an orb on one side and a cat on the other --
                    // and eliding at one line threw away most of every video
                    // title while a card two hundred pixels tall sat empty
                    // underneath it.
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: Media.artist
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLead
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    // Sources that have no album name often put the track's
                    // there, and a line repeating the title reads as a fault.
                    text: {
                        const album = Media.player ? (Media.player.trackAlbum || "") : "";
                        return album === Media.title ? "" : album;
                    }
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }

                Item { width: 1; height: 14 }

                SeekWave { width: parent.width }

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        text: root.clock(Media.position)
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                        font.features: ({ "tnum": 1 })
                    }

                    // A stream has no length, and MPRIS reports that as zero.
                    // Printing it as 0:00 next to a running elapsed time is a
                    // clock that says the track is over while it plays.
                    Row {
                        anchors.right: parent.right
                        spacing: 5
                        visible: Media.length <= 0

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.red
                            opacity: Media.playing ? 1 : 0.4

                            SequentialAnimation on opacity {
                                running: Media.playing
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "прямой эфир"
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMicro
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        visible: Media.length > 0
                        text: root.clock(Media.length)
                        color: Theme.subtext0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMicro
                        font.features: ({ "tnum": 1 })
                    }
                }

                Item { width: 1; height: 8 }

                Row {
                    spacing: 10

                    MediaButton {
                        glyph: Media.shuffleOn ? Glyphs.shuffle : Glyphs.shuffleOff
                        visible: Media.canShuffle
                        size: 30
                        onActivated: Media.toggleShuffle()
                    }
                    MediaButton { glyph: Glyphs.skipPrevious; onActivated: Media.previous() }
                    MediaButton {
                        glyph: Media.playing ? Glyphs.pause : Glyphs.play
                        size: 44
                        accented: true
                        onActivated: Media.togglePlay()
                    }
                    MediaButton { glyph: Glyphs.skipNext; onActivated: Media.next() }
                    MediaButton {
                        glyph: Media.loopGlyph
                        size: 30
                        onActivated: Media.cycleLoop()
                    }
                }

                Item { width: 1; height: 10; visible: sources.visible }

                // Which application this is. The shell picks whatever is
                // playing, which is right almost always and wrong exactly when
                // two things are paused and you meant the other one -- so the
                // choice is shown rather than inferred silently, and clicking a
                // source pins it until you click it again.
                Row {
                    id: sources
                    spacing: 7
                    visible: Mpris.players.values.length > 1

                    Repeater {
                        model: Mpris.players.values

                        delegate: Rectangle {
                            id: chip
                            required property var modelData

                            readonly property bool current: Media.player === chip.modelData
                            readonly property bool held: Media.pinned === chip.modelData

                            width: chipRow.implicitWidth + 18
                            height: 26
                            radius: 13
                            color: chip.current ? Qt.alpha(MediaTint.accent, 0.22)
                                : (chipHit.containsMouse ? Qt.alpha(Theme.text, 0.10)
                                                         : Qt.alpha(Theme.text, 0.05))
                            border.width: 1
                            border.color: chip.held ? Qt.alpha(MediaTint.accent, 0.8) : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 14
                                    // Through the desktop entry, not through the
                                    // entry's id. MPRIS reports the id
                                    // (org.mozilla.firefox), which is not an icon
                                    // name -- the theme has no such icon and every
                                    // load logged a failure.
                                    source: {
                                        const id = chip.modelData.desktopEntry;
                                        const entry = id ? DesktopEntries.byId(String(id)) : null;
                                        const name = entry && entry.icon
                                            ? entry.icon : "application-x-executable";
                                        return Icons.forName(name);
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    // The desktop entry's name first: MPRIS
                                    // identity is whatever the application felt
                                    // like publishing, and Firefox publishes
                                    // "Mozilla org.mozilla.firefox".
                                    text: {
                                        const id = chip.modelData.desktopEntry;
                                        const entry = id ? DesktopEntries.byId(String(id)) : null;
                                        if (entry && entry.name) return entry.name;
                                        return chip.modelData.identity || "?";
                                    }
                                    color: chip.current ? Theme.text : Theme.subtext0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                    font.weight: chip.current ? Font.Medium : Font.Normal
                                }
                            }

                            MouseArea {
                                id: chipHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Media.pin(chip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    // MPRIS reports both of these in seconds.
    function clock(seconds) {
        if (!seconds || seconds <= 0) return "0:00";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
