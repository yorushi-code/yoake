import QtQuick
import Quickshell

// The overview: what time it is, what month it is, what this machine is, and
// what is playing.
//
// Deliberately the things you would glance at, not the things you would change
// — the control centre is still where switches live. A dashboard that opens on
// a wall of toggles is a settings dialog.
Item {
    id: root

    readonly property int gap: 14

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.visible
    }

    // ── Clock ──
    DashCard {
        id: timeCard
        anchors.top: parent.top
        anchors.left: parent.left
        width: 232
        height: 202

        Column {
            anchors.centerIn: parent
            spacing: -6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
                color: Theme.text
                font.family: Theme.fontDisplayFamily
                font.pixelSize: 56
                font.weight: Font.DemiBold
                font.letterSpacing: -3
                font.features: ({ "tnum": 1 })
            }

            // Three dots rather than a colon: a colon between stacked figures
            // has nothing to sit against and reads as a stray mark.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                topPadding: 8
                bottomPadding: 8

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 4
                        height: 4
                        radius: 2
                        color: Theme.accent
                        opacity: 0.35 + 0.3 * ((clock.date.getSeconds() + index) % 3)
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.text
                font.family: Theme.fontDisplayFamily
                font.pixelSize: 56
                font.weight: Font.DemiBold
                font.letterSpacing: -3
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 14
                text: {
                    const d = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "ddd, d MMMM");
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
        anchors.top: parent.top
        anchors.left: timeCard.right
        anchors.leftMargin: root.gap
        anchors.right: machineCard.left
        anchors.rightMargin: root.gap
        height: 202

        DashCalendar {
            anchors.centerIn: parent
            today: clock.date
        }
    }

    // ── The machine ──
    DashCard {
        id: machineCard
        anchors.top: parent.top
        anchors.right: parent.right
        width: 244
        height: 202
        title: "Машина"

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.verticalCenterOffset: 14
            spacing: 9

            Repeater {
                model: [
                    { glyph: Glyphs.terminal, value: SysInfo.distro },
                    { glyph: Glyphs.cpu, value: SysInfo.kernel },
                    { glyph: Glyphs.monitor, value: "niri · yshell" },
                    { glyph: Glyphs.flash, value: SysInfo.uptimeText }
                ]

                delegate: Row {
                    id: fact
                    required property var modelData
                    width: parent.width
                    spacing: 10
                    visible: fact.modelData.value !== ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15
                        text: fact.modelData.glyph
                        font.family: Theme.fontIconFamily
                        font.pixelSize: 12
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 25
                        text: fact.modelData.value
                        color: Theme.subtext1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ── Now playing ──
    DashCard {
        id: mediaCard
        anchors.top: timeCard.bottom
        anchors.topMargin: root.gap
        anchors.left: parent.left
        anchors.right: statsCard.left
        anchors.rightMargin: root.gap
        anchors.bottom: parent.bottom
        interactive: Media.hasPlayer
        onActivated: Media.playPause()

        Text {
            anchors.centerIn: parent
            visible: !Media.hasPlayer
            text: "Ничего не играет"
            color: Theme.subtext0
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16
            visible: Media.hasPlayer

            AlbumArt {
                id: art
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: Math.min(parent.height, 148)
            }

            Column {
                anchors.left: art.right
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

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
                    color: Theme.subtext0
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
                }

                Item { width: 1; height: 8 }

                SeekBar { width: parent.width }

                Item { width: 1; height: 4 }

                Row {
                    spacing: 6

                    MediaButton { glyph: Glyphs.skipPrevious; onActivated: Media.previous() }
                    MediaButton {
                        glyph: Media.playing ? Glyphs.pause : Glyphs.play
                        accented: true
                        onActivated: Media.playPause()
                    }
                    MediaButton { glyph: Glyphs.skipNext; onActivated: Media.next() }
                }
            }
        }
    }

    // ── Resources, in brief ──
    DashCard {
        id: statsCard
        anchors.top: machineCard.bottom
        anchors.topMargin: root.gap
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 244
        title: "Нагрузка"

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.verticalCenterOffset: 12
            spacing: 13

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
                    spacing: 6

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
                        color: Qt.alpha(Theme.text, 0.10)

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
