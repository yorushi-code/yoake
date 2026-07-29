import QtQuick
import QtQuick.Effects
import Quickshell

// Now-playing popup that slides up from the bottom on every track change —
// the same "transient status" slot the volume/brightness OSD uses, so media
// changes get acknowledged without needing the desktop to be visible.
PanelWindow {
    id: win

    anchors.bottom: true
    margins.bottom: 60
    implicitWidth: 460
    implicitHeight: 96
    color: "transparent"
    exclusiveZone: 0
    // Never takes keyboard focus; its controls only need pointer input, which
    // layer-shell surfaces get regardless. The mask keeps input to the card
    // itself so the transparent margin around it isn't a dead click-trap over
    // whatever is underneath.
    focusable: false
    mask: Region { item: card }
    // Explicit mapping bool — see ControlCenter.qml. Keeps the window mapped
    // through the whole slide-down exit instead of unmapping instantly.
    property bool mapped: false
    visible: mapped

    Timer {
        id: hideDelay
        interval: Theme.animExit + 40
        onTriggered: win.mapped = false
    }
    Connections {
        target: Media
        function onOsdShownChanged() {
            if (Media.osdShown) {
                hideDelay.stop();
                win.mapped = true;
            } else {
                hideDelay.restart();
            }
        }
    }
    Component.onCompleted: win.mapped = Media.osdShown

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        color: Theme.shadowColor
        blur: Theme.shadowBlur
        spread: Theme.shadowSpread
        offset: Qt.vector2d(Theme.shadowOffset.x, Theme.shadowOffset.y)
    }

    FrostedBackground {
        id: card
        anchors.fill: parent
        radius: Theme.radiusLarge
        screenX: (Screen.width - width) / 2
        screenY: Screen.height - win.margins.bottom - height
        tintOpacity: 0.80

        opacity: Media.osdShown ? 1 : 0
        // Rises into place rather than just fading — reinforces that it came
        // from the bottom edge. On exit it sinks back down (see the larger
        // exit offset) with an accelerate curve, matching the other panels.
        y: Media.osdShown ? 0 : 20
        Behavior on opacity {
            NumberAnimation {
                duration: Media.osdShown ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Media.osdShown ? Theme.easeEmphasized : Theme.easeExit
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Media.osdShown ? Theme.animNormal : Theme.animExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Media.osdShown ? Theme.easeSpring : Theme.easeExit
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            AlbumArt {
                size: 68
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 68 - 14 - controls.width - 14
                spacing: 6

                Text {
                    width: parent.width
                    text: Media.title
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Media.artist
                    color: Theme.subtext1
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                SeekBar { width: parent.width }
            }

            Row {
                id: controls
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                MediaButton {
                    glyph: Glyphs.skipPrevious
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
                    enabled: Media.player !== null && Media.player.canGoNext
                    onActivated: Media.next()
                }
            }
        }
    }
}
