import QtQuick
import QtQuick.Effects
import Quickshell

// Desktop-level composition (clock + spectrum + now-playing), sitting behind
// normal windows so it only shows on empty desktop space — a wallpaper-level
// flourish rather than another always-on-top bar.
PanelWindow {
    id: desk

    anchors {
        top: true
        right: true
    }
    margins {
        top: 110
        right: 56
    }
    implicitWidth: 420
    implicitHeight: stack.height
    color: "transparent"
    exclusiveZone: 0
    focusable: false
    aboveWindows: false
    // Only the media card takes input; the clock and spectrum stay
    // click-through so the desktop behaves like bare wallpaper everywhere
    // except the transport controls. The region has to collapse when there is
    // no player — a Region over an invisible item still masks its rectangle,
    // which left a 420x96 patch of empty desktop swallowing clicks.
    mask: Region { item: Media.hasPlayer ? mediaCard : null }

    readonly property real panelX: Screen.width - desk.margins.right - desk.implicitWidth
    readonly property real panelY: desk.margins.top

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: true
    }

    Column {
        id: stack
        width: parent.width
        spacing: 14

        // ── Time ──
        // Deliberately unadorned. Two earlier attempts at a glow both showed
        // up as a visible rectangle behind the digits: a RectangularShadow
        // draws an actual rounded box, and a blurred layer + MultiEffect
        // leaves a haze the size of the layer's texture bounds. The digits
        // carry enough weight on their own.
        Item {
            width: parent.width
            height: timeGroup.height

            Item {
                id: timeGroup
                anchors.right: parent.right
                width: hhmm.width + 8 + secondsText.width
                height: hhmm.height

                Text {
                    id: hhmm
                    anchors.left: parent.left
                    textFormat: Text.RichText
                    text: {
                        const hh = Qt.formatDateTime(clock.date, "hh");
                        const mm = Qt.formatDateTime(clock.date, "mm");
                        return `<span style="color:${Theme.text}">${hh}</span>`
                             + `<span style="color:${Theme.accent}">:${mm}</span>`;
                    }
                    font.pixelSize: 96
                    font.bold: true
                    font.letterSpacing: -2
                }

                // Separate element rather than an inline span: mixing font
                // sizes inside one RichText made the seconds sit awkwardly
                // against the big digits. Baseline anchoring lines them up
                // properly whatever the sizes.
                Text {
                    id: secondsText
                    anchors.left: hhmm.right
                    anchors.leftMargin: 8
                    anchors.baseline: hhmm.baseline
                    text: Qt.formatDateTime(clock.date, "ss")
                    color: Theme.subtext1
                    font.pixelSize: 34
                    font.bold: true
                }
            }
        }

        // ── Date ──
        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
            color: Theme.subtext1
            font.pixelSize: 13
            font.letterSpacing: 3
            opacity: 0.85
        }

        // ── Spectrum ──
        // Mirrored around the vertical centre so the shape reads as a waveform
        // rather than a bar chart; fades out entirely when audio is silent.
        Row {
            anchors.right: parent.right
            height: 76
            spacing: 4
            opacity: (Cava.active && Wallpaper.desktopVisible) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

            Repeater {
                // Zero rows, not just an invisible Row: occlusion does not stop
                // Qt from re-evaluating bindings, so twenty-eight delegates
                // kept recomputing their heights off every cava frame behind an
                // opaque window — about half the shell's idle CPU, spent on
                // something nobody could see. Dropping the delegates is what
                // actually stops the work.
                //
                // Only the spectrum is gated. Hiding the whole window would
                // also take the clock, and niri is a scrolling tiler: a window
                // on this workspace very often leaves most of the output bare.
                model: (Cava.active && Wallpaper.desktopVisible) ? Cava.barCount : 0
                delegate: Item {
                    required property int index
                    readonly property real level: Cava.values[index] || 0
                    readonly property real peak: Cava.peaks[index] || 0
                    width: 7
                    height: 76

                    // Glow scales with the band's own level, so loud bands
                    // bloom and quiet ones stay clean. Gated on being visible
                    // at all: below this the glow is under 0.17 opacity and
                    // indistinguishable from nothing, but all 28 were still
                    // drawn every frame.
                    RectangularShadow {
                        anchors.fill: barRect
                        radius: barRect.radius
                        visible: level > 0.25
                        color: Theme.accent
                        blur: 18
                        spread: 1
                        opacity: level * 0.7
                        offset: Qt.vector2d(0, 0)
                    }

                    Rectangle {
                        id: barRect
                        width: parent.width
                        height: Math.max(4, level * 76)
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Theme.blue }
                        }
                        opacity: 0.5 + level * 0.5
                        // See BarMedia: the fall is smoothed in Cava now.
                    }

                    // Peak-hold: a transient that would be gone by the next
                    // frame leaves a marker that sinks back down, which is what
                    // makes a fast track read as loud rather than just busy.
                    Rectangle {
                        width: parent.width
                        height: 2
                        radius: 1
                        color: Theme.text
                        opacity: peak > level + 0.04 ? 0.8 : 0
                        y: (parent.height - Math.max(4, peak * 76)) / 2
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }
                }
            }
        }

        // ── System load ──
        Row {
            anchors.right: parent.right
            spacing: 14

            StatChip {
                glyph: Glyphs.cpu
                label: Math.round(SysInfo.cpu * 100) + "%"
                level: SysInfo.cpu
            }
            StatChip {
                glyph: Glyphs.memory
                label: Math.round(SysInfo.memory * 100) + "%"
                level: SysInfo.memory
            }
            StatChip {
                glyph: Glyphs.thermometer
                visible: SysInfo.temperature > 0
                label: SysInfo.temperature + "°"
                // 40-90C mapped onto the bar: below 40 idle reads as empty and
                // above 90 the machine is thermally throttling anyway.
                level: Math.max(0, Math.min(1, (SysInfo.temperature - 40) / 50))
            }
        }

        // ── Now playing ──
        Item {
            id: mediaCard
            anchors.right: parent.right
            width: parent.width
            height: 96
            visible: Media.hasPlayer
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }

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
                screenX: desk.panelX
                screenY: desk.panelY + mediaCard.y
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
    }

}
