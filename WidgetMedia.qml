import QtQuick
import QtQuick.Effects

// Now playing, on the desktop.
//
// Unlike the popup this one is not transient: it is where the transport lives
// while the desktop is visible, so it stays for as long as there is a player.
//
// It was a thumbnail, two lines and a hairline — the same card every shell has.
// It carries the record now, at the size that fits, so the desktop, the
// dashboard and the popup are visibly the same player rather than three widgets
// that happen to show the same track.
Item {
    id: root

    // Where on screen the glass should sample the wallpaper. Set by the
    // surface, which is the only thing that knows where the widget ended up.
    property real screenX: 0
    property real screenY: 0

    width: 430
    height: 124

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

    // The cover, washed across the card. One cached texture — the blur is a
    // layer Qt renders once per track, not once per frame.
    Image {
        id: bleed
        anchors.fill: parent
        source: Media.cover
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 320
        sourceSize.height: 320
        asynchronous: true
        retainWhileLoading: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: bleed
        visible: bleed.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        blurMultiplier: 1.1
        saturation: 0.2
        opacity: 0.36
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        MediaOrb {
            id: orb
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // No spectrum ring at this size: the bars would be three pixels
            // long and read as fringe rather than as sound.
            coverSize: 84
            barLength: 9
            barWidth: 2
            gap: 5
        }

        Column {
            anchors.left: orb.right
            anchors.right: deskControls.left
            anchors.leftMargin: 6
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: Media.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLead
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Media.artist
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }

            SeekWave {
                width: parent.width
                implicitHeight: 20
                barCount: 40
            }
        }

        Row {
            id: deskControls
            anchors.right: parent.right
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
