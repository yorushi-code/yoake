import QtQuick
import QtQuick.Effects
import Quickshell

// The overview: what time it is, what month it is, what this machine is, and
// what is playing.
//
// Deliberately the things you would glance at, not the things you would change
// — the control centre is still where switches live. A dashboard that opens on
// a wall of toggles is a settings dialog.
Item {
    id: root

    // Set by the dashboard when the sheet opens.
    property bool revealed: true

    readonly property int gap: 14

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.visible
    }

    // ── Clock ──
    DashCard {
        id: timeCard
        order: 0
        revealed: root.revealed
        anchors.top: parent.top
        anchors.left: parent.left
        width: 232
        height: 202

        Column {
            anchors.centerIn: parent
            spacing: Theme.gapWide

            RollClock {
                anchors.horizontalCenter: parent.horizontalCenter
                hours: clock.date.getHours()
                minutes: clock.date.getMinutes()
                pixelSize: 52
                tracking: -2
                groupGap: 5
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const d = Lang.date(clock.date, "ddd, d MMMM");
                    return d.charAt(0).toUpperCase() + d.slice(1);
                }
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
            }
        }
    }

    // ── Calendar ──
    DashCard {
        id: calCard
        order: 1
        revealed: root.revealed
        anchors.top: parent.top
        anchors.left: timeCard.right
        anchors.leftMargin: root.gap
        anchors.right: weatherCard.left
        anchors.rightMargin: root.gap
        height: 202

        DashCalendar {
            anchors.centerIn: parent
            today: clock.date
        }
    }

    // ── Weather ──
    // Where the machine actually is, not where the tunnel says it is: Weather
    // locates over the physical interface for exactly that reason.
    DashCard {
        id: weatherCard
        order: 2
        revealed: root.revealed
        anchors.top: parent.top
        anchors.right: parent.right
        width: 244
        height: 202

        Text {
            anchors.centerIn: parent
            visible: !Weather.valid
            text: Weather.error !== "" ? Weather.error : "Погода загружается…"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Column {
            anchors.centerIn: parent
            visible: Weather.valid
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.glyph
                font.family: Theme.fontIconFamily
                font.pixelSize: 42
                color: Theme.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                text: Math.round(Weather.temperature) + "°"
                color: Theme.text
                font.family: Theme.fontDisplayFamily
                font.pixelSize: 40
                font.weight: Font.Medium
                font.letterSpacing: -1.5
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.summary
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8
                text: Weather.place
                color: Theme.subtext0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                spacing: Theme.gapCard

                Repeater {
                    model: [
                        { glyph: Glyphs.thermometer,
                          value: "ощущается " + Math.round(Weather.feelsLike) + "°" },
                        { glyph: Glyphs.wind, value: Math.round(Weather.wind) + " км/ч" }
                    ]

                    delegate: Row {
                        id: detail
                        required property var modelData
                        spacing: Theme.gapTight

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detail.modelData.glyph
                            font.family: Theme.fontIconFamily
                            font.pixelSize: Theme.fontIconMicro
                            color: Qt.alpha(Theme.subtext0, 0.8)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detail.modelData.value
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMicro
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }
    }

    // ── Now playing ──
    // The cover is the card. Blown up, blurred and dimmed behind the content,
    // it makes this the one card on the page that changes character with the
    // music instead of being another grey rectangle with a thumbnail in the
    // corner — and it costs one cached texture, because the blur is a layer Qt
    // renders once per track rather than per frame.
    DashCard {
        id: mediaCard
        order: 3
        revealed: root.revealed
        anchors.top: timeCard.bottom
        anchors.topMargin: root.gap
        anchors.left: parent.left
        anchors.right: statsCard.left
        anchors.rightMargin: root.gap
        anchors.bottom: parent.bottom
        interactive: Media.hasPlayer
        onActivated: Media.togglePlay()

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
            blurMax: 48
            blurMultiplier: 1.2
            saturation: 0.25
            opacity: 0.5
        }

        // A scrim, so the type stays readable whatever the cover happens to be.
        Rectangle {
            anchors.fill: parent
            visible: bleed.status === Image.Ready
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(Theme.crust, 0.62) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.crust, 0.86) }
            }
        }

        EmptyState {
            anchors.centerIn: parent
            visible: !Media.hasPlayer
            text: "Ничего не играет"
            catSize: 92
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16
            visible: Media.hasPlayer

            MediaOrb {
                id: orb
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                // Sized from the room the whole figure gets, ring included.
                coverSize: Math.min(orb.coverFor(parent.height), 116)
                barLength: 18
                gap: 9
            }

            Column {
                anchors.left: orb.right
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.gapTight

                Text {
                    width: parent.width
                    text: Media.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: Media.artist
                    color: Theme.subtext1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
                }

                Item { width: 1; height: 8 }

                SeekWave {
                    width: parent.width
                    implicitHeight: 26
                    barCount: 46
                    barGap: 3
                }

                Item { width: 1; height: 4 }

                Row {
                    spacing: Theme.spacing

                    MediaButton { glyph: Glyphs.skipPrevious; onActivated: Media.previous() }
                    MediaButton {
                        glyph: Media.playing ? Glyphs.pause : Glyphs.play
                        accented: true
                        onActivated: Media.togglePlay()
                    }
                    MediaButton { glyph: Glyphs.skipNext; onActivated: Media.next() }
                }
            }
        }
    }

    // ── Resources, in brief ──
    DashCard {
        id: statsCard
        order: 4
        revealed: root.revealed
        anchors.top: weatherCard.bottom
        anchors.topMargin: root.gap
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 244
        title: "Нагрузка"

        // The card is as tall as the player beside it, and three rows do not
        // fill that; centring them left a hand's width of nothing under the
        // heading. The history goes there — it is the thing the card was
        // missing anyway, since a percentage on its own cannot say whether the
        // machine is settling down or winding up.
        Sparkline {
            id: cpuChart
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: meters.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 4
            anchors.bottomMargin: 14
            values: SysInfo.cpuHistory
            capacity: SysInfo.historyLength
        }

        Column {
            id: meters
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 16
            spacing: Theme.gapCard

            Repeater {
                model: [
                    { label: "Процессор", value: SysInfo.cpu,
                      text: Math.round(SysInfo.cpu * 100) + "%" },
                    { label: "Память", value: SysInfo.memory,
                      text: SysInfo.formatGb(SysInfo.memoryUsedGb) + " / "
                            + SysInfo.formatGb(SysInfo.memoryTotalGb) + " ГиБ" },
                    { label: "Диск", value: SysInfo.disk,
                      text: SysInfo.formatGb(SysInfo.diskUsedGb) + " / "
                            + SysInfo.formatGb(SysInfo.diskTotalGb) + " ГиБ" }
                ]

                delegate: Column {
                    id: meter
                    required property var modelData
                    width: parent.width
                    spacing: Theme.spacing

                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors.left: parent.left
                            text: meter.modelData.label
                            color: Theme.subtext1
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            anchors.right: parent.right
                            text: meter.modelData.text
                            color: Theme.subtext0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.features: ({ "tnum": 1 })
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.alpha(Theme.text, Theme.fillMuted)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.max(0, Math.min(1, meter.modelData.value))
                            color: Theme.accent
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animSlow
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easeEmphasized
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
