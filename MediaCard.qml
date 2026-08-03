import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// The compact player, shared by the desktop widget and the popup.
//
// It carried the radial orb for a while, which was a mistake with a clear
// cause: that figure is drawn for a 150px cover, and squeezed into 84 its bars
// are two pixels long and collapse into a dotted ring. Detail that does not
// survive its size is not detail, it is noise — so at this size the cover is
// simply a cover, large and square, and the sound is carried by the waveform
// that is already there for the position.
//
// One component for both surfaces, so they cannot drift apart the way three
// separate copies of the same player did.
Item {
    id: root

    // Where on screen the glass should sample the wallpaper.
    property real screenX: 0
    property real screenY: 0
    property bool showGlass: true
    property real radius: 20

    implicitWidth: 440
    implicitHeight: 116

    // MPRIS reports both of these in seconds.
    function clock(seconds) {
        if (!seconds || seconds <= 0) return "0:00";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    RectangularShadow {
        anchors.fill: glass
        radius: glass.radius
        visible: root.showGlass
        color: Theme.shadowColor
        blur: Theme.shadowBlur
        spread: Theme.shadowSpread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    FrostedBackground {
        id: glass
        anchors.fill: parent
        radius: root.radius
        visible: root.showGlass
        screenX: root.screenX
        screenY: root.screenY
    }

    // The cover washed across the card. One cached texture: the blur is a layer
    // Qt renders once per track rather than once per frame.
    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

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
            blurMultiplier: 1.2
            saturation: 0.3
            opacity: 0.42
        }

        // Darkest under the type, clearest under the cover — the words have to
        // survive whatever the album happens to look like.
        Rectangle {
            anchors.fill: parent
            visible: bleed.status === Image.Ready
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(Theme.crust, 0.30) }
                GradientStop { position: 0.34; color: Qt.alpha(Theme.crust, 0.72) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.84) }
            }
        }
    }

    // The specular the bar islands carry, so the card belongs to the same
    // set of surfaces rather than being a differently-lit rectangle near them.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.radius * 0.55
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.text, Theme.fillActive) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        // ── Cover ──
        ClippingRectangle {
            id: cover
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height
            height: width
            radius: width * 0.19
            color: Qt.alpha(Theme.crust, 0.85)

            // Lifts with the beat. At this size that is all the reaction there
            // is room for, and it is enough to tell playing from paused across
            // the room.
            scale: 1 + (Cava.active && Media.playing ? Cava.bass * 0.035 : 0)

            Image {
                id: fallback
                anchors.fill: parent
                visible: art.status !== Image.Ready
                source: Wallpaper.isVideo ? Wallpaper.stillPath : Wallpaper.path
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 320
                sourceSize.height: 320
                asynchronous: true
                cache: true
            }

            Rectangle {
                anchors.fill: parent
                visible: fallback.visible
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.alpha(MediaTint.accent, 0.32) }
                    GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.5) }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: fallback.visible
                text: Glyphs.music
                font.family: Theme.fontIconFamily
                font.pixelSize: cover.width * 0.3
                color: Qt.alpha(Theme.text, 0.5)
            }

            Image {
                id: art
                anchors.fill: parent
                source: Media.cover
                fillMode: Image.PreserveAspectCrop
                // Decoded well above the 92px it is drawn at. The same image is
                // the one the dashboard shows at 168, and a cache entry that is
                // only just big enough for the smallest surface is the one every
                // larger surface then has to upscale.
                sourceSize.width: 512
                sourceSize.height: 512
                asynchronous: true
                retainWhileLoading: true
                visible: status === Image.Ready
            }
        }

        Rectangle {
            anchors.fill: cover
            radius: cover.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, Theme.strokeFirm)
        }

        // ── Transport ──
        Row {
            id: controls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            MediaButton {
                glyph: Glyphs.skipPrevious
                size: 30
                enabled: Media.player !== null && Media.player.canGoPrevious
                onActivated: Media.previous()
            }
            MediaButton {
                glyph: Media.playing ? Glyphs.pause : Glyphs.play
                size: 40
                accented: true
                enabled: Media.player !== null && Media.player.canTogglePlaying
                onActivated: Media.togglePlay()
            }
            MediaButton {
                glyph: Glyphs.skipNext
                size: 30
                enabled: Media.player !== null && Media.player.canGoNext
                onActivated: Media.next()
            }
        }

        // ── Track ──
        Column {
            anchors.left: cover.right
            anchors.right: controls.left
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

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

            Item { width: 1; height: 4 }

            // The times flank the wave rather than sitting under it: this card
            // is short, and a fourth line would cost more height than the two
            // numbers are worth.
            Item {
                width: parent.width
                height: 24

                Text {
                    id: elapsed
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.clock(Media.position)
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    font.features: ({ "tnum": 1 })
                }

                Text {
                    id: remaining
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // Counts down, because what is left is the thing you look
                    // at a running track to find out.
                    text: Media.length > 0
                        ? "-" + root.clock(Media.length - Media.position)
                        : ""
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMicro
                    font.features: ({ "tnum": 1 })
                }

                SeekWave {
                    anchors.left: elapsed.right
                    anchors.right: remaining.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 24
                    // Fewer, fatter bars: at this width sixty-four of them are a
                    // pixel each and the shape stops being readable.
                    barCount: 30
                    barGap: 3
                }
            }
        }
    }
}
