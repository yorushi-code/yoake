import QtQuick
import Quickshell
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

        Text {
            anchors.centerIn: parent
            visible: !Media.hasPlayer
            text: "Ничего не играет"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitle
        }

        Item {
            anchors.fill: parent
            anchors.margins: 22
            visible: Media.hasPlayer

            MediaOrb {
                id: orb
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                coverSize: Math.min(parent.height - 40, 168)
            }

            MediaCat {
                id: cat
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 6
                anchors.bottomMargin: 4
            }

            Column {
                anchors.left: orb.right
                anchors.right: cat.left
                anchors.leftMargin: 26
                anchors.rightMargin: 20
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

                    Text {
                        anchors.right: parent.right
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
