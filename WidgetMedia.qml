import QtQuick
import QtQuick.Effects

// Now playing, on the desktop.
//
// Unlike the popup this one is not transient: it is where the transport
// controls live when the desktop is visible, so it stays for as long as there
// is a player.
Item {
    id: root

    // Where on screen the glass should sample the wallpaper. Set by the
    // surface, which is the only thing that knows where the widget ended up.
    property real screenX: 0
    property real screenY: 0

    width: 420
    height: 96

    RectangularShadow {
        anchors.fill: cardGlass
        radius: cardGlass.radius
        color: Theme.shadowColor
        blur: Theme.shadowBlur
        spread: Theme.shadowSpread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    FrostedBackground {
        id: cardGlass
        anchors.fill: parent
        radius: 20
        screenX: root.screenX
        screenY: root.screenY
    }

    Row {
        anchors.fill: parent
        anchors.margins: 13
        spacing: 12

        AlbumArt {
            size: 60
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60 - 12 - deskControls.width - 12
            spacing: 5

            Text {
                width: parent.width
                text: Media.title
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Media.artist
                color: Theme.subtext1
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            SeekBar { width: parent.width }
        }

        Row {
            id: deskControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            MediaButton {
                glyph: Glyphs.skipPrevious
                size: 28
                enabled: Media.player !== null && Media.player.canGoPrevious
                onActivated: Media.previous()
            }
            MediaButton {
                glyph: Media.playing ? Glyphs.pause : Glyphs.play
                size: 34
                accented: true
                enabled: Media.player !== null && Media.player.canTogglePlaying
                onActivated: Media.togglePlay()
            }
            MediaButton {
                glyph: Glyphs.skipNext
                size: 28
                enabled: Media.player !== null && Media.player.canGoNext
                onActivated: Media.next()
            }
        }
    }
}
